import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gpu_monitor/models/ssh_host.dart';
import 'package:gpu_monitor/providers/gpu_monitor_provider.dart';
import 'package:gpu_monitor/providers/settings_provider.dart';
import 'package:gpu_monitor/providers/theme_provider.dart';
import 'package:gpu_monitor/services/macos_menu_bar_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('gpu_monitor/menu_bar');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('publishes active host data to the macOS channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({});

    final settings = SettingsProvider(
      hostLoader: () async => const [SshHost(alias: 'node-1')],
    );
    await settings.load();
    final theme = ThemeProvider();
    final monitor = GpuMonitorProvider(settings);
    final calls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    final bridge = MacosMenuBarBridge();
    bridge.bind(
      monitor: monitor,
      settings: settings,
      theme: theme,
      onOpenSettings: () {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(calls, isNotEmpty);
    expect(calls.last.method, 'updateSnapshot');
    final snapshot = Map<String, dynamic>.from(calls.last.arguments as Map);
    expect(snapshot['themeMode'], 'system');
    expect(snapshot['menuBarShortcut'], 'cmd+shift+g');
    expect(snapshot['hosts'], hasLength(1));
    expect((snapshot['hosts'] as List).single['status'], 'idle');

    bridge.dispose();
    monitor.dispose();
  });
}
