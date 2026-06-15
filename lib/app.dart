import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

class SshGpuMonitorApp extends StatelessWidget {
  const SshGpuMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'SSH GPU 监控',
      debugShowCheckedModeBanner: false,
      themeMode: theme.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo, brightness: Brightness.light),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo, brightness: Brightness.dark),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}
