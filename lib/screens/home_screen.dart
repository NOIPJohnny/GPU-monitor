import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/host_query_result.dart';
import '../models/ssh_host.dart';
import '../providers/gpu_monitor_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ssh_executor.dart';
import '../widgets/empty_state.dart';
import '../widgets/host_section.dart';
import '../widgets/passphrase_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final monitor = context.read<GpuMonitorProvider>();
      monitor.onCredentialProvider =
          (CredentialKind kind, SshHost host, {String? reason}) =>
              showCredentialDialog(context, kind, host, reason: reason);
      if (monitor.results.isEmpty) monitor.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<GpuMonitorProvider>();
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH GPU 监控'),
        actions: [
          _AutoRefreshToggle(),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: '切换主题',
            onPressed: () => _cycleTheme(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const _StatusBar(),
          const Divider(height: 1),
          Expanded(child: _body(monitor, settings)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: monitor.isRefreshing ? null : () => monitor.refresh(),
        icon: monitor.isRefreshing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: const Text('查询 GPU'),
      ),
    );
  }

  Widget _body(GpuMonitorProvider monitor, SettingsProvider settings) {
    if (settings.allHosts.isEmpty) {
      return const EmptyState(
        icon: Icons.dns_outlined,
        title: '未在 ~/.ssh/config 中找到任何 Host',
        message: '请在你的 SSH 配置中加入至少一个 Host 条目后重启本程序。',
      );
    }
    final active = settings.activeHosts;
    if (active.isEmpty) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: '所有主机已被排除',
        message: '在设置中重新启用至少一台主机即可查询。',
        actionLabel: '打开设置',
        onAction: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      );
    }
    final showOverview = monitor.results.values.any(
      (r) => r.status == QueryStatus.success,
    );
    return RefreshIndicator(
      onRefresh: () => monitor.refresh(),
      child: ListView.builder(
        itemCount: active.length + (showOverview ? 1 : 0),
        itemBuilder: (context, i) {
          if (showOverview && i == 0) {
            return _OverviewPanel(results: monitor.results.values.toList());
          }
          final host = active[i - (showOverview ? 1 : 0)];
          final result =
              monitor.results[host.alias] ??
              HostQueryResult(
                alias: host.alias,
                status: QueryStatus.idle,
                fetchedAt: DateTime.now(),
              );
          return HostSection(
            alias: host.alias,
            address: host.address,
            result: result,
          );
        },
      ),
    );
  }

  void _cycleTheme(BuildContext context) {
    final tp = context.read<ThemeProvider>();
    final next = switch (tp.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    tp.setThemeMode(next);
  }
}

class _OverviewPanel extends StatelessWidget {
  final List<HostQueryResult> results;

  const _OverviewPanel({required this.results});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idleByHost = <String, List<int>>{};
    final usageByUser = <String, _UserUsage>{};

    for (final result in results.where(
      (r) => r.status == QueryStatus.success,
    )) {
      for (final gpu in result.gpus) {
        if (gpu.isLikelyIdle) {
          idleByHost.putIfAbsent(result.alias, () => []).add(gpu.index);
        }
        for (final process in gpu.processes) {
          final user = process.user ?? '未知用户';
          final usage = usageByUser.putIfAbsent(user, () => _UserUsage(user));
          usage.processCount++;
          usage.memoryUsed += process.usedMemory ?? 0;
          usage.gpus.add('${result.alias}:${gpu.index}');
        }
      }
    }

    final users = usageByUser.values.toList()
      ..sort((a, b) => b.memoryUsed.compareTo(a.memoryUsed));
    final idleHosts = idleByHost.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dashboard_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '资源概览',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('空闲 GPU', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            if (idleHosts.isEmpty)
              Text(
                '暂无空闲 GPU',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final entry in idleHosts)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.memory, size: 16),
                      label: Text('${entry.key}：${entry.value.join('，')}'),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Text('用户占用', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            if (users.isEmpty)
              Text(
                '暂无 GPU 进程',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: [
                  for (final usage in users.take(6))
                    _UserUsageRow(usage: usage),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UserUsageRow extends StatelessWidget {
  final _UserUsage usage;

  const _UserUsageRow({required this.usage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              usage.user,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${usage.processCount} 进程',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(_fmtMiB(usage.memoryUsed), style: theme.textTheme.bodySmall),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              usage.gpus.take(4).join(', '),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserUsage {
  final String user;
  int processCount = 0;
  int memoryUsed = 0;
  final Set<String> gpus = {};

  _UserUsage(this.user);
}

String _fmtMiB(int m) {
  if (m >= 1024) return '${(m / 1024).toStringAsFixed(1)}GiB';
  return '${m}MiB';
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<GpuMonitorProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    final results = monitor.results.values.toList();
    final ok = results.where((r) => r.status == QueryStatus.success).length;
    final err = results.where((r) => r.status == QueryStatus.error).length;
    final noGpu = results.where((r) => r.status == QueryStatus.noGpu).length;
    final idleGpu = results
        .where((r) => r.status == QueryStatus.success)
        .expand((r) => r.gpus)
        .where((g) => g.isLikelyIdle)
        .length;

    final last = monitor.lastRefreshedAt;
    final lastText = last == null
        ? '尚未刷新'
        : '上次刷新 ${DateFormat('HH:mm:ss').format(last)}';

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(lastText, style: theme.textTheme.bodySmall),
            ],
          ),
          if (settings.autoRefresh)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.autorenew,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '自动刷新 · ${settings.intervalSeconds}s',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          _countChip(context, '在线', ok, Colors.green),
          _countChip(context, '空闲 GPU', idleGpu, Colors.blue),
          _countChip(context, '错误', err, theme.colorScheme.error),
          _countChip(context, '无 GPU', noGpu, Colors.orange),
        ],
      ),
    );
  }

  Widget _countChip(BuildContext context, String label, int n, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text('$label $n', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AutoRefreshToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return IconButton(
      icon: Icon(
        settings.autoRefresh ? Icons.sync : Icons.sync_disabled,
        color: settings.autoRefresh
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      tooltip: settings.autoRefresh
          ? '自动刷新中（${settings.intervalSeconds}s）'
          : '自动刷新已关闭',
      onPressed: () => settings.setAutoRefresh(!settings.autoRefresh),
    );
  }
}
