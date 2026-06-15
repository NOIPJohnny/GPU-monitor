import '../models/gpu_info.dart';
import '../models/host_query_result.dart';
import '../models/ssh_host.dart';
import 'nvidia_smi_parser.dart';
import 'ssh_executor.dart';

/// High-level orchestration: query many hosts in parallel, returning a
/// [HostQueryResult] per host. Individual host failures are isolated.
class GpuQueryService {
  final SshExecutor _executor;
  GpuQueryService(this._executor);

  Future<Map<String, HostQueryResult>> queryAll(Iterable<SshHost> hosts) async {
    final entries = await Future.wait(hosts.map((h) => _queryOne(h)));
    return {for (final e in entries) e.alias: e};
  }

  Future<HostQueryResult> _queryOne(SshHost host) async {
    try {
      final raw = await _executor.queryGpu(host);
      final List<GpuInfo> gpus = NvidiaSmiParser.parse(raw);
      if (gpus.isEmpty) return HostQueryResult.noGpu(host.alias);
      return HostQueryResult.success(host.alias, gpus);
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
