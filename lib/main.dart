import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/gpu_monitor_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/desktop_lifecycle_controller.dart';
import 'services/macos_menu_bar_bridge.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Force instance to be ready before providers read it during construction.
  await SharedPreferences.getInstance();

  final settings = SettingsProvider();
  final theme = ThemeProvider();
  await Future.wait([settings.load(), theme.load()]);
  final desktopLifecycleController = DesktopLifecycleController(settings);
  await desktopLifecycleController.initialize();
  final monitor = GpuMonitorProvider(settings);
  final navigatorKey = GlobalKey<NavigatorState>();
  final menuBarBridge = MacosMenuBarBridge();
  menuBarBridge.bind(
    monitor: monitor,
    settings: settings,
    theme: theme,
    onOpenSettings: () {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    },
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: monitor),
      ],
      child: SshGpuMonitorApp(
        navigatorKey: navigatorKey,
        onHideToBackground: desktopLifecycleController.hideToBackground,
        onBeforeCredentialDialog: desktopLifecycleController.showMainWindow,
      ),
    ),
  );
}
