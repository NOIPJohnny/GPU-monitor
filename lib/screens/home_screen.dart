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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
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
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => monitor.refresh(),
      child: ListView.builder(
        itemCount: active.length,
        itemBuilder: (context, i) {
          final host = active[i];
          final result = monitor.results[host.alias] ??
              HostQueryResult(
                  alias: host.alias,
                  status: QueryStatus.idle,
                  fetchedAt: DateTime.now());
          return HostSection(
              alias: host.alias, address: host.address, result: result);
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

    final last = monitor.lastRefreshedAt;
    final lastText =
        last == null ? '尚未刷新' : '上次刷新 ${DateFormat('HH:mm:ss').format(last)}';

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.access_time,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(lastText, style: theme.textTheme.bodySmall),
          ]),
          if (settings.autoRefresh)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.autorenew,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text('自动刷新 · ${settings.intervalSeconds}s',
                  style: theme.textTheme.bodySmall),
            ]),
          _countChip(context, '在线', ok, Colors.green),
          _countChip(context, '错误', err, theme.colorScheme.error),
          _countChip(context, '无 GPU', noGpu, Colors.orange),
        ],
      ),
    );
  }

  Widget _countChip(BuildContext context, String label, int n, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 4),
      Text('$label $n', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _AutoRefreshToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return IconButton(
      icon: Icon(
        settings.autoRefresh ? Icons.sync : Icons.sync_disabled,
        color: settings.autoRefresh ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: settings.autoRefresh
          ? '自动刷新中（${settings.intervalSeconds}s）'
          : '自动刷新已关闭',
      onPressed: () => settings.setAutoRefresh(!settings.autoRefresh),
    );
  }
}
