import '../models/gpu_info.dart';

/// Parses output of:
///   nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,
///              memory.total,temperature.gpu,power.draw
///              --format=csv,noheader,nounits
class NvidiaSmiParser {
  static List<GpuInfo> parse(String output) {
    final gpus = <GpuInfo>[];
    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final fields = line.split(',').map((f) => f.trim()).toList();
      if (fields.isEmpty) continue;

      gpus.add(GpuInfo(
        index: int.tryParse(fields[0]) ?? gpus.length,
        name: fields.length > 1 ? fields[1] : 'GPU',
        gpuUtil: fields.length > 2 ? int.tryParse(fields[2]) : null,
        memUsed: fields.length > 3 ? int.tryParse(fields[3]) : null,
        memTotal: fields.length > 4 ? int.tryParse(fields[4]) : null,
        temp: fields.length > 5 ? int.tryParse(fields[5]) : null,
        powerDraw: fields.length > 6 ? double.tryParse(fields[6]) : null,
      ));
    }
    return gpus;
  }
}
