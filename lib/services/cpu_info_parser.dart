import '../models/cpu_info.dart';
import '../models/cpu_process_info.dart';

/// Parses CPU sections emitted by [SshExecutor] when CPU monitoring is enabled.
class CpuInfoParser {
  static CpuInfo? parse(String output) {
    final cpuSection = _section(output, '__CPU__');
    if (cpuSection.trim().isEmpty) return null;

    final values = <String, String>{};
    for (final rawLine in cpuSection.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      values[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }

    final processes = _parseProcesses(_section(output, '__CPUPROC__'));
    final cpu = CpuInfo(
      cpuUtil: _parseDouble(values['usage_pct']),
      memoryUsed: _parseInt(values['mem_used_mib']),
      memoryTotal: _parseInt(values['mem_total_mib']),
      logicalCores: _parseInt(values['logical_cores']),
      loadAvg1: _parseDouble(values['load_avg_1']),
      loadAvg5: _parseDouble(values['load_avg_5']),
      loadAvg15: _parseDouble(values['load_avg_15']),
      processes: List.unmodifiable(processes),
    );

    if (cpu.cpuUtil == null &&
        cpu.memoryUsed == null &&
        cpu.memoryTotal == null &&
        cpu.logicalCores == null &&
        !cpu.hasLoadAverage &&
        cpu.processes.isEmpty) {
      return null;
    }
    return cpu;
  }

  static List<CpuProcessInfo> _parseProcesses(String output) {
    final processes = <CpuProcessInfo>[];
    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      if (processes.length >= 5) break;
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;
      final fields = line.split('\t');
      if (fields.length < 7) continue;

      final pid = int.tryParse(fields[0].trim());
      if (pid == null) continue;

      final command = fields.sublist(6).join('\t').trim();
      final name = _processName(command);
      processes.add(
        CpuProcessInfo(
          pid: pid,
          name: name,
          user: _emptyToNull(fields[1].trim()),
          cpuUtil: _parseDouble(fields[2]),
          memoryUtil: _parseDouble(fields[3]),
          residentMemory: _parseInt(fields[4]),
          elapsed: _emptyToNull(fields[5].trim()),
          command: command.isEmpty ? null : command,
        ),
      );
    }
    return processes;
  }

  static String _section(String output, String marker) {
    final lines = output.split(RegExp(r'\r?\n'));
    final start = lines.indexWhere((line) => line.trim() == marker);
    if (start < 0) return '';

    final sectionLines = <String>[];
    for (var i = start + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('__') && line.endsWith('__')) break;
      sectionLines.add(lines[i]);
    }
    return sectionLines.join('\n');
  }

  static String _processName(String command) {
    if (command.isEmpty) return 'process';
    final first = command.split(RegExp(r'\s+')).first;
    final normalized = first.replaceAll(r'\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash >= 0 ? normalized.substring(slash + 1) : normalized;
  }

  static String? _emptyToNull(String value) => value.isEmpty ? null : value;

  static int? _parseInt(String? value) =>
      value == null ? null : int.tryParse(value.trim());

  static double? _parseDouble(String? value) =>
      value == null ? null : double.tryParse(value.trim());
}
