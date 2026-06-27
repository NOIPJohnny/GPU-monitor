import '../models/gpu_info.dart';
import '../models/gpu_process_info.dart';

/// Parses output of:
///   nvidia-smi --query-gpu=index,uuid,name,utilization.gpu,memory.used,
///              memory.total,temperature.gpu,power.draw
///              --format=csv,noheader,nounits
class NvidiaSmiParser {
  static List<GpuInfo> parse(String output) {
    if (output.contains('__GPU__')) return _parseDetailed(output);
    return _parseGpuRows(output);
  }

  static List<GpuInfo> _parseDetailed(String output) {
    final gpus = _parseGpuRows(_section(output, '__GPU__'));
    if (gpus.isEmpty) return gpus;

    final gpuByUuid = {
      for (final gpu in gpus)
        if (gpu.uuid != null) gpu.uuid!: gpu,
    };
    final pmon = _parsePmon(_section(output, '__PMON__'));
    final ps = _parsePs(_section(output, '__PS__'));
    final processesByGpu = <String, List<GpuProcessInfo>>{};

    for (final rawLine in _section(
      output,
      '__PROC__',
    ).split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final fields = _splitCsvLine(line);
      if (fields.length < 4) continue;

      final uuid = fields[0];
      final pid = int.tryParse(fields[1]);
      if (pid == null || !gpuByUuid.containsKey(uuid)) continue;

      final gpu = gpuByUuid[uuid]!;
      final util = pmon[_GpuPid(gpu.index, pid)];
      final process = ps[pid];
      processesByGpu
          .putIfAbsent(uuid, () => [])
          .add(
            GpuProcessInfo(
              pid: pid,
              name: fields[2].isEmpty ? 'process' : fields[2],
              user: process?.user,
              usedMemory: _parseInt(fields[3]),
              smUtil: util?.smUtil,
              memUtil: util?.memUtil,
              elapsed: process?.elapsed,
              command: process?.command,
            ),
          );
    }

    return gpus
        .map(
          (gpu) => GpuInfo(
            index: gpu.index,
            uuid: gpu.uuid,
            name: gpu.name,
            gpuUtil: gpu.gpuUtil,
            memUsed: gpu.memUsed,
            memTotal: gpu.memTotal,
            temp: gpu.temp,
            powerDraw: gpu.powerDraw,
            processes: gpu.uuid == null
                ? const []
                : List.unmodifiable(processesByGpu[gpu.uuid] ?? const []),
          ),
        )
        .toList();
  }

  static List<GpuInfo> _parseGpuRows(String output) {
    final gpus = <GpuInfo>[];
    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final fields = _splitCsvLine(line);
      if (fields.isEmpty) continue;

      final hasUuid = fields.length >= 8 && fields[1].startsWith('GPU-');
      final nameOffset = hasUuid ? 2 : 1;
      gpus.add(
        GpuInfo(
          index: _parseInt(fields[0]) ?? gpus.length,
          uuid: hasUuid ? fields[1] : null,
          name: fields.length > nameOffset ? fields[nameOffset] : 'GPU',
          gpuUtil: fields.length > nameOffset + 1
              ? _parseInt(fields[nameOffset + 1])
              : null,
          memUsed: fields.length > nameOffset + 2
              ? _parseInt(fields[nameOffset + 2])
              : null,
          memTotal: fields.length > nameOffset + 3
              ? _parseInt(fields[nameOffset + 3])
              : null,
          temp: fields.length > nameOffset + 4
              ? _parseInt(fields[nameOffset + 4])
              : null,
          powerDraw: fields.length > nameOffset + 5
              ? double.tryParse(fields[nameOffset + 5])
              : null,
        ),
      );
    }
    return gpus;
  }

  static String _section(String output, String marker) {
    final lines = output.split(RegExp(r'\r?\n'));
    final start = lines.indexWhere((line) => line.trim() == marker);
    if (start < 0) return '';

    final sectionLines = <String>[];
    for (var i = start + 1; i < lines.length; i++) {
      if (lines[i].trim().startsWith('__') && lines[i].trim().endsWith('__')) {
        break;
      }
      sectionLines.add(lines[i]);
    }
    return sectionLines.join('\n');
  }

  static Map<_GpuPid, _PmonInfo> _parsePmon(String output) {
    final pmon = <_GpuPid, _PmonInfo>{};
    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final fields = line.split(RegExp(r'\s+'));
      if (fields.length < 5) continue;

      final gpuIndex = _parseInt(fields[0]);
      final pid = _parseInt(fields[1]);
      if (gpuIndex == null || pid == null) continue;

      pmon[_GpuPid(gpuIndex, pid)] = _PmonInfo(
        smUtil: _parseInt(fields[3]),
        memUtil: _parseInt(fields[4]),
      );
    }
    return pmon;
  }

  static Map<int, _PsInfo> _parsePs(String output) {
    final processes = <int, _PsInfo>{};
    final linePattern = RegExp(r'^\s*(\d+)\s+(\S+)\s+(\S+)\s*(.*)$');
    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      if (rawLine.contains('\t')) {
        final fields = rawLine.split('\t');
        if (fields.length >= 4) {
          final pid = int.tryParse(fields[0].trim());
          if (pid == null) continue;
          final command = fields.sublist(3).join('\t').trim();
          processes[pid] = _PsInfo(
            user: fields[1].trim().isEmpty ? null : fields[1].trim(),
            elapsed: fields[2].trim().isEmpty ? null : fields[2].trim(),
            command: command.isEmpty ? null : command,
          );
        }
        continue;
      }

      final match = linePattern.firstMatch(rawLine);
      if (match == null) continue;
      final pid = int.tryParse(match.group(1)!);
      if (pid == null) continue;
      final command = match.group(4)?.trim();
      processes[pid] = _PsInfo(
        user: match.group(2),
        elapsed: match.group(3),
        command: command == null || command.isEmpty ? null : command,
      );
    }
    return processes;
  }

  static List<String> _splitCsvLine(String line) =>
      line.split(',').map((field) => field.trim()).toList();

  static int? _parseInt(String value) => int.tryParse(value.trim());
}

class _GpuPid {
  final int gpuIndex;
  final int pid;

  const _GpuPid(this.gpuIndex, this.pid);

  @override
  bool operator ==(Object other) =>
      other is _GpuPid && other.gpuIndex == gpuIndex && other.pid == pid;

  @override
  int get hashCode => Object.hash(gpuIndex, pid);
}

class _PmonInfo {
  final int? smUtil;
  final int? memUtil;

  const _PmonInfo({this.smUtil, this.memUtil});
}

class _PsInfo {
  final String? user;
  final String? elapsed;
  final String? command;

  const _PsInfo({this.user, this.elapsed, this.command});
}
