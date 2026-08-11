import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gpu_monitor/models/email_settings.dart';
import 'package:gpu_monitor/models/gpu_availability_event.dart';
import 'package:gpu_monitor/models/gpu_info.dart';
import 'package:gpu_monitor/models/gpu_process_info.dart';
import 'package:gpu_monitor/models/host_query_result.dart';
import 'package:gpu_monitor/models/ssh_host.dart';
import 'package:gpu_monitor/providers/settings_provider.dart';
import 'package:gpu_monitor/services/alert_delivery_queue.dart';
import 'package:gpu_monitor/services/email_notification_sender.dart';
import 'package:gpu_monitor/services/gpu_alert_engine.dart';
import 'package:gpu_monitor/services/secret_store.dart';
import 'package:gpu_monitor/services/system_notification_sender.dart';

void main() {
  group('EmailSettings', () {
    test('parses, trims, and deduplicates recipients', () {
      expect(
        EmailSettings.parseRecipients(
          'one@example.com; two@example.com, one@example.com',
        ),
        ['one@example.com', 'two@example.com'],
      );
    });

    test('uses the username as the default from address', () {
      const settings = EmailSettings(
        host: 'smtp.mail.me.com',
        port: 587,
        username: 'user@icloud.com',
        recipients: ['user@icloud.com'],
      );
      expect(settings.effectiveFromAddress, 'user@icloud.com');
      expect(settings.isStructurallyComplete, isTrue);
    });
  });

  group('SettingsProvider email alerts', () {
    test('persists settings, secret, and per-host alert state', () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = _MemorySecretStore();
      Future<List<SshHost>> hosts() async => const [SshHost(alias: 'node-1')];
      final settings = SettingsProvider(
        secretStore: secrets,
        hostLoader: hosts,
      );
      await settings.load();
      const email = EmailSettings(
        host: 'smtp.mail.me.com',
        port: 587,
        username: 'user@icloud.com',
        recipients: ['user@icloud.com'],
      );

      await settings.saveEmailSettings(email, password: 'app-password');
      expect(await settings.setHostAlert('node-1', true), isTrue);
      expect(settings.autoRefresh, isTrue);
      expect(settings.isHostAlertEnabled('node-1'), isTrue);

      final reloaded = SettingsProvider(
        secretStore: secrets,
        hostLoader: hosts,
      );
      await reloaded.load();
      expect(reloaded.emailSettings.host, 'smtp.mail.me.com');
      expect(await reloaded.loadSmtpPassword(), 'app-password');
      expect(reloaded.isHostAlertEnabled('node-1'), isTrue);

      await reloaded.setExcluded('node-1', true);
      expect(reloaded.isHostAlertEnabled('node-1'), isFalse);
    });

    test('clearing the password disables every host alert', () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = _MemorySecretStore();
      final settings = SettingsProvider(
        secretStore: secrets,
        hostLoader: () async => const [SshHost(alias: 'node-1')],
      );
      await settings.load();
      await settings.saveEmailSettings(
        const EmailSettings(
          host: 'smtp.example.com',
          username: 'sender@example.com',
          recipients: ['receiver@example.com'],
        ),
        password: 'secret',
      );
      await settings.setHostAlert('node-1', true);

      await settings.clearSmtpPassword();

      expect(settings.hasSmtpPassword, isFalse);
      expect(settings.alertHosts, isEmpty);
      expect(await secrets.read(SettingsProvider.smtpPasswordKey), isNull);
    });
  });

  group('GpuAlertEngine', () {
    test('establishes a baseline and confirms both transitions twice', () {
      final engine = GpuAlertEngine()..syncEnabledHosts({'node-1'});
      final busy = _result([_gpu(0, idle: false), _gpu(1, idle: false)]);
      final idle = _result([_gpu(0, idle: true), _gpu(1, idle: false)]);

      expect(engine.process('node-1', busy), isNull);
      expect(engine.process('node-1', idle), isNull);
      final becameIdle = engine.process('node-1', idle);
      expect(becameIdle?.previous, GpuAvailability.busy);
      expect(becameIdle?.current, GpuAvailability.idle);
      expect(becameIdle?.changedGpus.map((gpu) => gpu.index), [0]);

      expect(engine.process('node-1', busy), isNull);
      final becameBusy = engine.process('node-1', busy);
      expect(becameBusy?.previous, GpuAvailability.idle);
      expect(becameBusy?.current, GpuAvailability.busy);
    });

    test('does not notify when individual GPUs change but host stays idle', () {
      final engine = GpuAlertEngine()..syncEnabledHosts({'node-1'});
      final first = _result([_gpu(0, idle: true), _gpu(1, idle: false)]);
      final swapped = _result([_gpu(0, idle: false), _gpu(1, idle: true)]);

      expect(engine.process('node-1', first), isNull);
      expect(engine.process('node-1', swapped), isNull);
      expect(engine.process('node-1', swapped), isNull);
    });

    test('an error breaks consecutive confirmation', () {
      final engine = GpuAlertEngine()..syncEnabledHosts({'node-1'});
      final busy = _result([_gpu(0, idle: false)]);
      final idle = _result([_gpu(0, idle: true)]);
      final error = HostQueryResult.error('node-1', 'offline');

      engine.process('node-1', busy);
      expect(engine.process('node-1', idle), isNull);
      expect(engine.process('node-1', error), isNull);
      expect(engine.process('node-1', idle), isNull);
      expect(engine.process('node-1', idle), isNotNull);
    });
  });

  group('AlertDeliveryQueue', () {
    test('retries a failed event no more often than the interval', () async {
      final sender = _FakeNotificationSender(failuresRemaining: 1);
      final queue = AlertDeliveryQueue(sender);
      final event = _event(GpuAvailability.idle);
      final start = DateTime(2026, 1, 1);
      queue.enqueue(event);

      await queue.dispatch(now: start);
      expect(sender.events.length, 1);
      expect(queue.deliveries['node-1']?.status, HostAlertDeliveryStatus.error);

      await queue.dispatch(now: start.add(const Duration(seconds: 59)));
      expect(sender.events.length, 1);
      await queue.dispatch(now: start.add(const Duration(seconds: 60)));
      expect(sender.events.length, 2);
      expect(queue.hasPending, isFalse);
      expect(queue.deliveries['node-1']?.status, HostAlertDeliveryStatus.sent);
    });

    test('keeps a newer reverse event when an old send finishes', () async {
      final sender = _BlockingNotificationSender();
      final queue = AlertDeliveryQueue(sender);
      queue.enqueue(_event(GpuAvailability.idle));
      final firstDispatch = queue.dispatch();
      await sender.started.future;

      queue.enqueue(_event(GpuAvailability.busy));
      sender.release.complete();
      await firstDispatch;

      expect(queue.hasPending, isTrue);
      await queue.dispatch();
      expect(sender.events.map((event) => event.current), [
        GpuAvailability.idle,
        GpuAvailability.busy,
      ]);
    });
  });

  group('SystemNotificationSender content', () {
    test('formats a confirmed transition in Chinese', () {
      final content = SystemNotificationSender.eventContent(
        _event(GpuAvailability.idle),
        'zh-CN',
      );

      expect(content.title, 'node-1 GPU 状态变化');
      expect(content.body, '服务器状态已确认：忙碌 → 空闲');
    });

    test('formats a confirmed transition in English', () {
      final content = SystemNotificationSender.eventContent(
        _event(GpuAvailability.busy),
        'en',
      );

      expect(content.title, 'node-1 GPU status changed');
      expect(content.body, 'Server status confirmed: idle → busy');
    });
  });
}

GpuInfo _gpu(int index, {required bool idle}) => GpuInfo(
  index: index,
  uuid: 'GPU-$index',
  name: 'Test GPU',
  gpuUtil: idle ? 0 : 80,
  memUsed: idle ? 0 : 4096,
  memTotal: 24576,
  processes: idle ? const [] : const [GpuProcessInfo(pid: 123, name: 'python')],
);

HostQueryResult _result(List<GpuInfo> gpus) =>
    HostQueryResult.success('node-1', gpus);

GpuAvailabilityEvent _event(GpuAvailability current) => GpuAvailabilityEvent(
  hostAlias: 'node-1',
  previous: current == GpuAvailability.idle
      ? GpuAvailability.busy
      : GpuAvailability.idle,
  current: current,
  confirmedAt: DateTime(2026, 1, 1),
  changedGpus: [_gpu(0, idle: current == GpuAvailability.idle)],
  currentGpus: [_gpu(0, idle: current == GpuAvailability.idle)],
);

class _MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeNotificationSender implements NotificationSender {
  int failuresRemaining;
  final List<GpuAvailabilityEvent> events = [];

  _FakeNotificationSender({this.failuresRemaining = 0});

  @override
  Future<void> send(GpuAvailabilityEvent event) async {
    events.add(event);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw Exception('temporary failure');
    }
  }
}

class _BlockingNotificationSender implements NotificationSender {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  final List<GpuAvailabilityEvent> events = [];

  @override
  Future<void> send(GpuAvailabilityEvent event) async {
    events.add(event);
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
  }
}
