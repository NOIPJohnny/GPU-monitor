import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

class SshGpuMonitorApp extends StatelessWidget {
  const SshGpuMonitorApp({
    super.key,
    this.navigatorKey,
    this.onHideToBackground,
    this.onBeforeCredentialDialog,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final Future<void> Function()? onHideToBackground;
  final Future<void> Function()? onBeforeCredentialDialog;

  void _hideToBackground() {
    final callback = onHideToBackground;
    if (callback != null) unawaited(callback());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyW, control: true):
              _hideToBackground,
          const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
              _hideToBackground,
        },
        child: Focus(autofocus: true, child: child ?? const SizedBox.shrink()),
      ),
      themeMode: theme.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(onBeforeCredentialDialog: onBeforeCredentialDialog),
    );
  }
}
