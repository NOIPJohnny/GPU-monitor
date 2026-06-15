import 'gpu_info.dart';

/// Lifecycle state of one host's most recent query.
enum QueryStatus { idle, loading, success, error, noGpu }

/// Result of querying one host.
class HostQueryResult {
  final String alias;
  final QueryStatus status;
  final List<GpuInfo> gpus;
  final String? errorMessage;
  final DateTime fetchedAt;

  const HostQueryResult({
    required this.alias,
    required this.status,
    this.gpus = const [],
    this.errorMessage,
    required this.fetchedAt,
  });

  factory HostQueryResult.loading(String alias) =>
      HostQueryResult(alias: alias, status: QueryStatus.loading, fetchedAt: DateTime.now());

  factory HostQueryResult.error(String alias, String message) => HostQueryResult(
      alias: alias, status: QueryStatus.error, errorMessage: message, fetchedAt: DateTime.now());

  factory HostQueryResult.noGpu(String alias) =>
      HostQueryResult(alias: alias, status: QueryStatus.noGpu, fetchedAt: DateTime.now());

  factory HostQueryResult.success(String alias, List<GpuInfo> gpus) =>
      HostQueryResult(alias: alias, status: QueryStatus.success, gpus: gpus, fetchedAt: DateTime.now());
}
