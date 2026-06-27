import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_host.dart';
import 'ssh_key_loader.dart';

/// What kind of secret the executor is asking the UI for.
enum CredentialKind { passphrase, password }

/// Returned by the credential provider; null means the user cancelled.
typedef CredentialProvider =
    Future<String?> Function(
      CredentialKind kind,
      SshHost host, {
      String? reason,
    });

/// Owns per-host SSH clients, caches them across refreshes, and runs a single
/// command. Host-key policy: accept on first connection this session, then
/// require the same fingerprint thereafter.
class SshExecutor {
  final CredentialProvider? onCredential;
  final Duration connectTimeout;

  SshExecutor({
    this.onCredential,
    this.connectTimeout = const Duration(seconds: 15),
  });

  final _clients = <String, SSHClient>{}; // by host alias
  final _acceptedFingerprints = <String, String>{}; // alias -> base64 SHA256

  static const _linuxCmd = r'''/bin/sh -lc '
printf "%s\n" "__GPU__"
nvidia-smi --query-gpu=index,uuid,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits || exit $?
printf "%s\n" "__PROC__"
nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null || true
printf "%s\n" "__PMON__"
nvidia-smi pmon -c 1 -s um 2>/dev/null || true
printf "%s\n" "__PS__"
pid_lines=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null | sort -u)
if [ -n "$pid_lines" ]; then
  for pid in $pid_lines; do
    uid=$(awk "/^Uid:/{print \$2; exit}" "/proc/$pid/status" 2>/dev/null)
    user=$(getent passwd "$uid" 2>/dev/null | cut -d: -f1)
    if [ -z "$user" ]; then user="$uid"; fi
    etime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d " ")
    args=$(tr "\000" " " < "/proc/$pid/cmdline" 2>/dev/null)
    if [ -z "$args" ]; then args=$(ps -o args= -p "$pid" 2>/dev/null); fi
    printf "%s\t%s\t%s\t%s\n" "$pid" "$user" "$etime" "$args"
  done
fi
'
''';

  static const _windowsScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Write-Output '__GPU__'
nvidia-smi --query-gpu=index,uuid,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output '__PROC__'
nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader,nounits
Write-Output '__PMON__'
nvidia-smi pmon -c 1 -s um
Write-Output '__PS__'
$tab = [char]9
$pids = @(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
foreach ($pid in $pids) {
  $proc = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $pid)
  if ($null -eq $proc) { continue }
  $owner = Invoke-CimMethod -InputObject $proc -MethodName GetOwner
  $user = $owner.User
  if ($owner.Domain) { $user = $owner.Domain + '\' + $owner.User }
  $elapsed = ''
  if ($proc.CreationDate) {
    $span = (Get-Date) - $proc.CreationDate
    $elapsed = ('{0:00}:{1:00}:{2:00}' -f [int]$span.TotalHours, $span.Minutes, $span.Seconds)
  }
  $cmd = $proc.CommandLine
  if ([string]::IsNullOrWhiteSpace($cmd)) { $cmd = $proc.Name }
  Write-Output ($pid + $tab + $user + $tab + $elapsed + $tab + $cmd)
}
exit 0
''';

  static final _windowsCmd =
      'powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand '
      '${_toUtf16LeBase64(_windowsScript)}';

  /// Runs nvidia-smi on [host]. Throws [SshExecutorException] with a
  /// user-readable message on any failure.
  Future<String> queryGpu(SshHost host) async {
    final client = await _clientFor(host);
    try {
      final linux = await _runQueryCommand(client, _linuxCmd);
      if (linux.isSuccess) return linux.stdout;

      final windows = await _runQueryCommand(client, _windowsCmd);
      if (windows.isSuccess) return windows.stdout;

      final failure = windows.hasMessage ? windows : linux;
      throw SshExecutorException(failure.message);
    } on TimeoutException {
      throw SshExecutorException('查询超时（>${connectTimeout.inSeconds}s）');
    } catch (e) {
      // Stale/closed client: drop so the next refresh reconnects.
      if (e is! SshExecutorException) _invalidate(host.alias);
      if (e is SshExecutorException) rethrow;
      throw SshExecutorException('命令执行失败：$e');
    }
  }

  Future<_RemoteCommandResult> _runQueryCommand(
    SSHClient client,
    String command,
  ) async {
    final result = await client.runWithResult(command).timeout(connectTimeout);
    return _RemoteCommandResult(
      exitCode: result.exitCode ?? -1,
      stdout: _decodeRemote(result.stdout),
      stderr: _decodeRemote(result.stderr, stripPowerShellProgress: true),
    );
  }

  Future<SSHClient> _clientFor(SshHost host) async {
    final cached = _clients[host.alias];
    if (cached != null && !cached.isClosed) return cached;

    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(
        host.address,
        host.port,
        timeout: connectTimeout,
      );
    } catch (e) {
      throw SshExecutorException('无法连接 ${host.address}:${host.port}：$e');
    }

    final pem = await _loadIdentity(host);
    var identities = <SSHKeyPair>[];
    var needsPassword = true;
    if (pem != null) {
      try {
        identities = await _unlockKey(host, pem);
        needsPassword = identities.isEmpty;
      } on _UserCancelled {
        needsPassword = true;
      }
    }

    final client = SSHClient(
      socket,
      username: host.user ?? _currentUserName(),
      identities: identities.isNotEmpty ? identities : null,
      onPasswordRequest: needsPassword && onCredential != null
          ? () => onCredential!(CredentialKind.password, host)
          : null,
      onVerifyHostKey: (type, fingerprint) =>
          _verifyHostKey(host.alias, fingerprint),
    );

    try {
      await client.authenticated.timeout(connectTimeout);
    } catch (e) {
      client.close();
      _clients.remove(host.alias);
      throw SshExecutorException('认证失败：$e');
    }

    _clients[host.alias] = client;
    return client;
  }

  Future<String?> _loadIdentity(SshHost host) async {
    final paths = SshKeyLoader.candidates(host);
    return SshKeyLoader.readExisting(paths);
  }

  /// Unlocks a private key, prompting for a passphrase if it is encrypted.
  Future<List<SSHKeyPair>> _unlockKey(SshHost host, String pem) async {
    bool encrypted;
    try {
      encrypted = SSHKeyPair.isEncryptedPem(pem);
    } catch (_) {
      encrypted = false;
    }
    if (!encrypted) {
      return SSHKeyPair.fromPem(pem);
    }
    if (onCredential == null) return [];
    final pass = await onCredential!(CredentialKind.passphrase, host);
    if (pass == null) throw const _UserCancelled();
    return SSHKeyPair.fromPem(pem, pass);
  }

  bool _verifyHostKey(String alias, Uint8List fingerprint) {
    final fp = utf8.decode(fingerprint);
    final known = _acceptedFingerprints[alias];
    if (known == null) {
      _acceptedFingerprints[alias] = fp; // first connect: trust & remember
      return true;
    }
    return known == fp;
  }

  void _invalidate(String alias) {
    final c = _clients.remove(alias);
    c?.close();
  }

  /// Close everything (called on app shutdown).
  void dispose() {
    for (final c in _clients.values) {
      c.close();
    }
    _clients.clear();
  }

  static String _currentUserName() =>
      Platform.environment['USER'] ??
      Platform.environment['USERNAME'] ??
      'root';

  static String _decodeRemote(
    Uint8List bytes, {
    bool stripPowerShellProgress = false,
  }) {
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (!stripPowerShellProgress) return text;
    return _stripPowerShellProgress(text).trim();
  }

  static String _stripPowerShellProgress(String text) {
    if (!text.startsWith('#< CLIXML')) return text;
    if (text.contains('S="progress"')) return '';
    return text;
  }

  static String _toUtf16LeBase64(String script) {
    final bytes = Uint8List(script.length * 2);
    for (var i = 0; i < script.length; i++) {
      final code = script.codeUnitAt(i);
      bytes[i * 2] = code & 0xff;
      bytes[i * 2 + 1] = code >> 8;
    }
    return base64.encode(bytes);
  }
}

class _RemoteCommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _RemoteCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get isSuccess => exitCode == 0 && stdout.isNotEmpty;
  bool get hasMessage => stdout.isNotEmpty || stderr.isNotEmpty;

  String get message {
    if (stderr.isNotEmpty) return stderr;
    if (stdout.isNotEmpty) return stdout;
    return '未检测到 GPU 或未安装 NVIDIA 驱动 (exit $exitCode)';
  }
}

class SshExecutorException implements Exception {
  final String message;
  const SshExecutorException(this.message);
  @override
  String toString() => message;
}

class _UserCancelled implements Exception {
  const _UserCancelled();
}
