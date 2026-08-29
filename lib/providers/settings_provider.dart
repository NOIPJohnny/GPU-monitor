import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ssh_config_parser.dart';
import '../services/menu_bar_shortcut.dart';
import '../models/ssh_host.dart';

enum AppLanguage {
  system,
  zh,
  en;

  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.en => const Locale('en'),
  };
}

/// Holds user preferences and the list of hosts discovered in ~/.ssh/config.
/// Persisted via SharedPreferences: excluded aliases, refresh interval,
/// auto-refresh toggle, CPU monitoring toggle, menu bar shortcut.
class SettingsProvider extends ChangeNotifier {
  static const _kExcluded = 'ssh_gpu.excluded_hosts';
  static const _kInterval = 'ssh_gpu.refresh_interval';
  static const _kAutoRefresh = 'ssh_gpu.auto_refresh';
  static const _kLanguage = 'ssh_gpu.language';
  static const _kShowCpuMetrics = 'ssh_gpu.show_cpu_metrics';
  static const _kCloseToBackground = 'ssh_gpu.close_to_background';
  static const _kAlertHosts = 'ssh_gpu.alert_hosts';
  static const _kMenuBarShortcut = 'ssh_gpu.menu_bar_shortcut';

  static const double minInterval = 0.5;
  static const double maxInterval = 3600;

  List<SshHost> _allHosts = const [];
  Set<String> _excluded = {};
  double _intervalSeconds = 10;
  bool _autoRefresh = false;
  bool _showCpuMetrics = false;
  bool _closeToBackground = false;
  AppLanguage _language = AppLanguage.system;
  Set<String> _alertHosts = {};
  String _menuBarShortcut = MenuBarShortcut.defaultValue;

  final Future<List<SshHost>> Function() _hostLoader;

  SettingsProvider({Future<List<SshHost>> Function()? hostLoader})
    : _hostLoader = hostLoader ?? SshConfigParser.loadDefault;

  List<SshHost> get allHosts => List.unmodifiable(_allHosts);
  Set<String> get excludedHosts => Set.unmodifiable(_excluded);
  double get intervalSeconds => _intervalSeconds;
  bool get autoRefresh => _autoRefresh;
  bool get showCpuMetrics => _showCpuMetrics;
  bool get closeToBackground => _closeToBackground;
  AppLanguage get language => _language;
  Locale? get locale => _language.locale;
  Set<String> get alertHosts => Set.unmodifiable(_alertHosts);
  String get menuBarShortcut => _menuBarShortcut;

  /// Hosts that are NOT excluded — i.e. what should be queried.
  List<SshHost> get activeHosts => _allHosts
      .where((h) => !_excluded.contains(h.alias))
      .toList(growable: false);

  bool isExcluded(String alias) => _excluded.contains(alias);
  bool isActive(String alias) => !_excluded.contains(alias);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _allHosts = await _hostLoader();
    final raw = prefs.getString(_kExcluded);
    if (raw != null) {
      _excluded = (jsonDecode(raw) as List).cast<String>().toSet();
    }
    final rawInterval = prefs.get(_kInterval);
    _intervalSeconds = rawInterval is num ? rawInterval.toDouble() : 10;
    if (_intervalSeconds < minInterval) _intervalSeconds = minInterval;
    if (_intervalSeconds > maxInterval) _intervalSeconds = maxInterval;
    _autoRefresh = prefs.getBool(_kAutoRefresh) ?? false;
    _showCpuMetrics = prefs.getBool(_kShowCpuMetrics) ?? false;
    _closeToBackground = prefs.getBool(_kCloseToBackground) ?? false;
    _language = switch (prefs.getString(_kLanguage)) {
      'zh' => AppLanguage.zh,
      'en' => AppLanguage.en,
      _ => AppLanguage.system,
    };
    final rawAlerts = prefs.getString(_kAlertHosts);
    if (rawAlerts != null) {
      _alertHosts = (jsonDecode(rawAlerts) as List).cast<String>().toSet();
    }
    final rawShortcut = prefs.getString(_kMenuBarShortcut);
    _menuBarShortcut =
        rawShortcut != null && MenuBarShortcut.isValid(rawShortcut)
        ? rawShortcut
        : MenuBarShortcut.defaultValue;
    // Drop exclusions that no longer exist in config.
    final aliases = _allHosts.map((h) => h.alias).toSet();
    _excluded = _excluded.intersection(aliases);
    _alertHosts = _alertHosts.intersection(aliases)..removeAll(_excluded);
    notifyListeners();
  }

  Future<void> setExcluded(String alias, bool exclude) async {
    final changed = exclude ? _excluded.add(alias) : _excluded.remove(alias);
    if (!changed) return;
    if (exclude) _alertHosts.remove(alias);
    notifyListeners();
    await _persist();
  }

  Future<void> setInterval(double seconds) async {
    seconds = seconds.clamp(minInterval, maxInterval).toDouble();
    if (seconds == _intervalSeconds) return;
    _intervalSeconds = seconds;
    notifyListeners();
    await _persist();
  }

  Future<void> setAutoRefresh(bool enabled) async {
    if (enabled == _autoRefresh) return;
    _autoRefresh = enabled;
    notifyListeners();
    await _persist();
  }

  bool isHostAlertEnabled(String alias) => _alertHosts.contains(alias);

  Future<bool> setHostAlert(String alias, bool enabled) async {
    if (enabled && !isActive(alias)) return false;
    final changed = enabled
        ? _alertHosts.add(alias)
        : _alertHosts.remove(alias);
    if (!changed) return true;
    if (enabled) _autoRefresh = true;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> setShowCpuMetrics(bool enabled) async {
    if (enabled == _showCpuMetrics) return;
    _showCpuMetrics = enabled;
    notifyListeners();
    await _persist();
  }

  Future<void> setCloseToBackground(bool enabled) async {
    if (enabled == _closeToBackground) return;
    _closeToBackground = enabled;
    notifyListeners();
    await _persist();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    await _persist();
  }

  Future<void> setMenuBarShortcut(String shortcut) async {
    shortcut = shortcut.toLowerCase();
    if (!MenuBarShortcut.isValid(shortcut) || shortcut == _menuBarShortcut) {
      return;
    }
    _menuBarShortcut = shortcut;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExcluded, jsonEncode(_excluded.toList()));
    await prefs.setDouble(_kInterval, _intervalSeconds);
    await prefs.setBool(_kAutoRefresh, _autoRefresh);
    await prefs.setBool(_kShowCpuMetrics, _showCpuMetrics);
    await prefs.setBool(_kCloseToBackground, _closeToBackground);
    await prefs.setString(_kLanguage, _language.name);
    await prefs.setString(_kAlertHosts, jsonEncode(_alertHosts.toList()));
    await prefs.setString(_kMenuBarShortcut, _menuBarShortcut);
  }

  static String formatInterval(double seconds) {
    if (seconds == seconds.roundToDouble()) return seconds.toInt().toString();
    return seconds.toStringAsFixed(1);
  }
}
