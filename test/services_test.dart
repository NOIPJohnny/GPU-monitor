import 'package:flutter_test/flutter_test.dart';

import 'package:gpu_monitor/models/gpu_info.dart';
import 'package:gpu_monitor/services/nvidia_smi_parser.dart';
import 'package:gpu_monitor/services/ssh_config_parser.dart';

void main() {
  group('NvidiaSmiParser', () {
    test('parses a typical multi-GPU CSV row set', () {
      const csv = '0, NVIDIA GeForce RTX 4090, 35, 4230, 24564, 58, 215.5\n'
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

    test('skips wildcard host blocks but keeps their defaults for later hosts', () {
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
      expect(hosts[0].user, 'default-user'); // inherited from wildcard defaults
      expect(hosts[0].port, 2022);
      expect(hosts[1].user, 'override');
    });

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
