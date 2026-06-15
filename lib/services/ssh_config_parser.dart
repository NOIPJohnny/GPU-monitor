import 'dart:io';

import '../models/ssh_host.dart';

class SshConfigParser {
  /// Parse ssh config text into concrete (non-wildcard) hosts.
  /// Wildcard Host patterns (e.g. `Host *`) accumulate defaults that get
  /// merged into subsequent concrete hosts.
  static List<SshHost> parse(String content) {
    final hosts = <SshHost>[];
    final defaults = _Defaults();
    _Defaults? pending; // active non-wildcard block being filled

    void commit(_Defaults block) {
      final alias = block.alias;
      if (alias == null || _isWildcard(alias)) return;
      hosts.add(SshHost(
        alias: alias,
        hostName: block.hostName,
        user: block.user ?? defaults.user,
        port: block.port ?? defaults.port ?? 22,
        identityFiles: block.identityFiles.isNotEmpty
            ? block.identityFiles
            : List.unmodifiable(defaults.identityFiles),
      ));
    }

    // Which accumulator a per-keyword setting writes to: the current concrete
    // host if one is open, otherwise the wildcard defaults.
    _Defaults target() {
      final p = pending;
      if (p != null && !_isWildcard(p.alias ?? '')) return p;
      return defaults;
    }

    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = _stripComment(rawLine).trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      final keyword = parts[0].toLowerCase();
      final args = parts.sublist(1);
      if (args.isEmpty) continue;

      switch (keyword) {
        case 'host':
          {
            final p = pending;
            if (p != null) commit(p);
          }
          // Open a new block: concrete host (pending) for the first concrete
          // name; pure-wildcard lines fall back to filling `defaults`.
          final firstConcrete = args.firstWhere(
            (a) => !_isWildcard(a),
            orElse: () => args.first,
          );
          pending = _Defaults(alias: firstConcrete);
          break;
        case 'hostname':
          target().hostName = args.first;
          break;
        case 'user':
          target().user = args.first;
          break;
        case 'port':
          target().port = int.tryParse(args.first);
          break;
        case 'identityfile':
          target().identityFiles.add(_expandTilde(args.first));
          break;
        // Keywords we deliberately ignore for v1.
        default:
          break;
      }
    }
    {
      final p = pending;
      if (p != null) commit(p);
    }
    return hosts;
  }

  static bool _isWildcard(String alias) => alias.contains(RegExp(r'[*?!]'));

  /// ~/.ssh/config, or [] if missing/unreadable.
  static Future<List<SshHost>> loadDefault() async {
    final file = await _defaultConfigFile();
    if (file == null || !await file.exists()) return [];
    try {
      return parse(await file.readAsString());
    } catch (_) {
      return [];
    }
  }

  static String _stripComment(String line) {
    final hash = line.indexOf('#');
    return hash >= 0 ? line.substring(0, hash) : line;
  }

  static String _expandTilde(String path) {
    final home = homeDir;
    if (path.startsWith('~')) return '$home${path.substring(1)}';
    return path;
  }

  static String get homeDir =>
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;

  static Future<File?> _defaultConfigFile() async {
    final home = homeDir;
    if (home.isEmpty) return null;
    return File('$home${Platform.pathSeparator}.ssh${Platform.pathSeparator}config');
  }
}

/// Mutable accumulator for either a wildcard-default block or a concrete host.
class _Defaults {
  String? alias;
  String? hostName;
  String? user;
  int? port;
  final List<String> identityFiles = [];

  _Defaults({this.alias});
}
