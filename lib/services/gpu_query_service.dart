import '../models/gpu_info.dart';
import '../models/host_query_result.dart';
import '../models/ssh_host.dart';
import 'cpu_info_parser.dart';
import 'nvidia_smi_parser.dart';
import 'ssh_executor.dart';

/// High-level orchestration: query many hosts in parallel, returning a
/// [HostQueryResult] per host. Individual host failures are isolated.
class GpuQueryService {
  final SshExecutor _executor;
  GpuQueryService(this._executor);

  Future<Map<String, HostQueryResult>> queryAll(
    Iterable<SshHost> hosts, {
    bool includeCpu = false,
  }) async {
    final entries = await Future.wait(
      hosts.map((h) => _queryOne(h, includeCpu: includeCpu)),
    );
    return {for (final e in entries) e.alias: e};
  }

  Future<HostQueryResult> _queryOne(
    SshHost host, {
    required bool includeCpu,
  }) async {
    try {
      final raw = await _executor.queryGpu(host, includeCpu: includeCpu);
      final List<GpuInfo> gpus = NvidiaSmiParser.parse(raw);
      final cpu = includeCpu ? CpuInfoParser.parse(raw) : null;
      if (gpus.isEmpty) return HostQueryResult.noGpu(host.alias, cpu: cpu);
      return HostQueryResult.success(host.alias, gpus, cpu: cpu);
    } on SshExecutorException catch (e) {
      final msg = e.message;
      if (msg.contains('未检测到 GPU') || msg.contains('未安装')) {
        return HostQueryResult.noGpu(host.alias);
      }
      return HostQueryResult.error(host.alias, e.message);
    } catch (e) {
      return HostQueryResult.error(host.alias, '未知错误：$e');
    }
  }
}
