import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gpu_monitor/providers/settings_provider.dart';
import 'package:gpu_monitor/services/menu_bar_shortcut.dart';

void main() {
  group('MenuBarShortcut', () {
    test('validates and formats shortcut values', () {
      expect(MenuBarShortcut.isValid('cmd+shift+g'), isTrue);
      expect(MenuBarShortcut.display('cmd+shift+g'), '⌘⇧G');
      expect(MenuBarShortcut.isValid('g'), isFalse);
      expect(MenuBarShortcut.isValid('cmd+cmd+g'), isFalse);
    });
  });

  group('SettingsProvider menu bar shortcut', () {
    test('defaults and persists the shortcut', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(hostLoader: () async => const []);

      await settings.load();
      expect(settings.menuBarShortcut, MenuBarShortcut.defaultValue);

      await settings.setMenuBarShortcut('cmd+alt+k');
      final reloaded = SettingsProvider(hostLoader: () async => const []);
      await reloaded.load();

      expect(reloaded.menuBarShortcut, 'cmd+alt+k');
    });

    test('ignores invalid shortcuts', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider(hostLoader: () async => const []);

      await settings.load();
      await settings.setMenuBarShortcut('g');

      expect(settings.menuBarShortcut, MenuBarShortcut.defaultValue);
    });
  });
}
