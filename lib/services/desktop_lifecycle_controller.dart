import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/settings_provider.dart';

class DesktopLifecycleController with WindowListener, TrayListener {
  DesktopLifecycleController(this._settings);

  static const _showWindowKey = 'show_window';
  static const _quitAppKey = 'quit_app';

  final SettingsProvider _settings;
  bool _trayCreated = false;
  bool _isQuitting = false;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> initialize() async {
    if (!_isSupported) return;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    if (_isWindows) trayManager.addListener(this);
    _settings.addListener(_onSettingsChanged);
    await _applySettings();
  }

  void _onSettingsChanged() {
    unawaited(_applySettings());
  }

  Future<void> _applySettings() async {
    await windowManager.setPreventClose(
      _isMacOS || _settings.closeToBackground,
    );
    if (!_isWindows) return;
    if (_settings.closeToBackground) {
      await _createOrUpdateTray();
    } else if (_trayCreated) {
      await trayManager.destroy();
      _trayCreated = false;
    }
  }

  Future<void> _createOrUpdateTray() async {
    final useChinese =
        _settings.language == AppLanguage.zh ||
        (_settings.language == AppLanguage.system &&
            PlatformDispatcher.instance.locale.languageCode == 'zh');
    if (!_trayCreated) {
      await trayManager.setIcon('windows/runner/resources/app_icon.ico');
      await trayManager.setToolTip('GPU Monitor');
      _trayCreated = true;
    }
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: _showWindowKey,
            label: useChinese ? '显示窗口' : 'Show window',
          ),
          MenuItem.separator(),
          MenuItem(
            key: _quitAppKey,
            label: useChinese ? '退出 GPU Monitor' : 'Quit GPU Monitor',
          ),
        ],
      ),
    );
  }

  Future<void> hideToBackground() async {
    if (!_isSupported || _isQuitting) return;
    if (_isWindows) await _createOrUpdateTray();
    await windowManager.hide();
  }

  Future<void> showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    if (_isQuitting) return;
    _isQuitting = true;
    await windowManager.setPreventClose(false);
    if (_isWindows && _trayCreated) await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (_isQuitting) return;
    if (_settings.closeToBackground) {
      unawaited(windowManager.hide());
    } else if (_isMacOS) {
      unawaited(_quit());
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(showMainWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _showWindowKey:
        unawaited(showMainWindow());
        return;
      case _quitAppKey:
        unawaited(_quit());
        return;
    }
  }
}
