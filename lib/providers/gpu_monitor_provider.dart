import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/host_query_result.dart';
import '../models/ssh_host.dart';
import '../services/alert_delivery_queue.dart';
import '../services/gpu_alert_engine.dart';
import '../services/system_notification_sender.dart';
import '../services/ssh_executor.dart';
import '../services/gpu_query_service.dart';
import 'settings_provider.dart';

/// Core runtime state: current query results, refresh status, and the
/// auto-refresh timer. Depends on [SettingsProvider] for which hosts to query.
class GpuMonitorProvider extends ChangeNotifier {
  final SettingsProvider _settings;
  late final SshExecutor _executor;
  late final GpuQueryService _service;
  late final SystemNotificationSender _systemNotificationSender;
  late final AlertDeliveryQueue _alertDeliveryQueue;
  final GpuAlertEngine _alertEngine = GpuAlertEngine();

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
  bool _queuedAutoRefresh = false;
  bool _wasAutoRefresh = false;
  Map<String, HostAlertDelivery> get alertDeliveries =>
      _alertDeliveryQueue.deliveries;

  GpuMonitorProvider(
    this._settings, {
    NotificationSender? notificationSender,
    SystemNotificationSender? systemNotificationSender,
  }) {
    _executor = SshExecutor(onCredential: _handleCredential);
    _service = GpuQueryService(_executor);
    _systemNotificationSender =
        systemNotificationSender ??
        SystemNotificationSender(
          loadLanguageCode: () =>
              (_settings.locale ?? PlatformDispatcher.instance.locale)
                  .languageCode,
        );
    _alertDeliveryQueue = AlertDeliveryQueue(
      notificationSender ?? _systemNotificationSender,
      onChanged: notifyListeners,
    );
    _wasAutoRefresh = _settings.autoRefresh;
    _settings.addListener(_onSettingsChanged);
    if (_settings.autoRefresh) {
      _syncAlertHosts();
      _armTimer();
    }
  }

  bool get supportsSystemNotifications => _systemNotificationSender.isSupported;

  Future<void> sendTestSystemNotification() =>
      _systemNotificationSender.sendTest();

  Future<String?> _handleCredential(
    CredentialKind kind,
    SshHost host, {
    String? reason,
  }) async {
    final cb = onCredentialProvider;
    if (cb == null) return null;
    return cb(kind, host, reason: reason);
  }

  /// Trigger an immediate refresh. Concurrent manual calls are ignored; one
  /// automatic tick can be queued while a refresh is in flight.
  Future<void> refresh({bool showLoading = true}) async {
    if (_isRefreshing) {
      if (!showLoading) _queuedAutoRefresh = true;
      return;
    }
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
      final fresh = await _service.queryAll(
        hosts,
        includeCpu: _settings.showCpuMetrics,
      );
      _results
        ..clear()
        ..addAll(fresh);
      if (_settings.autoRefresh) {
        _processAlerts(fresh);
        _dispatchPendingAlerts();
      }
    } finally {
      _isRefreshing = false;
      _isShowingManualRefresh = false;
      _lastRefreshedAt = DateTime.now();
      notifyListeners();
      if (_queuedAutoRefresh && _settings.autoRefresh) {
        _queuedAutoRefresh = false;
        unawaited(refresh(showLoading: false));
      }
    }
  }

  void _onSettingsChanged() {
    if (!_settings.showCpuMetrics) {
      var changed = false;
      _results.updateAll((_, result) {
        if (result.cpu == null) return result;
        changed = true;
        return result.withoutCpu();
      });
      if (changed) notifyListeners();
    }

    if (_settings.autoRefresh) {
      if (!_wasAutoRefresh) {
        _clearAlertRuntime();
      }
      _syncAlertHosts();
    } else if (_wasAutoRefresh) {
      _clearAlertRuntime();
    }
    _wasAutoRefresh = _settings.autoRefresh;

    // Re-arm timer if interval or auto-refresh changed.
    if (_settings.autoRefresh) {
      _armTimer();
    } else {
      _disarmTimer();
    }
  }

  void _syncAlertHosts() {
    final enabled = _settings.alertHosts.where(_settings.isActive).toSet();
    _alertEngine.syncEnabledHosts(enabled);
    _alertDeliveryQueue.retainHosts(enabled);
  }

  void _processAlerts(Map<String, HostQueryResult> fresh) {
    for (final alias in _settings.alertHosts) {
      final result = fresh[alias];
      if (result == null) continue;
      final event = _alertEngine.process(alias, result);
      if (event == null) continue;
      _alertDeliveryQueue.enqueue(event);
    }
  }

  void _dispatchPendingAlerts() {
    if (!_alertDeliveryQueue.hasPending) return;
    unawaited(_alertDeliveryQueue.dispatch());
  }

  void _clearAlertRuntime() {
    _alertEngine.resetAll();
    _alertDeliveryQueue.clear();
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
    _queuedAutoRefresh = false;
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _disarmTimer();
    _executor.dispose();
    super.dispose();
  }
}
