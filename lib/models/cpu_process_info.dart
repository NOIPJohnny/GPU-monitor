class CpuProcessInfo {
  final int pid;
  final String name;
  final String? user;
  final double? cpuUtil; // %
  final double? memoryUtil; // %
  final int? residentMemory; // MiB
  final String? elapsed;
  final String? command;

  const CpuProcessInfo({
    required this.pid,
    required this.name,
    this.user,
    this.cpuUtil,
    this.memoryUtil,
    this.residentMemory,
    this.elapsed,
    this.command,
  });
}
