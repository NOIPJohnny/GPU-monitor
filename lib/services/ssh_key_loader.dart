import 'dart:io';

import '../models/ssh_host.dart';
import 'ssh_config_parser.dart';

/// Candidate private-key file paths for a host, in priority order:
/// the host's IdentityFile entries first, then the conventional defaults.
class SshKeyLoader {
  static const _defaults = ['id_ed25519', 'id_rsa', 'id_ecdsa', 'id_dsa'];

  static List<String> candidates(SshHost host) {
    final home = _sshDir;
    final out = <String>[];
    for (final f in host.identityFiles) {
      out.add(_normalize(f));
    }
    for (final name in _defaults) {
      final p = '$home${Platform.pathSeparator}$name';
      if (!out.contains(p)) out.add(p);
    }
    return out;
  }

  /// Returns the first existing private key's PEM text, or null if none found.
  static Future<String?> readExisting(List<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) return await f.readAsString();
      } catch (_) {
        // unreadable / permission denied: skip to next candidate
      }
    }
    return null;
  }

  static String _normalize(String path) {
    if (path.startsWith('~')) {
      return '${SshConfigParser.homeDir}${path.substring(1)}';
    }
    return path;
  }

  static String get _sshDir =>
      '${SshConfigParser.homeDir}${Platform.pathSeparator}.ssh';
}
