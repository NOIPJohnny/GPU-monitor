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
typedef CredentialProvider = Future<String?> Function(
    CredentialKind kind, SshHost host, {String? reason});

/// Owns per-host SSH clients, caches them across refreshes, and runs a single
/// command. Host-key policy: accept on first connection this session, then
/// require the same fingerprint thereafter.
class SshExecutor {
  final CredentialProvider? onCredential;
  final Duration connectTimeout;

  SshExecutor({this.onCredential, this.connectTimeout = const Duration(seconds: 15)});

  final _clients = <String, SSHClient>{}; // by host alias
  final _acceptedFingerprints = <String, String>{}; // alias -> base64 SHA256

  static const _cmd =
      'nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,'
      'temperature.gpu,power.draw --format=csv,noheader,nounits';

  /// Runs nvidia-smi on [host]. Throws [SshExecutorException] with a
  /// user-readable message on any failure.
  Future<String> queryGpu(SshHost host) async {
    final client = await _clientFor(host);
    try {
      final result = await client.runWithResult(_cmd).timeout(connectTimeout);
      // nvidia-smi returns non-zero when no GPU / driver present.
      final out = utf8.decode(result.stdout).trim();
      final err = utf8.decode(result.stderr).trim();
      if (result.exitCode != 0 && out.isEmpty) {
        throw SshExecutorException(
            err.isEmpty ? '未检测到 GPU 或未安装 NVIDIA 驱动 (exit ${result.exitCode})' : err);
      }
      if (out.isEmpty) {
        throw SshExecutorException('未检测到 GPU 或未安装 NVIDIA 驱动');
      }
      return out;
    } on TimeoutException {
      throw SshExecutorException('查询超时（>${connectTimeout.inSeconds}s）');
    } catch (e) {
      // Stale/closed client: drop so the next refresh reconnects.
      if (e is! SshExecutorException) _invalidate(host.alias);
      if (e is SshExecutorException) rethrow;
      throw SshExecutorException('命令执行失败：$e');
    }
  }

  Future<SSHClient> _clientFor(SshHost host) async {
    final cached = _clients[host.alias];
    if (cached != null && !cached.isClosed) return cached;

    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(host.address, host.port,
          timeout: connectTimeout);
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
