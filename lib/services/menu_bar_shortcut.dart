import 'package:flutter/services.dart';

class MenuBarShortcut {
  static const defaultValue = 'cmd+shift+g';

  static const _modifierNames = {'cmd', 'ctrl', 'alt', 'shift'};
  static const _keyNames = {
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'f1',
    'f2',
    'f3',
    'f4',
    'f5',
    'f6',
    'f7',
    'f8',
    'f9',
    'f10',
    'f11',
    'f12',
    'space',
  };

  static bool isValid(String value) {
    final parts = value.toLowerCase().split('+');
    if (parts.length < 2) return false;
    final key = parts.last;
    final modifiers = parts.sublist(0, parts.length - 1);
    return _keyNames.contains(key) &&
        modifiers.isNotEmpty &&
        modifiers.every(_modifierNames.contains) &&
        modifiers.toSet().length == modifiers.length;
  }

  static String? fromKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
    final key = _keyName(event.logicalKey);
    if (key == null) return null;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final modifiers = <String>[
      if (pressed.any(_isMeta)) 'cmd',
      if (pressed.any(_isControl)) 'ctrl',
      if (pressed.any(_isAlt)) 'alt',
      if (pressed.any(_isShift)) 'shift',
    ];
    if (modifiers.isEmpty) return null;
    return [...modifiers, key].join('+');
  }

  static String display(String value) {
    final normalized = value.toLowerCase();
    if (!isValid(normalized)) return value;
    return normalized.split('+').map((part) {
      return switch (part) {
        'cmd' => '⌘',
        'ctrl' => '⌃',
        'alt' => '⌥',
        'shift' => '⇧',
        'space' => 'Space',
        _ => part.toUpperCase(),
      };
    }).join();
  }

  static String? _keyName(LogicalKeyboardKey key) {
    final label = key.keyLabel.toLowerCase();
    if (_keyNames.contains(label)) return label;
    if (key == LogicalKeyboardKey.space) return 'space';
    if (key == LogicalKeyboardKey.f1) return 'f1';
    if (key == LogicalKeyboardKey.f2) return 'f2';
    if (key == LogicalKeyboardKey.f3) return 'f3';
    if (key == LogicalKeyboardKey.f4) return 'f4';
    if (key == LogicalKeyboardKey.f5) return 'f5';
    if (key == LogicalKeyboardKey.f6) return 'f6';
    if (key == LogicalKeyboardKey.f7) return 'f7';
    if (key == LogicalKeyboardKey.f8) return 'f8';
    if (key == LogicalKeyboardKey.f9) return 'f9';
    if (key == LogicalKeyboardKey.f10) return 'f10';
    if (key == LogicalKeyboardKey.f11) return 'f11';
    if (key == LogicalKeyboardKey.f12) return 'f12';
    return null;
  }

  static bool _isMeta(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.metaLeft || key == LogicalKeyboardKey.metaRight;

  static bool _isControl(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight;

  static bool _isAlt(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.altLeft || key == LogicalKeyboardKey.altRight;

  static bool _isShift(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight;
}
