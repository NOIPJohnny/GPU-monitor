/// A single host entry parsed from ~/.ssh/config.
class SshHost {
  final String alias;
  final String? hostName;
  final String? user;
  final int port;
  final List<String> identityFiles;

  const SshHost({
    required this.alias,
    this.hostName,
    this.user,
    this.port = 22,
    this.identityFiles = const [],
  });

  /// Effective connection target: HostName if set, otherwise the alias.
  String get address => hostName?.isNotEmpty == true ? hostName! : alias;

  SshHost copyWith({List<String>? identityFiles}) => SshHost(
        alias: alias,
        hostName: hostName,
        user: user,
        port: port,
        identityFiles: identityFiles ?? this.identityFiles,
      );

  @override
  String toString() =>
      'SshHost($alias -> $address:$port user=${user ?? "-"} keys=${identityFiles.length})';
}
