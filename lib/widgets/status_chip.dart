import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/host_query_result.dart';

/// Small colored label showing one host's query status.
class StatusChip extends StatelessWidget {
  final QueryStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, fg) = _style(
      status,
      Theme.of(context).colorScheme,
      AppLocalizations.of(context)!,
    );
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

  (String, Color) _style(QueryStatus s, ColorScheme c, AppLocalizations l10n) =>
      switch (s) {
        QueryStatus.loading => (l10n.statusLoading, c.primary),
        QueryStatus.success => (l10n.statusOnline, Colors.green),
        QueryStatus.error => (l10n.statusError, c.error),
        QueryStatus.noGpu => (l10n.statusNoGpu, Colors.orange),
        QueryStatus.idle => (l10n.statusIdle, c.outline),
      };
}
