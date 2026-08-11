import '../models/gpu_availability_event.dart';
import '../models/gpu_info.dart';
import '../models/host_query_result.dart';

class GpuAlertEngine {
  final Map<String, _HostState> _hosts = {};

  void syncEnabledHosts(Set<String> aliases) {
    _hosts.removeWhere((alias, _) => !aliases.contains(alias));
    for (final alias in aliases) {
      _hosts.putIfAbsent(alias, _HostState.new);
    }
  }

  void resetAll() => _hosts.clear();

  GpuAvailabilityEvent? process(
    String alias,
    HostQueryResult result, {
    DateTime? now,
  }) {
    final state = _hosts[alias];
    if (state == null) return null;
    if (result.status != QueryStatus.success || result.gpus.isEmpty) {
      state.clearCandidate();
      return null;
    }

    final sample = _AvailabilitySample(
      availability: result.gpus.any((gpu) => gpu.isLikelyIdle)
          ? GpuAvailability.idle
          : GpuAvailability.busy,
      gpus: List.unmodifiable(result.gpus),
    );

    final stable = state.stable;
    if (stable == null) {
      state.stable = sample;
      return null;
    }
    if (sample.availability == stable.availability) {
      state
        ..stable = sample
        ..clearCandidate();
      return null;
    }

    if (state.candidate?.availability == sample.availability) {
      state.candidateCount++;
      state.candidate = sample;
    } else {
      state
        ..candidate = sample
        ..candidateCount = 1;
    }
    if (state.candidateCount < 2) return null;

    final event = GpuAvailabilityEvent(
      hostAlias: alias,
      previous: stable.availability,
      current: sample.availability,
      confirmedAt: now ?? DateTime.now(),
      changedGpus: _changedGpus(stable.gpus, sample.gpus),
      currentGpus: sample.gpus,
    );
    state
      ..stable = sample
      ..clearCandidate();
    return event;
  }

  static List<GpuInfo> _changedGpus(
    List<GpuInfo> previous,
    List<GpuInfo> current,
  ) {
    final oldByKey = {for (final gpu in previous) _gpuKey(gpu): gpu};
    return current
        .where((gpu) {
          final old = oldByKey[_gpuKey(gpu)];
          return old == null || old.isLikelyIdle != gpu.isLikelyIdle;
        })
        .toList(growable: false);
  }

  static String _gpuKey(GpuInfo gpu) => gpu.uuid ?? 'index:${gpu.index}';
}

class _HostState {
  _AvailabilitySample? stable;
  _AvailabilitySample? candidate;
  int candidateCount = 0;

  void clearCandidate() {
    candidate = null;
    candidateCount = 0;
  }
}

class _AvailabilitySample {
  final GpuAvailability availability;
  final List<GpuInfo> gpus;

  const _AvailabilitySample({required this.availability, required this.gpus});
}
