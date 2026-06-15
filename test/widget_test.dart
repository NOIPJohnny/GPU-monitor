import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gpu_monitor/app.dart';
import 'package:gpu_monitor/providers/gpu_monitor_provider.dart';
import 'package:gpu_monitor/providers/settings_provider.dart';
import 'package:gpu_monitor/providers/theme_provider.dart';

void main() {
  testWidgets('home renders title and empty-state when no hosts', (tester) async {
    final settings = SettingsProvider();
    final theme = ThemeProvider();
    // Do NOT call load() — keeps allHosts empty so the empty-state shows.
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider(
            create: (_) => GpuMonitorProvider(settings)),
      ],
      child: const SshGpuMonitorApp(),
    ));
    await tester.pump();

    expect(find.text('SSH GPU 监控'), findsOneWidget);
    expect(find.text('未在 ~/.ssh/config 中找到任何 Host'), findsOneWidget);

    // Auto-refresh should be off initially; flipping it must not crash.
    await tester.tap(find.byTooltip('自动刷新已关闭'));
    await tester.pump();
    expect(settings.autoRefresh, isTrue);
  });
}
