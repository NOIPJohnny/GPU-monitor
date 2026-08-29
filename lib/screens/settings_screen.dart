import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/gpu_monitor_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/menu_bar_shortcut.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          const _SystemNotificationSection(),
          const _HostListSection(),
          const _MetricsSection(),
          const _AutoRefreshSection(),
          const _DesktopBehaviorSection(),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS)
            const _MenuBarShortcutSection(),
          const _AppearanceSection(),
        ],
      ),
    );
  }
}

class _MenuBarShortcutSection extends StatelessWidget {
  const _MenuBarShortcutSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(l10n.menuBarShortcutTitle),
      subtitle: Text(l10n.menuBarShortcutSubtitle),
      leading: const Icon(Icons.keyboard_alt_outlined),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _ShortcutRecorder(
                  value: settings.menuBarShortcut,
                  onChanged: settings.setMenuBarShortcut,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed:
                    settings.menuBarShortcut == MenuBarShortcut.defaultValue
                    ? null
                    : () => settings.setMenuBarShortcut(
                        MenuBarShortcut.defaultValue,
                      ),
                child: Text(l10n.menuBarShortcutReset),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutRecorder extends StatefulWidget {
  const _ShortcutRecorder({required this.value, required this.onChanged});

  final String value;
  final Future<void> Function(String shortcut) onChanged;

  @override
  State<_ShortcutRecorder> createState() => _ShortcutRecorderState();
}

class _ShortcutRecorderState extends State<_ShortcutRecorder> {
  final _focusNode = FocusNode();
  bool _recording = false;
  String? _error;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _recording = false;
        _error = null;
      });
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }

    final shortcut = MenuBarShortcut.fromKeyEvent(event);
    if (shortcut == null) {
      if (event is KeyDownEvent) {
        setState(
          () => _error = AppLocalizations.of(context)!.menuBarShortcutInvalid,
        );
      }
      return KeyEventResult.handled;
    }

    unawaited(widget.onChanged(shortcut));
    setState(() {
      _recording = false;
      _error = null;
    });
    _focusNode.unfocus();
    return KeyEventResult.handled;
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _error = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: InkWell(
        onTap: _startRecording,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          isFocused: _recording,
          decoration: InputDecoration(
            labelText: _recording
                ? l10n.menuBarShortcutRecording
                : l10n.menuBarShortcutRecord,
            errorText: _error,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          child: Text(
            MenuBarShortcut.display(widget.value),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final hosts = settings.allHosts;
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(
        l10n.hostsSectionTitle(settings.activeHosts.length, hosts.length),
      ),
      subtitle: hosts.isEmpty
          ? Text(l10n.noHostInConfig)
          : Text(l10n.hostExcludeHint),
      leading: const Icon(Icons.dns),
      children: [
        if (hosts.isEmpty)
          ListTile(
            dense: true,
            title: Text(
              l10n.addHostThenRestart,
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final h in hosts) ...[
          SwitchListTile(
            value: settings.isActive(h.alias),
            onChanged: (v) => settings.setExcluded(h.alias, !v),
            secondary: const Icon(Icons.computer),
            title: Text(h.alias),
            subtitle: Text(
              '${h.address}:${h.port}'
              '${h.user == null ? "" : "  user=${h.user}"}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(l10n.hostAlert),
              subtitle: Text(
                !settings.autoRefresh && settings.isHostAlertEnabled(h.alias)
                    ? l10n.hostAlertPaused
                    : l10n.hostAlertReady,
              ),
              value:
                  settings.isActive(h.alias) &&
                  settings.isHostAlertEnabled(h.alias),
              onChanged: settings.isActive(h.alias)
                  ? (enabled) => settings.setHostAlert(h.alias, enabled)
                  : null,
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _SystemNotificationSection extends StatefulWidget {
  const _SystemNotificationSection();

  @override
  State<_SystemNotificationSection> createState() =>
      _SystemNotificationSectionState();
}

class _SystemNotificationSectionState
    extends State<_SystemNotificationSection> {
  bool _isTestingSystemNotification = false;

  Future<void> _testSystemNotification() async {
    setState(() => _isTestingSystemNotification = true);
    try {
      await context.read<GpuMonitorProvider>().sendTestSystemNotification();
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.testSystemNotificationSent);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context)!.systemNotificationFailure('$error'),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingSystemNotification = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<GpuMonitorProvider>();
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.notifications_outlined),
      title: Text(l10n.notificationsTitle),
      subtitle: Text(l10n.notificationsSubtitle),
      children: [
        if (monitor.supportsSystemNotifications)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _isTestingSystemNotification
                    ? null
                    : _testSystemNotification,
                icon: _isTestingSystemNotification
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(
                  _isTestingSystemNotification
                      ? l10n.sendingTestSystemNotification
                      : l10n.sendTestSystemNotification,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricsSection extends StatelessWidget {
  const _MetricsSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(l10n.metricsSectionTitle),
      leading: const Icon(Icons.monitor_heart_outlined),
      children: [
        SwitchListTile(
          title: Text(l10n.showCpuMetrics),
          subtitle: Text(l10n.showCpuMetricsSubtitle),
          value: settings.showCpuMetrics,
          onChanged: settings.setShowCpuMetrics,
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
  // Slider covers the common range (0.5–120s); the text field accepts the full
  // 0.5–3600s range for users who want very long intervals.
  static const double _sliderMax = 120;
  static const double _sliderStep = 0.5;
  static const _quickIntervals = [0.5, 1.0, 2.0];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _ctrl = TextEditingController(
      text: SettingsProvider.formatInterval(settings.intervalSeconds),
    );
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
    final l10n = AppLocalizations.of(context)!;
    // Keep the field in sync when value changed via slider.
    final shown = SettingsProvider.formatInterval(settings.intervalSeconds);
    if (_ctrl.text != shown) {
      _ctrl.value = _ctrl.value.copyWith(
        text: shown,
        selection: TextSelection.collapsed(offset: shown.length),
      );
    }
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(l10n.autoRefreshTitle),
      leading: const Icon(Icons.sync),
      children: [
        SwitchListTile(
          title: Text(l10n.enableAutoRefresh),
          subtitle: Text(l10n.autoRefreshSubtitle(shown)),
          value: settings.autoRefresh,
          onChanged: settings.setAutoRefresh,
        ),
        ListTile(
          leading: const Icon(Icons.timer),
          title: Text(l10n.refreshInterval),
          subtitle: Text(
            l10n.refreshIntervalRange(
              SettingsProvider.formatInterval(SettingsProvider.minInterval),
              SettingsProvider.formatInterval(SettingsProvider.maxInterval),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  min: SettingsProvider.minInterval,
                  max: _sliderMax,
                  divisions:
                      ((_sliderMax - SettingsProvider.minInterval) /
                              _sliderStep)
                          .round(),
                  value: settings.intervalSeconds
                      .clamp(SettingsProvider.minInterval, _sliderMax)
                      .toDouble(),
                  label: '${shown}s',
                  onChanged: (v) => settings.setInterval(
                    (v / _sliderStep).round() * _sliderStep,
                  ),
                ),
              ),
              SizedBox(
                width: 84,
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: 's',
                    border: OutlineInputBorder(),
                  ),
                  controller: _ctrl,
                  onSubmitted: (s) {
                    final v = double.tryParse(s);
                    if (v != null) settings.setInterval(v);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final interval in _quickIntervals)
                ChoiceChip(
                  label: Text('${SettingsProvider.formatInterval(interval)}s'),
                  selected: settings.intervalSeconds == interval,
                  onSelected: (_) => settings.setInterval(interval),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.autoRefreshTip(
              SettingsProvider.formatInterval(_sliderMax),
              SettingsProvider.formatInterval(SettingsProvider.maxInterval),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _DesktopBehaviorSection extends StatelessWidget {
  const _DesktopBehaviorSection();

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.windows &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return const SizedBox.shrink();
    }
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(l10n.desktopBehaviorTitle),
      leading: const Icon(Icons.desktop_windows_outlined),
      children: [
        SwitchListTile(
          title: Text(l10n.closeToBackground),
          subtitle: Text(
            isMacOS
                ? l10n.closeToBackgroundMacosSubtitle
                : l10n.closeToBackgroundWindowsSubtitle,
          ),
          value: settings.closeToBackground,
          onChanged: settings.setCloseToBackground,
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
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(l10n.appearance),
      leading: const Icon(Icons.palette),
      children: [
        RadioGroup<ThemeMode>(
          groupValue: theme.themeMode,
          onChanged: (v) => v == null ? null : theme.setThemeMode(v),
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: Text(l10n.themeSystem),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.themeLight),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.themeDark),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        RadioGroup<AppLanguage>(
          groupValue: context.watch<SettingsProvider>().language,
          onChanged: (v) => v == null
              ? null
              : context.read<SettingsProvider>().setLanguage(v),
          child: Column(
            children: [
              RadioListTile<AppLanguage>(
                title: Text(l10n.languageSystem),
                value: AppLanguage.system,
              ),
              RadioListTile<AppLanguage>(
                title: Text(l10n.languageChinese),
                value: AppLanguage.zh,
              ),
              RadioListTile<AppLanguage>(
                title: Text(l10n.languageEnglish),
                value: AppLanguage.en,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
