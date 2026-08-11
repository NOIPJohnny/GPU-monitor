import '../models/gpu_availability_event.dart';
import 'email_notification_sender.dart';

enum HostAlertDeliveryStatus { armed, sending, sent, error }

class HostAlertDelivery {
  final HostAlertDeliveryStatus status;
  final String? message;
  final DateTime? occurredAt;

  const HostAlertDelivery({
    required this.status,
    this.message,
    this.occurredAt,
  });
}

class AlertDeliveryQueue {
  final NotificationSender _sender;
  final Duration retryInterval;
  final void Function()? onChanged;
  final Map<String, _PendingAlert> _pending = {};
  final Map<String, HostAlertDelivery> _deliveries = {};
  bool _isDispatching = false;

  AlertDeliveryQueue(
    this._sender, {
    this.retryInterval = const Duration(seconds: 60),
    this.onChanged,
  });

  Map<String, HostAlertDelivery> get deliveries =>
      Map.unmodifiable(_deliveries);
  bool get hasPending => _pending.isNotEmpty;

  void enqueue(GpuAvailabilityEvent event) {
    _pending[event.hostAlias] = _PendingAlert(event);
    _deliveries[event.hostAlias] = const HostAlertDelivery(
      status: HostAlertDeliveryStatus.armed,
    );
    onChanged?.call();
  }

  void retainHosts(Set<String> aliases) {
    _pending.removeWhere((alias, _) => !aliases.contains(alias));
    _deliveries.removeWhere((alias, _) => !aliases.contains(alias));
  }

  void clear() {
    _pending.clear();
    _deliveries.clear();
  }

  Future<void> dispatch({DateTime? now}) async {
    if (_isDispatching || _pending.isEmpty) return;
    _isDispatching = true;
    try {
      final attemptedAt = now ?? DateTime.now();
      for (final alias in _pending.keys.toList()) {
        final pending = _pending[alias];
        if (pending == null ||
            !pending.canAttempt(attemptedAt, retryInterval)) {
          continue;
        }
        pending.lastAttemptAt = attemptedAt;
        _deliveries[alias] = const HostAlertDelivery(
          status: HostAlertDeliveryStatus.sending,
        );
        onChanged?.call();
        try {
          await _sender.send(pending.event);
          if (identical(_pending[alias], pending)) {
            _pending.remove(alias);
            _deliveries[alias] = HostAlertDelivery(
              status: HostAlertDeliveryStatus.sent,
              occurredAt: DateTime.now(),
            );
          }
        } catch (error) {
          if (identical(_pending[alias], pending)) {
            _deliveries[alias] = HostAlertDelivery(
              status: HostAlertDeliveryStatus.error,
              message: '$error',
              occurredAt: DateTime.now(),
            );
          }
        }
      }
    } finally {
      _isDispatching = false;
      onChanged?.call();
    }
  }
}

class _PendingAlert {
  final GpuAvailabilityEvent event;
  DateTime? lastAttemptAt;

  _PendingAlert(this.event);

  bool canAttempt(DateTime now, Duration retryInterval) {
    final last = lastAttemptAt;
    return last == null || now.difference(last) >= retryInterval;
  }
}
