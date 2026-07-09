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

  static const _linuxGpuCpuCmd = r'''/bin/sh -lc '
printf "%s\n" "__GPU__"
nvidia-smi --query-gpu=index,uuid,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null || true
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
printf "%s\n" "__CPU__"
printf "%s\n" "platform=linux"
read_cpu_sample() {
  awk "/^cpu / {idle=\$5+\$6; total=0; for (i=2; i<=NF; i++) total+=\$i; print total, idle; exit}" /proc/stat 2>/dev/null
}
set -- $(read_cpu_sample)
total1="$1"
idle1="$2"
if sleep 0.25 2>/dev/null; then
  :
elif command -v usleep >/dev/null 2>&1; then
  usleep 250000
else
  sleep 1
fi
set -- $(read_cpu_sample)
total2="$1"
idle2="$2"
if [ -n "$total1" ] && [ -n "$idle1" ] && [ -n "$total2" ] && [ -n "$idle2" ]; then
  cpu_usage=$(awk -v t1="$total1" -v i1="$idle1" -v t2="$total2" -v i2="$idle2" "BEGIN{dt=t2-t1; di=i2-i1; if (dt>0) printf \"%.1f\", 100*(dt-di)/dt}")
  if [ -n "$cpu_usage" ]; then printf "usage_pct=%s\n" "$cpu_usage"; fi
fi
mem_total_kib=$(awk "/^MemTotal:/{print \$2; exit}" /proc/meminfo 2>/dev/null)
mem_avail_kib=$(awk "/^MemAvailable:/{print \$2; exit}" /proc/meminfo 2>/dev/null)
if [ -n "$mem_total_kib" ] && [ -n "$mem_avail_kib" ]; then
  mem_total_mib=$((mem_total_kib / 1024))
  mem_used_mib=$(((mem_total_kib - mem_avail_kib) / 1024))
  printf "mem_used_mib=%s\n" "$mem_used_mib"
  printf "mem_total_mib=%s\n" "$mem_total_mib"
fi
cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || printf "")
printf "logical_cores=%s\n" "$cores"
if [ -r /proc/loadavg ]; then
  set -- $(cat /proc/loadavg 2>/dev/null)
  printf "load_avg_1=%s\n" "$1"
  printf "load_avg_5=%s\n" "$2"
  printf "load_avg_15=%s\n" "$3"
fi
printf "%s\n" "__CPUPROC__"
ps -eo pid=,user=,pcpu=,pmem=,rss=,etime=,args= --sort=-pcpu 2>/dev/null | head -n 5 | awk "{
  pid=\$1; user=\$2; cpu=\$3; mem=\$4; rss=\$5; etime=\$6;
  \$1=\$2=\$3=\$4=\$5=\$6=\"\";
  sub(/^[ \t]+/, \"\", \$0);
  printf \"%s\t%s\t%s\t%s\t%.0f\t%s\t%s\n\", pid, user, cpu, mem, rss/1024, etime, \$0
}"
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
foreach ($procId in $pids) {
  $proc = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $procId)
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
  Write-Output ($procId + $tab + $user + $tab + $elapsed + $tab + $cmd)
}
exit 0
''';

  static const _windowsGpuCpuScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Write-Output '__GPU__'
nvidia-smi --query-gpu=index,uuid,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
Write-Output '__PROC__'
nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader,nounits
Write-Output '__PMON__'
nvidia-smi pmon -c 1 -s um
Write-Output '__PS__'
$tab = [char]9
$pids = @(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
foreach ($procId in $pids) {
  $proc = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $procId)
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
  Write-Output ($procId + $tab + $user + $tab + $elapsed + $tab + $cmd)
}
Write-Output '__CPU__'
Write-Output 'platform=windows'
$processors = @(Get-CimInstance Win32_Processor)
$cores = ($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
$safeCores = [Math]::Max([int]$cores, 1)
$sampleStart = Get-Date
$beforeCpu = @{}
foreach ($proc in Get-CimInstance Win32_Process) {
  $procId = [int]$proc.ProcessId
  $beforeCpu[$procId] = [double]$proc.KernelModeTime + [double]$proc.UserModeTime
}
Start-Sleep -Milliseconds 250
$sampleEnd = Get-Date
$sampleSeconds = [Math]::Max(($sampleEnd - $sampleStart).TotalSeconds, 0.001)
$capacity = $sampleSeconds * 10000000 * $safeCores
$cpuRows = @()
$activeTime = 0.0
$afterProcesses = @(Get-CimInstance Win32_Process)
foreach ($proc in $afterProcesses) {
  $procId = [int]$proc.ProcessId
  if ($procId -eq 0 -or -not $beforeCpu.ContainsKey($procId)) { continue }
  $afterTime = [double]$proc.KernelModeTime + [double]$proc.UserModeTime
  $delta = $afterTime - $beforeCpu[$procId]
  if ($delta -le 0) { continue }
  $cpuPct = [Math]::Round([Math]::Min(100, [Math]::Max(0, 100 * $delta / $capacity)), 1)
  $activeTime += $delta
  $cpuRows += [PSCustomObject]@{
    Process = $proc
    CpuPct = $cpuPct
  }
}
$cpuValue = [Math]::Round([Math]::Min(100, [Math]::Max(0, 100 * $activeTime / $capacity)), 1)
Write-Output ('usage_pct={0}' -f $cpuValue)
$os = Get-CimInstance Win32_OperatingSystem
$totalMemMiB = 0
if ($null -ne $os) {
  $totalMemMiB = [double]$os.TotalVisibleMemorySize / 1024
  $freeMemMiB = [double]$os.FreePhysicalMemory / 1024
  $usedMemMiB = $totalMemMiB - $freeMemMiB
  Write-Output ('mem_used_mib={0}' -f [Math]::Round($usedMemMiB))
  Write-Output ('mem_total_mib={0}' -f [Math]::Round($totalMemMiB))
}
$cores = ($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
if ($null -ne $cores) {
  Write-Output ('logical_cores={0}' -f [int]$cores)
}
Write-Output '__CPUPROC__'
$safeTotalMemMiB = [Math]::Max($totalMemMiB, 1)
$rows = @($cpuRows | Sort-Object CpuPct -Descending | Select-Object -First 5)
foreach ($row in $rows) {
  $proc = $row.Process
  if ($null -eq $proc) { continue }
  $owner = Invoke-CimMethod -InputObject $proc -MethodName GetOwner
  $user = $owner.User
  if ($owner.Domain) { $user = $owner.Domain + '\' + $owner.User }
  $elapsed = ''
  if ($proc.CreationDate) {
    $span = (Get-Date) - $proc.CreationDate
    $elapsed = ('{0:00}:{1:00}:{2:00}' -f [int]$span.TotalHours, $span.Minutes, $span.Seconds)
  }
  $rss = 0
  if ($proc.WorkingSetSize) { $rss = [Math]::Round([double]$proc.WorkingSetSize / 1MB) }
  $memPct = [Math]::Round(100 * $rss / $safeTotalMemMiB, 1)
  $cmd = $proc.CommandLine
  if ([string]::IsNullOrWhiteSpace($cmd)) { $cmd = $proc.Name }
  Write-Output ([string]::Join($tab, @(
    $proc.ProcessId,
    $user,
    $row.CpuPct,
    $memPct,
    $rss,
    $elapsed,
    $cmd
  )))
}
exit 0
''';

  static final _windowsCmd =
      'powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand '
      '${_toUtf16LeBase64(_windowsScript)}';

  static final _windowsGpuCpuCmd =
      'powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand '
      '${_toUtf16LeBase64(_windowsGpuCpuScript)}';

  /// Runs the remote GPU query, with optional CPU metrics.
  Future<String> queryGpu(SshHost host, {bool includeCpu = false}) async {
    final client = await _clientFor(host);
    try {
      final linux = await _runQueryCommand(
        client,
        includeCpu ? _linuxGpuCpuCmd : _linuxCmd,
      );
      if (linux.isSuccess) return linux.stdout;

      final windows = await _runQueryCommand(
        client,
        includeCpu ? _windowsGpuCpuCmd : _windowsCmd,
      );
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
