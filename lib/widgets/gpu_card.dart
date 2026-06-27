import 'package:flutter/material.dart';

import '../models/gpu_info.dart';
import '../models/gpu_process_info.dart';

/// One GPU: name + utilization/memory bars + temp/power stats.
class GpuCard extends StatelessWidget {
  final GpuInfo gpu;
  const GpuCard(this.gpu, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${gpu.index}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gpu.name,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Bar(
              label: 'GPU 利用率',
              value: gpu.gpuUtil?.toDouble(),
              unit: '%',
              valueText: gpu.gpuUtil != null ? '${gpu.gpuUtil}%' : 'N/A',
              color: _utilColor(gpu.gpuUtil),
            ),
            const SizedBox(height: 10),
            _Bar(
              label: '显存',
              value: gpu.memUtilPct,
              unit: '%',
              valueText: gpu.memTotal != null
                  ? '${_fmtMiB(gpu.memUsed)} / ${_fmtMiB(gpu.memTotal)}'
                  : 'N/A',
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Stat(
                  icon: Icons.thermostat,
                  label: '温度',
                  value: gpu.temp != null ? '${gpu.temp}°C' : 'N/A',
                ),
                const SizedBox(width: 16),
                _Stat(
                  icon: Icons.bolt,
                  label: '功耗',
                  value: gpu.powerDraw != null
                      ? '${gpu.powerDraw!.toStringAsFixed(1)}W'
                      : 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            _ProcessDetails(gpu),
          ],
        ),
      ),
    );
  }

  static Color _utilColor(int? pct) {
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
}

class _ProcessDetails extends StatelessWidget {
  final GpuInfo gpu;

  const _ProcessDetails(this.gpu);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (gpu.processes.isEmpty) {
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
              '无 GPU 进程',
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
          '${gpu.processes.length} 个进程 · ${GpuCard._fmtMiB(gpu.processMemoryUsed)}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.expand_more),
        children: [
          const SizedBox(height: 4),
          for (final process in gpu.processes) _ProcessRow(process),
        ],
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  final GpuProcessInfo process;

  const _ProcessRow(this.process);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                GpuCard._fmtMiB(process.usedMemory),
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
                Text('运行 ${process.elapsed}', style: detailStyle),
              Text('SM ${_fmtPct(process.smUtil)}', style: detailStyle),
              Text('MEM ${_fmtPct(process.memUtil)}', style: detailStyle),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtPct(int? value) => value == null ? 'N/A' : '$value%';
}

class _Bar extends StatelessWidget {
  final String label;
  final double? value; // 0..100
  final String unit;
  final String valueText;
  final Color color;
  const _Bar({
    required this.label,
    required this.value,
    required this.unit,
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
          '$label：',
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
