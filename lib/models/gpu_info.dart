/// One GPU's metrics captured from a single nvidia-smi query.
class GpuInfo {
  final int index;
  final String name;
  final int? gpuUtil; // %
  final int? memUsed; // MiB
  final int? memTotal; // MiB
  final int? temp; // °C
  final double? powerDraw; // W

  const GpuInfo({
    required this.index,
    required this.name,
    this.gpuUtil,
    this.memUsed,
    this.memTotal,
    this.temp,
    this.powerDraw,
  });

  double? get memUtilPct {
    if (memTotal == null || memTotal == 0 || memUsed == null) return null;
    return (memUsed! / memTotal!) * 100;
  }
}
