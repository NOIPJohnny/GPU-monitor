import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/gpu_monitor_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Force instance to be ready before providers read it during construction.
  await SharedPreferences.getInstance();

  final settings = SettingsProvider();
  final theme = ThemeProvider();
  await Future.wait([settings.load(), theme.load()]);

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider(create: (_) => GpuMonitorProvider(settings)),
    ],
    child: const SshGpuMonitorApp(),
  ));
}
