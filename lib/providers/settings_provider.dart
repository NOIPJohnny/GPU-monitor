import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ssh_config_parser.dart';
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
/// auto-refresh toggle.
class SettingsProvider extends ChangeNotifier {
  static const _kExcluded = 'ssh_gpu.excluded_hosts';
  static const _kInterval = 'ssh_gpu.refresh_interval';
  static const _kAutoRefresh = 'ssh_gpu.auto_refresh';
  static const _kLanguage = 'ssh_gpu.language';

  static const double minInterval = 0.5;
  static const double maxInterval = 3600;

  List<SshHost> _allHosts = const [];
  Set<String> _excluded = {};
  double _intervalSeconds = 10;
  bool _autoRefresh = false;
  AppLanguage _language = AppLanguage.system;

  List<SshHost> get allHosts => List.unmodifiable(_allHosts);
  Set<String> get excludedHosts => Set.unmodifiable(_excluded);
  double get intervalSeconds => _intervalSeconds;
  bool get autoRefresh => _autoRefresh;
  AppLanguage get language => _language;
  Locale? get locale => _language.locale;

  /// Hosts that are NOT excluded — i.e. what should be queried.
  List<SshHost> get activeHosts => _allHosts
      .where((h) => !_excluded.contains(h.alias))
      .toList(growable: false);

  bool isExcluded(String alias) => _excluded.contains(alias);
  bool isActive(String alias) => !_excluded.contains(alias);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _allHosts = await SshConfigParser.loadDefault();
    final raw = prefs.getString(_kExcluded);
    if (raw != null) {
      _excluded = (jsonDecode(raw) as List).cast<String>().toSet();
    }
    final rawInterval = prefs.get(_kInterval);
    _intervalSeconds = rawInterval is num ? rawInterval.toDouble() : 10;
    if (_intervalSeconds < minInterval) _intervalSeconds = minInterval;
    if (_intervalSeconds > maxInterval) _intervalSeconds = maxInterval;
    _autoRefresh = prefs.getBool(_kAutoRefresh) ?? false;
    _language = switch (prefs.getString(_kLanguage)) {
      'zh' => AppLanguage.zh,
      'en' => AppLanguage.en,
      _ => AppLanguage.system,
    };
    // Drop exclusions that no longer exist in config.
    final aliases = _allHosts.map((h) => h.alias).toSet();
    _excluded = _excluded.intersection(aliases);
    notifyListeners();
  }

  Future<void> setExcluded(String alias, bool exclude) async {
    final changed = exclude ? _excluded.add(alias) : _excluded.remove(alias);
    if (!changed) return;
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

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExcluded, jsonEncode(_excluded.toList()));
    await prefs.setDouble(_kInterval, _intervalSeconds);
    await prefs.setBool(_kAutoRefresh, _autoRefresh);
    await prefs.setString(_kLanguage, _language.name);
  }

  static String formatInterval(double seconds) {
    if (seconds == seconds.roundToDouble()) return seconds.toInt().toString();
    return seconds.toStringAsFixed(1);
  }
}
