import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/gpu_availability_event.dart';
import 'alert_delivery_queue.dart';

typedef NotificationLanguageLoader = String Function();

class SystemNotificationContent {
  final String title;
  final String body;

  const SystemNotificationContent({required this.title, required this.body});
}

/// Sends native Windows and macOS notifications for confirmed GPU state
/// transitions. Other platforms are intentionally ignored for now.
class SystemNotificationSender implements NotificationSender {
  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationLanguageLoader _loadLanguageCode;
  Future<void>? _initialization;
  int _nextNotificationId = 1;

  SystemNotificationSender({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationLanguageLoader? loadLanguageCode,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _loadLanguageCode = loadLanguageCode ?? (() => 'en');

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> initialize() async {
    if (!isSupported) return;
    final pending = _initialization ??= _initialize();
    try {
      await pending;
    } catch (_) {
      if (identical(_initialization, pending)) _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    const settings = InitializationSettings(
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      windows: WindowsInitializationSettings(
        appName: 'SSH GPU Monitor',
        appUserModelId: 'com.example.gpumonitor',
        guid: '68c45eb2-903d-47c7-8ef0-723fc20f540b',
      ),
    );
    await _plugin.initialize(settings: settings);

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
      if (granted == false) {
        throw StateError('System notification permission was denied.');
      }
    }
  }

  @override
  Future<void> send(GpuAvailabilityEvent event) async {
    if (!isSupported) return;
    await initialize();
    final content = eventContent(event, _loadLanguageCode());
    await _show(content, payload: event.hostAlias);
  }

  Future<void> sendTest() async {
    if (!isSupported) {
      throw UnsupportedError(
        'System notifications are supported on Windows and macOS only.',
      );
    }
    await initialize();
    await _show(testContent(_loadLanguageCode()), payload: 'test');
  }

  Future<void> _show(
    SystemNotificationContent content, {
    required String payload,
  }) async {
    await _plugin.show(
      id: _nextNotificationId++,
      title: content.title,
      body: content.body,
      notificationDetails: const NotificationDetails(
        macOS: DarwinNotificationDetails(
          presentBanner: true,
          presentList: true,
          presentSound: true,
          threadIdentifier: 'gpu-monitor-alerts',
        ),
        windows: WindowsNotificationDetails(
          duration: WindowsNotificationDuration.long,
        ),
      ),
      payload: payload,
    );
  }

  @visibleForTesting
  static SystemNotificationContent eventContent(
    GpuAvailabilityEvent event,
    String languageCode,
  ) {
    final zh = languageCode.toLowerCase().startsWith('zh');
    final previous = availabilityText(event.previous, languageCode);
    final current = availabilityText(event.current, languageCode);
    return SystemNotificationContent(
      title: zh
          ? '${event.hostAlias} GPU 状态变化'
          : '${event.hostAlias} GPU status changed',
      body: zh
          ? '服务器状态已确认：$previous → $current'
          : 'Server status confirmed: $previous → $current',
    );
  }

  @visibleForTesting
  static SystemNotificationContent testContent(String languageCode) {
    final zh = languageCode.toLowerCase().startsWith('zh');
    return SystemNotificationContent(
      title: zh ? 'GPU Monitor 测试通知' : 'GPU Monitor test notification',
      body: zh ? '本地系统通知工作正常。' : 'Local system notifications are working.',
    );
  }

  @visibleForTesting
  static String availabilityText(
    GpuAvailability availability,
    String languageCode,
  ) {
    final zh = languageCode.toLowerCase().startsWith('zh');
    return switch (availability) {
      GpuAvailability.idle => zh ? '空闲' : 'idle',
      GpuAvailability.busy => zh ? '忙碌' : 'busy',
    };
  }
}
