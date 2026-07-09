import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/cpu_info.dart';
import '../models/cpu_process_info.dart';

/// One host's CPU summary and top CPU-consuming processes.
class CpuCard extends StatelessWidget {
  final CpuInfo cpu;
  const CpuCard(this.cpu, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.memory,
                    size: 14,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.cpuPerformance,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Bar(
              label: l10n.cpuUtilization,
              value: cpu.cpuUtil,
              valueText: cpu.cpuUtil != null
                  ? '${cpu.cpuUtil!.toStringAsFixed(1)}%'
                  : 'N/A',
              color: _utilColor(cpu.cpuUtil),
            ),
            const SizedBox(height: 10),
            _Bar(
              label: l10n.systemMemory,
              value: cpu.memoryUtilPct,
              valueText: cpu.memoryTotal != null
                  ? '${_fmtMiB(cpu.memoryUsed)} / ${_fmtMiB(cpu.memoryTotal)}'
                  : 'N/A',
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Stat(
                  icon: Icons.developer_board,
                  label: l10n.logicalCores,
                  value: cpu.logicalCores?.toString() ?? 'N/A',
                ),
                _Stat(
                  icon: Icons.speed,
                  label: l10n.cpuUsedCores,
                  value: _fmtUsedCores(cpu),
                ),
                if (cpu.hasLoadAverage)
                  _Stat(
                    icon: Icons.timeline,
                    label: l10n.loadAverage,
                    value: _fmtLoad(cpu),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            _CpuProcessDetails(cpu),
          ],
        ),
      ),
    );
  }

  static Color _utilColor(double? pct) {
    if (pct == null) return Colors.grey;
    if (pct >= 85) return Colors.red;
    if (pct >= 50) return Colors.orange;
    return Colors.green;
  }

  static String _fmtMiB(int? m) {
    if (m == null) return '-';
    if (m >= 1024) return '${(m / 1024).toStringAsFixed(1)}GiB';
    return '${m}MiB';
  }

  static String _fmtLoad(CpuInfo cpu) => [
    cpu.loadAvg1,
    cpu.loadAvg5,
    cpu.loadAvg15,
  ].whereType<double>().map((v) => v.toStringAsFixed(2)).join(' / ');

  static String _fmtUsedCores(CpuInfo cpu) {
    if (cpu.usedCores == null) return 'N/A';
    final used = cpu.usedCores!.toStringAsFixed(1);
    final total = cpu.logicalCores?.toString();
    return total == null ? used : '$used / $total';
  }
}

class _CpuProcessDetails extends StatelessWidget {
  final CpuInfo cpu;

  const _CpuProcessDetails(this.cpu);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (cpu.processes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.noCpuProcesses,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          l10n.cpuProcessCount(cpu.processes.length),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.expand_more),
        children: [
          const SizedBox(height: 4),
          for (final process in cpu.processes) _CpuProcessRow(process),
        ],
      ),
    );
  }
}

class _CpuProcessRow extends StatelessWidget {
  final CpuProcessInfo process;

  const _CpuProcessRow(this.process);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final command = process.command ?? process.name;
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  command,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CPU ${_fmtPct(process.cpuUtil)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              Text('PID ${process.pid}', style: detailStyle),
              if (process.user != null) Text(process.user!, style: detailStyle),
              if (process.elapsed != null)
                Text(l10n.runningElapsed(process.elapsed!), style: detailStyle),
              Text('MEM ${_fmtPct(process.memoryUtil)}', style: detailStyle),
              Text(CpuCard._fmtMiB(process.residentMemory), style: detailStyle),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtPct(double? value) =>
      value == null ? 'N/A' : '${value.toStringAsFixed(1)}%';
}

class _Bar extends StatelessWidget {
  final String label;
  final double? value;
  final String valueText;
  final Color color;

  const _Bar({
    required this.label,
    required this.value,
    required this.valueText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value?.clamp(0, 100) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              valueText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value == null ? null : v / 100,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
