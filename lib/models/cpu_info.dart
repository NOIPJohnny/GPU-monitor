import 'cpu_process_info.dart';

/// One host's CPU and memory metrics captured from a single SSH query.
class CpuInfo {
  final double? cpuUtil; // %
  final int? memoryUsed; // MiB
  final int? memoryTotal; // MiB
  final int? logicalCores;
  final double? loadAvg1;
  final double? loadAvg5;
  final double? loadAvg15;
  final List<CpuProcessInfo> processes;

  const CpuInfo({
    this.cpuUtil,
    this.memoryUsed,
    this.memoryTotal,
    this.logicalCores,
    this.loadAvg1,
    this.loadAvg5,
    this.loadAvg15,
    this.processes = const [],
  });

  double? get memoryUtilPct {
    if (memoryTotal == null || memoryTotal == 0 || memoryUsed == null) {
      return null;
    }
    return (memoryUsed! / memoryTotal!) * 100;
  }

  double? get usedCores {
    if (cpuUtil == null || logicalCores == null) return null;
    return logicalCores! * cpuUtil! / 100;
  }

  bool get hasLoadAverage =>
      loadAvg1 != null || loadAvg5 != null || loadAvg15 != null;
}
