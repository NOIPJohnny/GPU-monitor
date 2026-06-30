import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/host_query_result.dart';
import '../models/ssh_host.dart';
import '../services/ssh_executor.dart';
import '../services/gpu_query_service.dart';
import 'settings_provider.dart';

/// Core runtime state: current query results, refresh status, and the
/// auto-refresh timer. Depends on [SettingsProvider] for which hosts to query.
class GpuMonitorProvider extends ChangeNotifier {
  final SettingsProvider _settings;
  late final SshExecutor _executor;
  late final GpuQueryService _service;

  final Map<String, HostQueryResult> _results = {};
  Map<String, HostQueryResult> get results => Map.unmodifiable(_results);

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _isShowingManualRefresh = false;
  bool get isShowingManualRefresh => _isShowingManualRefresh;

  DateTime? _lastRefreshedAt;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;

  /// Callback wired by the UI to handle passphrase/password prompts from the
  /// SSH executor. See [SshExecutor.onCredential].
  CredentialProvider? onCredentialProvider;

  Timer? _timer;
  Duration? _armedInterval;

  GpuMonitorProvider(this._settings) {
    _executor = SshExecutor(onCredential: _handleCredential);
    _service = GpuQueryService(_executor);
    _settings.addListener(_onSettingsChanged);
    if (_settings.autoRefresh) _armTimer();
  }

  Future<String?> _handleCredential(
    CredentialKind kind,
    SshHost host, {
    String? reason,
  }) async {
    final cb = onCredentialProvider;
    if (cb == null) return null;
    return cb(kind, host, reason: reason);
  }

  /// Trigger an immediate refresh. Safe to call concurrently: the second call
  /// is dropped while one is in flight.
  Future<void> refresh({bool showLoading = true}) async {
    if (_isRefreshing) return;
    final hosts = _settings.activeHosts;
    _isRefreshing = true;
    _isShowingManualRefresh = showLoading;
    // Drop results for hosts no longer active.
    final activeAliases = hosts.map((h) => h.alias).toSet();
    _results.removeWhere((k, _) => !activeAliases.contains(k));
    for (final h in hosts) {
      if (showLoading || !_results.containsKey(h.alias)) {
        _results[h.alias] = HostQueryResult.loading(h.alias);
      }
    }
    notifyListeners();

    try {
      final fresh = await _service.queryAll(hosts);
      _results
        ..clear()
        ..addAll(fresh);
    } finally {
      _isRefreshing = false;
      _isShowingManualRefresh = false;
      _lastRefreshedAt = DateTime.now();
      notifyListeners();
    }
  }

  void _onSettingsChanged() {
    // Re-arm timer if interval or auto-refresh changed.
    if (_settings.autoRefresh) {
      _armTimer();
    } else {
      _disarmTimer();
    }
  }

  void _armTimer() {
    final want = Duration(
      milliseconds: (_settings.intervalSeconds * 1000).round(),
    );
    if (_timer?.isActive == true && _armedInterval == want) return;
    _armedInterval = want;
    _timer?.cancel();
    _timer = Timer.periodic(want, (_) => refresh(showLoading: false));
  }

  void _disarmTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _disarmTimer();
    _executor.dispose();
    super.dispose();
  }
}
