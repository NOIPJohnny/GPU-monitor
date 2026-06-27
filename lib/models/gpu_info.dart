import 'gpu_process_info.dart';

/// One GPU's metrics captured from a single nvidia-smi query.
class GpuInfo {
  final int index;
  final String? uuid;
  final String name;
  final int? gpuUtil; // %
  final int? memUsed; // MiB
  final int? memTotal; // MiB
  final int? temp; // °C
  final double? powerDraw; // W
  final List<GpuProcessInfo> processes;

  const GpuInfo({
    required this.index,
    this.uuid,
    required this.name,
    this.gpuUtil,
    this.memUsed,
    this.memTotal,
    this.temp,
    this.powerDraw,
    this.processes = const [],
  });

  double? get memUtilPct {
    if (memTotal == null || memTotal == 0 || memUsed == null) return null;
    return (memUsed! / memTotal!) * 100;
  }

  int get processMemoryUsed =>
      processes.fold<int>(0, (sum, process) => sum + (process.usedMemory ?? 0));

  bool get isLikelyIdle {
    final lowGpu = gpuUtil == null || gpuUtil! < 10;
    final lowMem = memUsed == null || memUsed! < 1024;
    return processes.isEmpty && lowGpu && lowMem;
  }
}
