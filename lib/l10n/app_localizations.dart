import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SSH GPU Monitor'**
  String get appTitle;

  /// No description provided for @toggleThemeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch theme'**
  String get toggleThemeTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @queryGpuButton.
  ///
  /// In en, this message translates to:
  /// **'Query GPU'**
  String get queryGpuButton;

  /// No description provided for @queryGpuCpuButton.
  ///
  /// In en, this message translates to:
  /// **'Query GPU/CPU'**
  String get queryGpuCpuButton;

  /// No description provided for @noHostsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Host entries found in ~/.ssh/config'**
  String get noHostsTitle;

  /// No description provided for @noHostsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add at least one Host entry to your SSH config, then restart this app.'**
  String get noHostsMessage;

  /// No description provided for @allHostsExcludedTitle.
  ///
  /// In en, this message translates to:
  /// **'All hosts are excluded'**
  String get allHostsExcludedTitle;

  /// No description provided for @allHostsExcludedMessage.
  ///
  /// In en, this message translates to:
  /// **'Re-enable at least one host in Settings to query it.'**
  String get allHostsExcludedMessage;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get unknownUser;

  /// No description provided for @resourceOverview.
  ///
  /// In en, this message translates to:
  /// **'Resource overview'**
  String get resourceOverview;

  /// No description provided for @idleGpu.
  ///
  /// In en, this message translates to:
  /// **'Idle GPU'**
  String get idleGpu;

  /// No description provided for @noIdleGpu.
  ///
  /// In en, this message translates to:
  /// **'No idle GPU'**
  String get noIdleGpu;

  /// No description provided for @userUsage.
  ///
  /// In en, this message translates to:
  /// **'User usage'**
  String get userUsage;

  /// No description provided for @noGpuProcesses.
  ///
  /// In en, this message translates to:
  /// **'No GPU processes'**
  String get noGpuProcesses;

  /// No description provided for @processCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 process} other{{count} processes}}'**
  String processCount(int count);

  /// No description provided for @neverRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Never refreshed'**
  String get neverRefreshed;

  /// No description provided for @lastRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Last refresh {time}'**
  String lastRefreshed(String time);

  /// No description provided for @autoRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Auto refresh · {interval}s'**
  String autoRefreshStatus(String interval);

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @noGpu.
  ///
  /// In en, this message translates to:
  /// **'No GPU'**
  String get noGpu;

  /// No description provided for @autoRefreshEnabledTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto refresh on ({interval}s)'**
  String autoRefreshEnabledTooltip(String interval);

  /// No description provided for @autoRefreshDisabledTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto refresh off'**
  String get autoRefreshDisabledTooltip;

  /// No description provided for @statusLoading.
  ///
  /// In en, this message translates to:
  /// **'Querying'**
  String get statusLoading;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// No description provided for @statusNoGpu.
  ///
  /// In en, this message translates to:
  /// **'No GPU'**
  String get statusNoGpu;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @privateKeyPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Private key passphrase'**
  String get privateKeyPassphraseTitle;

  /// No description provided for @sshPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'SSH password'**
  String get sshPasswordTitle;

  /// No description provided for @hostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host: {alias}'**
  String hostLabel(String alias);

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the private key passphrase'**
  String get passphraseHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the login password'**
  String get passwordHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get confirm;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @noGpuOrDriver.
  ///
  /// In en, this message translates to:
  /// **'No GPU detected, or NVIDIA driver is not installed'**
  String get noGpuOrDriver;

  /// No description provided for @notQueriedYet.
  ///
  /// In en, this message translates to:
  /// **'Not queried yet. Click the refresh button.'**
  String get notQueriedYet;

  /// No description provided for @gpuUtilization.
  ///
  /// In en, this message translates to:
  /// **'GPU utilization'**
  String get gpuUtilization;

  /// No description provided for @cpuPerformance.
  ///
  /// In en, this message translates to:
  /// **'CPU performance'**
  String get cpuPerformance;

  /// No description provided for @cpuUtilization.
  ///
  /// In en, this message translates to:
  /// **'CPU utilization'**
  String get cpuUtilization;

  /// No description provided for @gpuMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get gpuMemory;

  /// No description provided for @systemMemory.
  ///
  /// In en, this message translates to:
  /// **'System memory'**
  String get systemMemory;

  /// No description provided for @logicalCores.
  ///
  /// In en, this message translates to:
  /// **'Logical cores'**
  String get logicalCores;

  /// No description provided for @cpuUsedCores.
  ///
  /// In en, this message translates to:
  /// **'Used cores'**
  String get cpuUsedCores;

  /// No description provided for @loadAverage.
  ///
  /// In en, this message translates to:
  /// **'Load average'**
  String get loadAverage;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// No description provided for @noCpuProcesses.
  ///
  /// In en, this message translates to:
  /// **'No CPU process data'**
  String get noCpuProcesses;

  /// No description provided for @cpuProcessCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 CPU process} other{{count} CPU processes}}'**
  String cpuProcessCount(int count);

  /// No description provided for @processCountWithMemory.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 process} other{{count} processes}} · {memory}'**
  String processCountWithMemory(int count, String memory);

  /// No description provided for @runningElapsed.
  ///
  /// In en, this message translates to:
  /// **'Running {elapsed}'**
  String runningElapsed(String elapsed);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @hostsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Hosts ({enabled}/{total} enabled)'**
  String hostsSectionTitle(int enabled, int total);

  /// No description provided for @noHostInConfig.
  ///
  /// In en, this message translates to:
  /// **'No Host entries found in ~/.ssh/config'**
  String get noHostInConfig;

  /// No description provided for @hostExcludeHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off a host to exclude it from queries'**
  String get hostExcludeHint;

  /// No description provided for @addHostThenRestart.
  ///
  /// In en, this message translates to:
  /// **'Add a Host entry to ~/.ssh/config, then restart'**
  String get addHostThenRestart;

  /// No description provided for @metricsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get metricsSectionTitle;

  /// No description provided for @showCpuMetrics.
  ///
  /// In en, this message translates to:
  /// **'Show CPU metrics'**
  String get showCpuMetrics;

  /// No description provided for @showCpuMetricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Query CPU usage, memory, and top CPU processes'**
  String get showCpuMetricsSubtitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Availability alerts'**
  String get notificationsTitle;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use Windows/macOS system notifications only'**
  String get notificationsSubtitle;

  /// No description provided for @sendTestSystemNotification.
  ///
  /// In en, this message translates to:
  /// **'Send test system notification'**
  String get sendTestSystemNotification;

  /// No description provided for @sendingTestSystemNotification.
  ///
  /// In en, this message translates to:
  /// **'Sending test system notification'**
  String get sendingTestSystemNotification;

  /// No description provided for @testSystemNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Test system notification sent.'**
  String get testSystemNotificationSent;

  /// No description provided for @systemNotificationFailure.
  ///
  /// In en, this message translates to:
  /// **'System notification could not be sent: {error}'**
  String systemNotificationFailure(String error);

  /// No description provided for @hostAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert on GPU availability changes'**
  String get hostAlert;

  /// No description provided for @hostAlertReady.
  ///
  /// In en, this message translates to:
  /// **'Send a system notification after two samples confirm a change'**
  String get hostAlertReady;

  /// No description provided for @hostAlertPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused because auto refresh is off'**
  String get hostAlertPaused;

  /// No description provided for @alertArmedTooltip.
  ///
  /// In en, this message translates to:
  /// **'GPU availability alert monitoring is active'**
  String get alertArmedTooltip;

  /// No description provided for @alertPausedTooltip.
  ///
  /// In en, this message translates to:
  /// **'GPU availability alerts are paused'**
  String get alertPausedTooltip;

  /// No description provided for @alertSendingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sending GPU availability notification'**
  String get alertSendingTooltip;

  /// No description provided for @alertSentTooltip.
  ///
  /// In en, this message translates to:
  /// **'GPU availability notification sent'**
  String get alertSentTooltip;

  /// No description provided for @alertErrorTooltip.
  ///
  /// In en, this message translates to:
  /// **'System notification failed: {error}'**
  String alertErrorTooltip(String error);

  /// No description provided for @autoRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto refresh'**
  String get autoRefreshTitle;

  /// No description provided for @enableAutoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Enable auto refresh'**
  String get enableAutoRefresh;

  /// No description provided for @autoRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Query again every {interval} seconds'**
  String autoRefreshSubtitle(String interval);

  /// No description provided for @refreshInterval.
  ///
  /// In en, this message translates to:
  /// **'Refresh interval'**
  String get refreshInterval;

  /// No description provided for @refreshIntervalRange.
  ///
  /// In en, this message translates to:
  /// **'Range {min}-{max} seconds'**
  String refreshIntervalRange(String min, String max);

  /// No description provided for @autoRefreshTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: the slider goes up to {sliderMax}s; the input accepts up to {max}s.'**
  String autoRefreshTip(String sliderMax, String max);

  /// No description provided for @menuBarShortcutTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu bar shortcut'**
  String get menuBarShortcutTitle;

  /// No description provided for @menuBarShortcutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Press the shortcut to show or hide the panel'**
  String get menuBarShortcutSubtitle;

  /// No description provided for @menuBarShortcutRecord.
  ///
  /// In en, this message translates to:
  /// **'Click to record'**
  String get menuBarShortcutRecord;

  /// No description provided for @menuBarShortcutRecording.
  ///
  /// In en, this message translates to:
  /// **'Press a key combination'**
  String get menuBarShortcutRecording;

  /// No description provided for @menuBarShortcutReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get menuBarShortcutReset;

  /// No description provided for @menuBarShortcutInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use at least one modifier key'**
  String get menuBarShortcutInvalid;

  /// No description provided for @desktopBehaviorTitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop behavior'**
  String get desktopBehaviorTitle;

  /// No description provided for @closeToBackground.
  ///
  /// In en, this message translates to:
  /// **'Keep running when the window is closed'**
  String get closeToBackground;

  /// No description provided for @closeToBackgroundWindowsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide in the system tray; monitoring and alerts continue'**
  String get closeToBackgroundWindowsSubtitle;

  /// No description provided for @closeToBackgroundMacosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the background; use the menu bar icon or Dock'**
  String get closeToBackgroundMacosSubtitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Use system setting'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Use system language'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
