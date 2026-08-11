import 'gpu_info.dart';

enum GpuAvailability { idle, busy }

class GpuAvailabilityEvent {
  final String hostAlias;
  final GpuAvailability previous;
  final GpuAvailability current;
  final DateTime confirmedAt;
  final List<GpuInfo> changedGpus;
  final List<GpuInfo> currentGpus;

  const GpuAvailabilityEvent({
    required this.hostAlias,
    required this.previous,
    required this.current,
    required this.confirmedAt,
    required this.changedGpus,
    required this.currentGpus,
  });
}
