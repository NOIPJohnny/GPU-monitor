import 'dart:async';
import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

import '../models/email_settings.dart';
import '../models/gpu_availability_event.dart';
import '../models/gpu_info.dart';

abstract interface class NotificationSender {
  Future<void> send(GpuAvailabilityEvent event);
}

enum EmailSendFailureKind {
  missingConfiguration,
  timeout,
  connection,
  tls,
  authentication,
  recipient,
  unknown,
}

class EmailSendException implements Exception {
  final EmailSendFailureKind kind;
  final String detail;

  const EmailSendException(this.kind, this.detail);

  @override
  String toString() => detail;
}

typedef EmailConfigLoader = Future<SmtpDeliveryConfig> Function();

class EmailNotificationSender implements NotificationSender {
  final EmailConfigLoader _loadConfig;
  final Duration timeout;

  const EmailNotificationSender(
    this._loadConfig, {
    this.timeout = const Duration(seconds: 15),
  });

  @override
  Future<void> send(GpuAvailabilityEvent event) async {
    final config = await _loadConfig();
    await _send(config, _eventMessage(config.settings, event));
  }

  Future<void> sendTest(SmtpDeliveryConfig config) {
    final message = Message()
      ..from = Address(config.settings.effectiveFromAddress, 'GPU Monitor')
      ..recipients.addAll(config.settings.recipients)
      ..subject = '[GPU Monitor] Email configuration test'
      ..text =
          'GPU Monitor 已成功连接 SMTP 服务器并发送此测试邮件。\n'
          '发送时间：${DateTime.now().toLocal()}';
    return _send(config, message);
  }

  Future<void> _send(SmtpDeliveryConfig config, Message message) async {
    if (!config.isComplete) {
      throw const EmailSendException(
        EmailSendFailureKind.missingConfiguration,
        'SMTP configuration is incomplete.',
      );
    }
    final settings = config.settings;
    final server = SmtpServer(
      settings.host.trim(),
      port: settings.port,
      username: settings.username.trim(),
      password: config.password,
      ssl: settings.security == SmtpSecurity.implicitTls,
      allowInsecure: false,
    );
    try {
      await mailer.send(message, server).timeout(timeout);
    } on TimeoutException catch (error) {
      throw EmailSendException(EmailSendFailureKind.timeout, '$error');
    } on HandshakeException catch (error) {
      throw EmailSendException(EmailSendFailureKind.tls, '$error');
    } on SocketException catch (error) {
      throw EmailSendException(EmailSendFailureKind.connection, '$error');
    } on SmtpClientAuthenticationException catch (error) {
      throw EmailSendException(EmailSendFailureKind.authentication, '$error');
    } on SmtpMessageValidationException catch (error) {
      throw EmailSendException(EmailSendFailureKind.recipient, '$error');
    } on MailerException catch (error) {
      throw EmailSendException(_mailerFailureKind(error), error.message);
    } catch (error) {
      throw EmailSendException(EmailSendFailureKind.unknown, '$error');
    }
  }

  static EmailSendFailureKind _mailerFailureKind(MailerException error) {
    final text = error.toString().toLowerCase();
    if (text.contains('auth') ||
        text.contains('credential') ||
        text.contains('535')) {
      return EmailSendFailureKind.authentication;
    }
    if (text.contains('tls') ||
        text.contains('ssl') ||
        text.contains('secure')) {
      return EmailSendFailureKind.tls;
    }
    if (text.contains('recipient') ||
        text.contains('rcpt') ||
        text.contains('mailbox') ||
        RegExp(r'\b55[0-4]\b').hasMatch(text)) {
      return EmailSendFailureKind.recipient;
    }
    return EmailSendFailureKind.unknown;
  }

  static Message _eventMessage(
    EmailSettings settings,
    GpuAvailabilityEvent event,
  ) {
    final previous = _availabilityText(event.previous);
    final current = _availabilityText(event.current);
    final previousSubject = _availabilitySubjectText(event.previous);
    final currentSubject = _availabilitySubjectText(event.current);
    final changed = event.changedGpus.isEmpty
        ? '无可识别的单卡变化'
        : event.changedGpus.map(_gpuSummary).join('\n');
    final all = event.currentGpus.map(_gpuSummary).join('\n');
    return Message()
      ..from = Address(settings.effectiveFromAddress, 'GPU Monitor')
      ..recipients.addAll(settings.recipients)
      ..subject =
          '[GPU Monitor] ${event.hostAlias}: '
          '$previousSubject -> $currentSubject'
      ..text =
          '服务器：${event.hostAlias}\n'
          '状态变化：$previous → $current\n'
          '确认时间：${event.confirmedAt.toLocal()}\n\n'
          '发生变化的 GPU：\n$changed\n\n'
          '当前全部 GPU：\n$all';
  }

  static String _gpuSummary(GpuInfo gpu) {
    final state = gpu.isLikelyIdle ? '空闲' : '忙碌';
    final util = gpu.gpuUtil == null ? 'N/A' : '${gpu.gpuUtil}%';
    final memory = gpu.memUsed == null || gpu.memTotal == null
        ? 'N/A'
        : '${gpu.memUsed}/${gpu.memTotal} MiB';
    return 'GPU ${gpu.index} · ${gpu.name} · $state · '
        '利用率 $util · 显存 $memory · ${gpu.processes.length} 个进程';
  }

  static String _availabilityText(GpuAvailability value) =>
      value == GpuAvailability.idle ? '空闲' : '忙碌';

  static String _availabilitySubjectText(GpuAvailability value) =>
      value == GpuAvailability.idle ? 'idle' : 'busy';
}
