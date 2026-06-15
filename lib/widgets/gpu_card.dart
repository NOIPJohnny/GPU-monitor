import 'package:flutter/material.dart';

import '../models/gpu_info.dart';

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
                  child: Text('${gpu.index}',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(gpu.name,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis),
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
                    value: gpu.temp != null ? '${gpu.temp}°C' : 'N/A'),
                const SizedBox(width: 16),
                _Stat(
                    icon: Icons.bolt,
                    label: '功耗',
                    value:
                        gpu.powerDraw != null ? '${gpu.powerDraw!.toStringAsFixed(1)}W' : 'N/A'),
              ],
            ),
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

class _Bar extends StatelessWidget {
  final String label;
  final double? value; // 0..100
  final String unit;
  final String valueText;
  final Color color;
  const _Bar(
      {required this.label,
      required this.value,
      required this.unit,
      required this.valueText,
      required this.color});

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
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(valueText,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
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
        Text('$label：',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
