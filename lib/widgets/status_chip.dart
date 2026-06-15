import 'package:flutter/material.dart';

import '../models/host_query_result.dart';

/// Small colored label showing one host's query status.
class StatusChip extends StatelessWidget {
  final QueryStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, fg) = _style(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  (String, Color) _style(QueryStatus s, ColorScheme c) => switch (s) {
        QueryStatus.loading => ('查询中', c.primary),
        QueryStatus.success => ('在线', Colors.green),
        QueryStatus.error => ('错误', c.error),
        QueryStatus.noGpu => ('无 GPU', Colors.orange),
        QueryStatus.idle => ('待查询', c.outline),
      };
}
