import 'package:flutter/material.dart';

import '../models/host_query_result.dart';
import 'gpu_card.dart';
import 'status_chip.dart';

/// One host: header (alias + address + status chip) and its GPU cards,
/// or an inline message for error/noGpu states.
class HostSection extends StatelessWidget {
  final String alias;
  final String? address;
  final HostQueryResult result;
  const HostSection({
    super.key,
    required this.alias,
    this.address,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alias,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (address != null && address != alias)
                      Text(address!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              StatusChip(result.status),
            ],
          ),
          const SizedBox(height: 8),
          _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (result.status) {
      case QueryStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );
      case QueryStatus.success:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: result.gpus.map((g) {
            // Responsive-ish: fixed max width so 2–3 cards fit per row on desktop.
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: GpuCard(g),
            );
          }).toList(),
        );
      case QueryStatus.error:
        return _msg(context, Icons.error_outline, result.errorMessage ?? '未知错误',
            Theme.of(context).colorScheme.error);
      case QueryStatus.noGpu:
        return _msg(context, Icons.info_outline, '未检测到 GPU 或未安装 NVIDIA 驱动', Colors.orange);
      case QueryStatus.idle:
        return _msg(context, Icons.hourglass_empty, '尚未查询，点击右上角刷新按钮', Colors.grey);
    }
  }

  Widget _msg(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
