import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/email_settings.dart';
import '../providers/gpu_monitor_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/email_notification_sender.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: const [
          _EmailNotificationSection(),
          _HostListSection(),
          _MetricsSection(),
          _AutoRefreshSection(),
          _DesktopBehaviorSection(),
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
              title: Text(l10n.hostEmailAlert),
              subtitle: Text(
                !settings.isEmailReady
                    ? l10n.hostEmailAlertNeedsConfig
                    : !settings.autoRefresh &&
                          settings.isHostAlertEnabled(h.alias)
                    ? l10n.hostEmailAlertPaused
                    : l10n.hostEmailAlertReady,
              ),
              value:
                  settings.isActive(h.alias) &&
                  settings.isHostAlertEnabled(h.alias),
              onChanged: settings.isActive(h.alias)
                  ? (enabled) async {
                      final ok = await settings.setHostAlert(h.alias, enabled);
                      if (!context.mounted || ok) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.hostEmailAlertEnableFailed),
                        ),
                      );
                    }
                  : null,
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _EmailNotificationSection extends StatefulWidget {
  const _EmailNotificationSection();

  @override
  State<_EmailNotificationSection> createState() =>
      _EmailNotificationSectionState();
}

class _EmailNotificationSectionState extends State<_EmailNotificationSection> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _from;
  late final TextEditingController _recipients;
  late SmtpSecurity _security;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isTestingSystemNotification = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().emailSettings;
    _host = TextEditingController(text: settings.host);
    _port = TextEditingController(text: settings.port.toString());
    _username = TextEditingController(text: settings.username);
    _password = TextEditingController();
    _from = TextEditingController(text: settings.fromAddress);
    _recipients = TextEditingController(text: settings.recipients.join(', '));
    _security = settings.security;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _from.dispose();
    _recipients.dispose();
    super.dispose();
  }

  EmailSettings _draft() => EmailSettings(
    host: _host.text.trim(),
    port: int.tryParse(_port.text.trim()) ?? 0,
    security: _security,
    username: _username.text.trim(),
    fromAddress: _from.text.trim(),
    recipients: EmailSettings.parseRecipients(_recipients.text),
  );

  Future<SmtpDeliveryConfig?> _deliveryConfig() async {
    try {
      final settings = context.read<SettingsProvider>();
      final password = _password.text.trim().isNotEmpty
          ? _password.text.trim()
          : await settings.loadSmtpPassword() ?? '';
      final config = SmtpDeliveryConfig(settings: _draft(), password: password);
      if (config.isComplete) return config;
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.emailTestMissingFields);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context)!.emailFailureUnknown('$error'),
        );
      }
    }
    return null;
  }

  Future<void> _save() async {
    final config = await _deliveryConfig();
    if (config == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await context.read<SettingsProvider>().saveEmailSettings(
        config.settings,
        password: _password.text.trim().isEmpty ? null : _password.text,
      );
      _password.clear();
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.emailSettingsSaved);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context)!.emailFailureUnknown('$error'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _test() async {
    final config = await _deliveryConfig();
    if (config == null || !mounted) return;
    setState(() => _isTesting = true);
    try {
      final sender = EmailNotificationSender(() async => config);
      await sender.sendTest(config);
      if (mounted) {
        _showMessage(
          AppLocalizations.of(
            context,
          )!.testEmailSent(config.settings.recipients.join(', ')),
        );
      }
    } on EmailSendException catch (error) {
      if (mounted) _showMessage(_emailErrorText(error));
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

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

  String _emailErrorText(EmailSendException error) {
    final l10n = AppLocalizations.of(context)!;
    return switch (error.kind) {
      EmailSendFailureKind.missingConfiguration =>
        l10n.emailFailureMissingConfig,
      EmailSendFailureKind.timeout => l10n.emailFailureTimeout,
      EmailSendFailureKind.connection => l10n.emailFailureConnection,
      EmailSendFailureKind.tls => l10n.emailFailureTls,
      EmailSendFailureKind.authentication => l10n.emailFailureAuth,
      EmailSendFailureKind.recipient => l10n.emailFailureRecipient,
      EmailSendFailureKind.unknown => l10n.emailFailureUnknown(error.detail),
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final monitor = context.watch<GpuMonitorProvider>();
    final l10n = AppLocalizations.of(context)!;
    final actionsBusy = _isSaving || _isTesting || _isTestingSystemNotification;
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.notifications_outlined),
      title: Text(l10n.emailNotificationsTitle),
      subtitle: Text(l10n.emailNotificationsSubtitle),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              TextField(
                controller: _host,
                decoration: InputDecoration(
                  labelText: l10n.smtpHost,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.smtpPort,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<SmtpSecurity>(
                      initialValue: _security,
                      decoration: InputDecoration(
                        labelText: l10n.smtpSecurity,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: SmtpSecurity.startTls,
                          child: Text(l10n.smtpStartTls),
                        ),
                        DropdownMenuItem(
                          value: SmtpSecurity.implicitTls,
                          child: Text(l10n.smtpImplicitTls),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _security = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.smtpUsername,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.smtpPassword,
                  hintText: settings.hasSmtpPassword
                      ? l10n.smtpPasswordSavedHint
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _from,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.smtpFrom,
                  hintText: l10n.smtpFromHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _recipients,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.smtpRecipients,
                  hintText: l10n.smtpRecipientsHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.emailIcloudHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: actionsBusy ? null : _save,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(l10n.saveEmailSettings),
                  ),
                  OutlinedButton.icon(
                    onPressed: actionsBusy ? null : _test,
                    icon: _isTesting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _isTesting ? l10n.sendingTestEmail : l10n.sendTestEmail,
                    ),
                  ),
                  if (monitor.supportsSystemNotifications)
                    OutlinedButton.icon(
                      onPressed: actionsBusy ? null : _testSystemNotification,
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
                  if (settings.hasSmtpPassword)
                    TextButton.icon(
                      onPressed: actionsBusy
                          ? null
                          : () async {
                              try {
                                await settings.clearSmtpPassword();
                                if (mounted) {
                                  _showMessage(l10n.smtpPasswordCleared);
                                }
                              } catch (error) {
                                if (mounted) {
                                  _showMessage(
                                    l10n.emailFailureUnknown('$error'),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.clearSmtpPassword),
                    ),
                ],
              ),
            ],
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
