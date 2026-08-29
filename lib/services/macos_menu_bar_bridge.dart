import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/host_query_result.dart';
import '../providers/gpu_monitor_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class MacosMenuBarBridge {
  static const _channel = MethodChannel('gpu_monitor/menu_bar');

  GpuMonitorProvider? _monitor;
  SettingsProvider? _settings;
  ThemeProvider? _theme;
  VoidCallback? _onOpenSettings;
  bool _publishRequested = false;
  bool _isPublishing = false;

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  void bind({
    required GpuMonitorProvider monitor,
    required SettingsProvider settings,
    required ThemeProvider theme,
    required VoidCallback onOpenSettings,
  }) {
    if (!_isMacOS) return;

    _monitor = monitor;
    _settings = settings;
    _theme = theme;
    _onOpenSettings = onOpenSettings;
    _channel.setMethodCallHandler(_handleMethodCall);
    monitor.addListener(_requestPublish);
    settings.addListener(_requestPublish);
    theme.addListener(_requestPublish);
    _requestPublish();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'refresh':
        await _monitor?.refresh();
        return;
      case 'openSettings':
        _onOpenSettings?.call();
        return;
      default:
        throw MissingPluginException();
    }
  }

  void _requestPublish() {
    if (!_isMacOS) return;
    _publishRequested = true;
    if (!_isPublishing) unawaited(_publishLatest());
  }

  Future<void> _publishLatest() async {
    _isPublishing = true;
    try {
      while (_publishRequested) {
        _publishRequested = false;
        try {
          await _channel.invokeMethod('updateSnapshot', _buildSnapshot());
        } on MissingPluginException {
          return;
        } on PlatformException {
          return;
        }
      }
    } finally {
      _isPublishing = false;
    }
  }

  Map<String, dynamic> _buildSnapshot() {
    final monitor = _monitor!;
    final settings = _settings!;
    final theme = _theme!;

    return {
      'language': _languageCode(settings),
      'themeMode': theme.themeMode.name,
      'isRefreshing': monitor.isRefreshing,
      'autoRefresh': settings.autoRefresh,
      'intervalSeconds': settings.intervalSeconds,
      'lastRefreshedAt': monitor.lastRefreshedAt?.toIso8601String(),
      'hosts': [
        for (final host in settings.activeHosts)
          _hostSnapshot(host.alias, monitor.results[host.alias]),
      ],
    };
  }

  String _languageCode(SettingsProvider settings) {
    switch (settings.language) {
      case AppLanguage.zh:
        return 'zh';
      case AppLanguage.en:
        return 'en';
      case AppLanguage.system:
        return PlatformDispatcher.instance.locale.languageCode == 'zh'
            ? 'zh'
            : 'en';
    }
  }

  Map<String, dynamic> _hostSnapshot(String alias, HostQueryResult? result) {
    return {
      'alias': alias,
      'status': result?.status.name ?? QueryStatus.idle.name,
      'errorMessage': result?.errorMessage,
      'fetchedAt': result?.fetchedAt.toIso8601String(),
      'gpus': [
        for (final gpu in result?.gpus ?? const [])
          {
            'index': gpu.index,
            'name': gpu.name,
            'gpuUtil': gpu.gpuUtil,
            'memUsed': gpu.memUsed,
            'memTotal': gpu.memTotal,
            'temp': gpu.temp,
            'powerDraw': gpu.powerDraw,
            'processes': [
              for (final process in gpu.processes)
                {
                  'user': process.user,
                  'name': process.name,
                  'command': process.command,
                  'usedMemory': process.usedMemory,
                },
            ],
          },
      ],
    };
  }

  void dispose() {
    if (!_isMacOS) return;
    _monitor?.removeListener(_requestPublish);
    _settings?.removeListener(_requestPublish);
    _theme?.removeListener(_requestPublish);
    _channel.setMethodCallHandler(null);
  }
}
