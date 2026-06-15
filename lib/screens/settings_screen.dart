import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: const [
          _HostListSection(),
          _AutoRefreshSection(),
          _AppearanceSection(),
        ],
      ),
    );
  }
}

class _HostListSection extends StatelessWidget {
  const _HostListSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final hosts = settings.allHosts;
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text('主机（${settings.activeHosts.length}/${hosts.length} 启用）'),
      subtitle: hosts.isEmpty
          ? const Text('未在 ~/.ssh/config 中找到 Host')
          : Text('关闭即排除该主机，不参与查询'),
      leading: const Icon(Icons.dns),
      children: [
        if (hosts.isEmpty)
          ListTile(
            dense: true,
            title: Text('请先在 ~/.ssh/config 中添加 Host 后重启',
                style: theme.textTheme.bodySmall),
          ),
        for (final h in hosts)
          SwitchListTile(
            value: settings.isActive(h.alias),
            onChanged: (v) => settings.setExcluded(h.alias, !v),
            secondary: const Icon(Icons.computer),
            title: Text(h.alias),
            subtitle: Text('${h.address}:${h.port}'
                '${h.user == null ? "" : "  user=${h.user}"}'),
          ),
      ],
    );
  }
}

class _AutoRefreshSection extends StatefulWidget {
  const _AutoRefreshSection();

  @override
  State<_AutoRefreshSection> createState() => _AutoRefreshSectionState();
}

class _AutoRefreshSectionState extends State<_AutoRefreshSection> {
  late final TextEditingController _ctrl;
  // Slider covers the common range (3–120s); the text field accepts the full
  // 3–3600s range for users who want very long intervals.
  static const int _sliderMax = 120;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _ctrl = TextEditingController(text: '${settings.intervalSeconds}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    // Keep the field in sync when value changed via slider.
    final shown = '${settings.intervalSeconds}';
    if (_ctrl.text != shown) {
      _ctrl.value = _ctrl.value.copyWith(
        text: shown,
        selection: TextSelection.collapsed(offset: shown.length),
      );
    }
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('自动刷新'),
      leading: const Icon(Icons.sync),
      children: [
        SwitchListTile(
          title: const Text('启用自动刷新'),
          subtitle: Text('每隔 ${settings.intervalSeconds} 秒重复查询一次'),
          value: settings.autoRefresh,
          onChanged: settings.setAutoRefresh,
        ),
        ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('刷新间隔'),
          subtitle: Text(
              '范围 ${SettingsProvider.minInterval}–${SettingsProvider.maxInterval} 秒'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  min: SettingsProvider.minInterval.toDouble(),
                  max: _sliderMax.toDouble(),
                  divisions: _sliderMax - SettingsProvider.minInterval,
                  value: settings.intervalSeconds
                      .toDouble()
                      .clamp(
                          SettingsProvider.minInterval.toDouble(),
                          _sliderMax.toDouble()),
                  label: '${settings.intervalSeconds}s',
                  onChanged: (v) => settings.setInterval(v.round()),
                ),
              ),
              SizedBox(
                width: 84,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: 's',
                    border: OutlineInputBorder(),
                  ),
                  controller: _ctrl,
                  onSubmitted: (s) {
                    final v = int.tryParse(s);
                    if (v != null) settings.setInterval(v);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
              '提示：滑块上限 ${_sliderMax}s，输入框可填到 ${SettingsProvider.maxInterval}s。',
              style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}


class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('外观'),
      leading: const Icon(Icons.palette),
      children: [
        RadioListTile<ThemeMode>(
          title: const Text('跟随系统'),
          value: ThemeMode.system,
          groupValue: theme.themeMode,
          onChanged: (v) => v == null ? null : theme.setThemeMode(v),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('浅色'),
          value: ThemeMode.light,
          groupValue: theme.themeMode,
          onChanged: (v) => v == null ? null : theme.setThemeMode(v),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('深色'),
          value: ThemeMode.dark,
          groupValue: theme.themeMode,
          onChanged: (v) => v == null ? null : theme.setThemeMode(v),
        ),
      ],
    );
  }
}
