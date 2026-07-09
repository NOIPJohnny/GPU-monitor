import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gpu_monitor/models/gpu_info.dart';
import 'package:gpu_monitor/models/host_query_result.dart';
import 'package:gpu_monitor/models/ssh_host.dart';
import 'package:gpu_monitor/providers/settings_provider.dart';
import 'package:gpu_monitor/services/cpu_info_parser.dart';
import 'package:gpu_monitor/services/gpu_query_service.dart';
import 'package:gpu_monitor/services/nvidia_smi_parser.dart';
import 'package:gpu_monitor/services/ssh_config_parser.dart';
import 'package:gpu_monitor/services/ssh_executor.dart';

void main() {
  group('NvidiaSmiParser', () {
    test('parses a typical multi-GPU CSV row set', () {
      const csv =
          '0, NVIDIA GeForce RTX 4090, 35, 4230, 24564, 58, 215.5\n'
          '1, NVIDIA GeForce RTX 4090, 0, 1024, 24564, 42, 45.0';
      final gpus = NvidiaSmiParser.parse(csv);
      expect(gpus.length, 2);
      expect(gpus[0].index, 0);
      expect(gpus[0].name, 'NVIDIA GeForce RTX 4090');
      expect(gpus[0].gpuUtil, 35);
      expect(gpus[0].memUsed, 4230);
      expect(gpus[0].memTotal, 24564);
      expect(gpus[0].temp, 58);
      expect(gpus[0].powerDraw, 215.5);
      expect(gpus[1].memUtilPct, closeTo(100 * 1024 / 24564, 0.01));
    });

    test('handles empty output', () {
      expect(NvidiaSmiParser.parse(''), isEmpty);
    });

    test('tolerates non-numeric [Not Supported] fields', () {
      const csv = '0, Tesla T4, [Not Supported], 0, 15360, [N/A], 0.0';
      final gpus = NvidiaSmiParser.parse(csv);
      expect(gpus.length, 1);
      expect(gpus[0].gpuUtil, isNull);
      expect(gpus[0].temp, isNull);
      expect(gpus[0].memTotal, 15360);
      expect(gpus[0].memUtilPct, closeTo(0, 0.01));
    });

    test('joins GPU process, pmon, and ps details', () {
      const output = '''
__GPU__
0, GPU-abc, NVIDIA GeForce RTX 4090, 35, 4230, 24564, 58, 215.5
1, GPU-def, NVIDIA GeForce RTX 4090, 0, 1024, 24564, 42, 45.0
__PROC__
GPU-abc, 1234, python, 4096
__PMON__
# gpu        pid  type    sm   mem   enc   dec   command
    0       1234     C    76    12     -     -   python
__PS__
 1234 alice 01:02:03 python train.py --config exp.yaml
''';

      final gpus = NvidiaSmiParser.parse(output);

      expect(gpus.length, 2);
      expect(gpus[0].uuid, 'GPU-abc');
      expect(gpus[0].processes.length, 1);
      expect(gpus[0].processes.single.pid, 1234);
      expect(gpus[0].processes.single.user, 'alice');
      expect(gpus[0].processes.single.usedMemory, 4096);
      expect(gpus[0].processes.single.smUtil, 76);
      expect(gpus[0].processes.single.memUtil, 12);
      expect(
        gpus[0].processes.single.command,
        'python train.py --config exp.yaml',
      );
      expect(gpus[1].processes, isEmpty);
    });

    test('keeps long process usernames intact', () {
      const output = '''
__GPU__
0, GPU-abc, NVIDIA GeForce RTX 4090, 35, 4230, 24564, 58, 215.5
__PROC__
GPU-abc, 1234, python, 4096
__PS__
1234	zhourungui	01:02:03	python train.py
''';

      final gpus = NvidiaSmiParser.parse(output);

      expect(gpus.single.processes.single.user, 'zhourungui');
    });

    test('parses Windows process owner and command details', () {
      const output = '''
__GPU__
0, GPU-abc, NVIDIA GeForce RTX 4090, 35, 4230, 24564, 58, 215.5
__PROC__
GPU-abc, 1234, python.exe, 4096
__PS__
1234	LAB\\zhourungui	10:20:30	C:\\Python\\python.exe train.py
''';

      final gpus = NvidiaSmiParser.parse(output);

      expect(gpus.single.processes.single.user, r'LAB\zhourungui');
      expect(
        gpus.single.processes.single.command,
        r'C:\Python\python.exe train.py',
      );
    });

    test('ignores unsupported pmon text in detailed output', () {
      const output = '''
__GPU__
0, GPU-abc, NVIDIA GeForce RTX 4070 SUPER, 27, 1796, 12282, 51, 12.05
__PROC__
GPU-abc, 1880, C:\\Windows\\System32\\dwm.exe, [N/A]
__PMON__
The feature is not supported in this configuration
Not supported on the device(s)
Failed to process command line
__PS__
1880	DESKTOP\\user	01:02:03	C:\\Windows\\System32\\dwm.exe
''';

      final gpus = NvidiaSmiParser.parse(output);

      expect(gpus.single.name, 'NVIDIA GeForce RTX 4070 SUPER');
      expect(gpus.single.processes.single.pid, 1880);
      expect(gpus.single.processes.single.smUtil, isNull);
      expect(gpus.single.processes.single.memUtil, isNull);
      expect(
        gpus.single.processes.single.command,
        r'C:\Windows\System32\dwm.exe',
      );
    });
  });

  group('CpuInfoParser', () {
    test('parses Linux CPU summary and top processes', () {
      const output =
          '__CPU__\n'
          'platform=linux\n'
          'usage_pct=37.5\n'
          'mem_used_mib=12000\n'
          'mem_total_mib=64000\n'
          'logical_cores=32\n'
          'load_avg_1=1.23\n'
          'load_avg_5=2.34\n'
          'load_avg_15=3.45\n'
          '__CPUPROC__\n'
          '1234\talice\t88.5\t2.1\t2048\t01:02:03\tpython train.py\n';

      final cpu = CpuInfoParser.parse(output);

      expect(cpu, isNotNull);
      expect(cpu!.cpuUtil, 37.5);
      expect(cpu.memoryUsed, 12000);
      expect(cpu.memoryTotal, 64000);
      expect(cpu.memoryUtilPct, closeTo(18.75, 0.01));
      expect(cpu.logicalCores, 32);
      expect(cpu.usedCores, closeTo(12, 0.01));
      expect(cpu.loadAvg1, 1.23);
      expect(cpu.processes.single.pid, 1234);
      expect(cpu.processes.single.user, 'alice');
      expect(cpu.processes.single.cpuUtil, 88.5);
      expect(cpu.processes.single.memoryUtil, 2.1);
      expect(cpu.processes.single.residentMemory, 2048);
      expect(cpu.processes.single.command, 'python train.py');
    });

    test('parses Windows CPU summary and process command details', () {
      const output =
          '__CPU__\n'
          'platform=windows\n'
          'usage_pct=12.5\n'
          'mem_used_mib=4096\n'
          'mem_total_mib=16384\n'
          'logical_cores=16\n'
          '__CPUPROC__\n'
          '4321\tLAB\\alice\t18.5\t3.1\t512\t10:20:30\t'
          'C:\\Python\\python.exe train.py\n';

      final cpu = CpuInfoParser.parse(output);

      expect(cpu, isNotNull);
      expect(cpu!.cpuUtil, 12.5);
      expect(cpu.logicalCores, 16);
      expect(cpu.processes.single.user, r'LAB\alice');
      expect(cpu.processes.single.command, r'C:\Python\python.exe train.py');
      expect(cpu.processes.single.name, 'python.exe');
    });
  });

  group('GpuQueryService CPU monitoring', () {
    const host = SshHost(alias: 'node-1');

    test('returns GPU and CPU data when CPU monitoring is enabled', () async {
      const output = '''
__GPU__
0, GPU-abc, NVIDIA GeForce RTX 4090, 35, 4230, 24564, 58, 215.5
__CPU__
usage_pct=24.0
mem_used_mib=8000
mem_total_mib=32000
logical_cores=16
__CPUPROC__
1234	alice	50.0	2.0	1024	00:10:00	python train.py
''';
      final executor = _FakeSshExecutor(output);
      final service = GpuQueryService(executor);

      final results = await service.queryAll([host], includeCpu: true);
      final result = results[host.alias]!;

      expect(executor.lastIncludeCpu, isTrue);
      expect(result.status, QueryStatus.success);
      expect(result.gpus.single.uuid, 'GPU-abc');
      expect(result.cpu?.cpuUtil, 24.0);
    });

    test('keeps CPU data on a host without GPU', () async {
      const output = '''
__CPU__
usage_pct=10.0
mem_used_mib=4096
mem_total_mib=8192
logical_cores=8
__CPUPROC__
''';
      final executor = _FakeSshExecutor(output);
      final service = GpuQueryService(executor);

      final results = await service.queryAll([host], includeCpu: true);
      final result = results[host.alias]!;

      expect(result.status, QueryStatus.noGpu);
      expect(result.gpus, isEmpty);
      expect(result.cpu?.memoryTotal, 8192);
    });

    test('does not parse or request CPU data when disabled', () async {
      const output = '''
__GPU__
0, GPU-abc, NVIDIA GeForce RTX 4090, 35, 4230, 24564, 58, 215.5
__CPU__
usage_pct=24.0
''';
      final executor = _FakeSshExecutor(output);
      final service = GpuQueryService(executor);

      final results = await service.queryAll([host]);
      final result = results[host.alias]!;

      expect(executor.lastIncludeCpu, isFalse);
      expect(result.status, QueryStatus.success);
      expect(result.cpu, isNull);
    });
  });

  group('GpuInfo.memUtilPct', () {
    test('is null when total unknown', () {
      const g = GpuInfo(index: 0, name: 'x', memUsed: 100);
      expect(g.memUtilPct, isNull);
    });
    test('is null when total is zero', () {
      const g = GpuInfo(index: 0, name: 'x', memUsed: 0, memTotal: 0);
      expect(g.memUtilPct, isNull);
    });
  });

  group('SettingsProvider refresh interval', () {
    test('allows 0.5 second interval and clamps lower values', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await settings.setInterval(0.5);
      expect(settings.intervalSeconds, 0.5);

      await settings.setInterval(0.1);
      expect(settings.intervalSeconds, 0.5);
    });

    test('loads legacy integer interval values', () async {
      SharedPreferences.setMockInitialValues({'ssh_gpu.refresh_interval': 1});
      final settings = SettingsProvider();

      await settings.load();

      expect(settings.intervalSeconds, 1);
    });

    test('defaults CPU metrics to off and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await settings.load();
      expect(settings.showCpuMetrics, isFalse);

      await settings.setShowCpuMetrics(true);
      expect(settings.showCpuMetrics, isTrue);

      final reloaded = SettingsProvider();
      await reloaded.load();
      expect(reloaded.showCpuMetrics, isTrue);
    });
  });

  group('SshConfigParser', () {
    test('parses a concrete host with all fields', () {
      const cfg = '''
Host gpu-box
  HostName 10.0.0.5
  User lab
  Port 2222
  IdentityFile ~/.ssh/id_ed25519
''';
      final hosts = SshConfigParser.parse(cfg);
      expect(hosts.length, 1);
      expect(hosts[0].alias, 'gpu-box');
      expect(hosts[0].hostName, '10.0.0.5');
      expect(hosts[0].user, 'lab');
      expect(hosts[0].port, 2222);
      expect(hosts[0].identityFiles.length, 1);
      expect(hosts[0].identityFiles.first, contains('id_ed25519'));
      expect(hosts[0].address, '10.0.0.5'); // falls back to HostName
    });

    test(
      'skips wildcard host blocks but keeps their defaults for later hosts',
      () {
        const cfg = '''
Host *
  User default-user
  Port 2022

Host node-1
  HostName 10.0.0.1

Host node-2
  HostName 10.0.0.2
  User override
''';
        final hosts = SshConfigParser.parse(cfg);
        // wildcard block should NOT produce a host entry
        expect(hosts.length, 2);
        expect(hosts[0].alias, 'node-1');
        expect(
          hosts[0].user,
          'default-user',
        ); // inherited from wildcard defaults
        expect(hosts[0].port, 2022);
        expect(hosts[1].user, 'override');
      },
    );

    test('address falls back to alias when HostName absent', () {
      const cfg = 'Host shortname\n  User u\n';
      final hosts = SshConfigParser.parse(cfg);
      expect(hosts.single.address, 'shortname');
      expect(hosts.single.port, 22); // default
    });

    test('ignores comments and blank lines', () {
      const cfg = '''

# a comment line
Host foo   # trailing comment
  User bar
''';
      final hosts = SshConfigParser.parse(cfg);
      expect(hosts.length, 1);
      expect(hosts.single.alias, 'foo');
      expect(hosts.single.user, 'bar');
    });

    test('returns empty for empty input', () {
      expect(SshConfigParser.parse(''), isEmpty);
    });
  });
}

class _FakeSshExecutor extends SshExecutor {
  final String output;
  bool? lastIncludeCpu;

  _FakeSshExecutor(this.output);

  @override
  Future<String> queryGpu(SshHost host, {bool includeCpu = false}) async {
    lastIncludeCpu = includeCpu;
    return output;
  }
}
