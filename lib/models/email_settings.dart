enum SmtpSecurity { startTls, implicitTls }

class EmailSettings {
  final String host;
  final int port;
  final SmtpSecurity security;
  final String username;
  final String fromAddress;
  final List<String> recipients;

  const EmailSettings({
    this.host = '',
    this.port = 587,
    this.security = SmtpSecurity.startTls,
    this.username = '',
    this.fromAddress = '',
    this.recipients = const [],
  });

  String get effectiveFromAddress =>
      fromAddress.trim().isEmpty ? username.trim() : fromAddress.trim();

  bool get isStructurallyComplete =>
      host.trim().isNotEmpty &&
      port > 0 &&
      port <= 65535 &&
      username.trim().isNotEmpty &&
      _isEmail(effectiveFromAddress) &&
      recipients.isNotEmpty &&
      recipients.every(_isEmail);

  static List<String> parseRecipients(String text) => text
      .split(RegExp(r'[,;]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

class SmtpDeliveryConfig {
  final EmailSettings settings;
  final String password;

  const SmtpDeliveryConfig({required this.settings, required this.password});

  bool get isComplete =>
      settings.isStructurallyComplete && password.trim().isNotEmpty;
}
