class GpuProcessInfo {
  final int pid;
  final String name;
  final String? user;
  final int? usedMemory; // MiB
  final int? smUtil; // %
  final int? memUtil; // %
  final String? elapsed;
  final String? command;

  const GpuProcessInfo({
    required this.pid,
    required this.name,
    this.user,
    this.usedMemory,
    this.smUtil,
    this.memUtil,
    this.elapsed,
    this.command,
  });
}
