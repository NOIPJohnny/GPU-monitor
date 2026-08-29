// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SSH GPU Monitor';

  @override
  String get toggleThemeTooltip => 'Switch theme';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get queryGpuButton => 'Query GPU';

  @override
  String get queryGpuCpuButton => 'Query GPU/CPU';

  @override
  String get noHostsTitle => 'No Host entries found in ~/.ssh/config';

  @override
  String get noHostsMessage =>
      'Add at least one Host entry to your SSH config, then restart this app.';

  @override
  String get allHostsExcludedTitle => 'All hosts are excluded';

  @override
  String get allHostsExcludedMessage =>
      'Re-enable at least one host in Settings to query it.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get resourceOverview => 'Resource overview';

  @override
  String get idleGpu => 'Idle GPU';

  @override
  String get noIdleGpu => 'No idle GPU';

  @override
  String get userUsage => 'User usage';

  @override
  String get noGpuProcesses => 'No GPU processes';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processes',
      one: '1 process',
    );
    return '$_temp0';
  }

  @override
  String get neverRefreshed => 'Never refreshed';

  @override
  String lastRefreshed(String time) {
    return 'Last refresh $time';
  }

  @override
  String autoRefreshStatus(String interval) {
    return 'Auto refresh · ${interval}s';
  }

  @override
  String get online => 'Online';

  @override
  String get error => 'Error';

  @override
  String get noGpu => 'No GPU';

  @override
  String autoRefreshEnabledTooltip(String interval) {
    return 'Auto refresh on (${interval}s)';
  }

  @override
  String get autoRefreshDisabledTooltip => 'Auto refresh off';

  @override
  String get statusLoading => 'Querying';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusError => 'Error';

  @override
  String get statusNoGpu => 'No GPU';

  @override
  String get statusIdle => 'Idle';

  @override
  String get privateKeyPassphraseTitle => 'Private key passphrase';

  @override
  String get sshPasswordTitle => 'SSH password';

  @override
  String hostLabel(String alias) {
    return 'Host: $alias';
  }

  @override
  String get passwordLabel => 'Password';

  @override
  String get passphraseHint => 'Enter the private key passphrase';

  @override
  String get passwordHint => 'Enter the login password';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get noGpuOrDriver =>
      'No GPU detected, or NVIDIA driver is not installed';

  @override
  String get notQueriedYet => 'Not queried yet. Click the refresh button.';

  @override
  String get gpuUtilization => 'GPU utilization';

  @override
  String get cpuPerformance => 'CPU performance';

  @override
  String get cpuUtilization => 'CPU utilization';

  @override
  String get gpuMemory => 'Memory';

  @override
  String get systemMemory => 'System memory';

  @override
  String get logicalCores => 'Logical cores';

  @override
  String get cpuUsedCores => 'Used cores';

  @override
  String get loadAverage => 'Load average';

  @override
  String get temperature => 'Temperature';

  @override
  String get power => 'Power';

  @override
  String get noCpuProcesses => 'No CPU process data';

  @override
  String cpuProcessCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count CPU processes',
      one: '1 CPU process',
    );
    return '$_temp0';
  }

  @override
  String processCountWithMemory(int count, String memory) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processes',
      one: '1 process',
    );
    return '$_temp0 · $memory';
  }

  @override
  String runningElapsed(String elapsed) {
    return 'Running $elapsed';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String hostsSectionTitle(int enabled, int total) {
    return 'Hosts ($enabled/$total enabled)';
  }

  @override
  String get noHostInConfig => 'No Host entries found in ~/.ssh/config';

  @override
  String get hostExcludeHint => 'Turn off a host to exclude it from queries';

  @override
  String get addHostThenRestart =>
      'Add a Host entry to ~/.ssh/config, then restart';

  @override
  String get metricsSectionTitle => 'Metrics';

  @override
  String get showCpuMetrics => 'Show CPU metrics';

  @override
  String get showCpuMetricsSubtitle =>
      'Query CPU usage, memory, and top CPU processes';

  @override
  String get notificationsTitle => 'Availability alerts';

  @override
  String get notificationsSubtitle =>
      'Use Windows/macOS system notifications only';

  @override
  String get sendTestSystemNotification => 'Send test system notification';

  @override
  String get sendingTestSystemNotification =>
      'Sending test system notification';

  @override
  String get testSystemNotificationSent => 'Test system notification sent.';

  @override
  String systemNotificationFailure(String error) {
    return 'System notification could not be sent: $error';
  }

  @override
  String get hostAlert => 'Alert on GPU availability changes';

  @override
  String get hostAlertReady =>
      'Send a system notification after two samples confirm a change';

  @override
  String get hostAlertPaused => 'Paused because auto refresh is off';

  @override
  String get alertArmedTooltip => 'GPU availability alert monitoring is active';

  @override
  String get alertPausedTooltip => 'GPU availability alerts are paused';

  @override
  String get alertSendingTooltip => 'Sending GPU availability notification';

  @override
  String get alertSentTooltip => 'GPU availability notification sent';

  @override
  String alertErrorTooltip(String error) {
    return 'System notification failed: $error';
  }

  @override
  String get autoRefreshTitle => 'Auto refresh';

  @override
  String get enableAutoRefresh => 'Enable auto refresh';

  @override
  String autoRefreshSubtitle(String interval) {
    return 'Query again every $interval seconds';
  }

  @override
  String get refreshInterval => 'Refresh interval';

  @override
  String refreshIntervalRange(String min, String max) {
    return 'Range $min-$max seconds';
  }

  @override
  String autoRefreshTip(String sliderMax, String max) {
    return 'Tip: the slider goes up to ${sliderMax}s; the input accepts up to ${max}s.';
  }

  @override
  String get menuBarShortcutTitle => 'Menu bar shortcut';

  @override
  String get menuBarShortcutSubtitle =>
      'Press the shortcut to show or hide the panel';

  @override
  String get menuBarShortcutRecord => 'Click to record';

  @override
  String get menuBarShortcutRecording => 'Press a key combination';

  @override
  String get menuBarShortcutReset => 'Reset';

  @override
  String get menuBarShortcutInvalid => 'Use at least one modifier key';

  @override
  String get desktopBehaviorTitle => 'Desktop behavior';

  @override
  String get closeToBackground => 'Keep running when the window is closed';

  @override
  String get closeToBackgroundWindowsSubtitle =>
      'Hide in the system tray; monitoring and alerts continue';

  @override
  String get closeToBackgroundMacosSubtitle =>
      'Keep running in the background; use the menu bar icon or Dock';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'Use system setting';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageSystem => 'Use system language';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';
}
