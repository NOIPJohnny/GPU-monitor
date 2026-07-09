import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/cpu_info.dart';
import '../models/gpu_info.dart';
import '../models/host_query_result.dart';
import 'cpu_card.dart';
import 'gpu_card.dart';
import 'status_chip.dart';

/// One host: header (alias + address + status chip) and its GPU cards,
/// or an inline message for error/noGpu states.
class HostSection extends StatelessWidget {
  final String alias;
  final String? address;
  final HostQueryResult result;
  final bool showCpuMetrics;
  const HostSection({
    super.key,
    required this.alias,
    this.address,
    required this.result,
    this.showCpuMetrics = false,
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
                    Text(
                      alias,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (address != null && address != alias)
                      Text(
                        address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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
    final l10n = AppLocalizations.of(context)!;
    switch (result.status) {
      case QueryStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );
      case QueryStatus.success:
        final cards = <Widget>[
          if (showCpuMetrics && result.cpu != null) _cpuCard(result.cpu!),
          for (final gpu in result.gpus) _gpuCard(gpu),
        ];
        return Wrap(spacing: 12, runSpacing: 12, children: cards);
      case QueryStatus.error:
        return _msg(
          context,
          Icons.error_outline,
          result.errorMessage ?? l10n.unknownError,
          Theme.of(context).colorScheme.error,
        );
      case QueryStatus.noGpu:
        if (showCpuMetrics && result.cpu != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [_cpuCard(result.cpu!)],
              ),
              const SizedBox(height: 8),
              _msg(
                context,
                Icons.info_outline,
                l10n.noGpuOrDriver,
                Colors.orange,
              ),
            ],
          );
        }
        return _msg(
          context,
          Icons.info_outline,
          l10n.noGpuOrDriver,
          Colors.orange,
        );
      case QueryStatus.idle:
        return _msg(
          context,
          Icons.hourglass_empty,
          l10n.notQueriedYet,
          Colors.grey,
        );
    }
  }

  Widget _cpuCard(CpuInfo cpu) {
    // Responsive-ish: fixed max width so 2–3 cards fit per row on desktop.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: CpuCard(cpu),
    );
  }

  Widget _gpuCard(GpuInfo gpu) {
    // Responsive-ish: fixed max width so 2–3 cards fit per row on desktop.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: GpuCard(gpu),
    );
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
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
