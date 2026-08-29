// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'SSH GPU 监控';

  @override
  String get toggleThemeTooltip => '切换主题';

  @override
  String get settingsTooltip => '设置';

  @override
  String get queryGpuButton => '查询 GPU';

  @override
  String get queryGpuCpuButton => '查询 GPU/CPU';

  @override
  String get noHostsTitle => '未在 ~/.ssh/config 中找到任何 Host';

  @override
  String get noHostsMessage => '请在你的 SSH 配置中加入至少一个 Host 条目后重启本程序。';

  @override
  String get allHostsExcludedTitle => '所有主机已被排除';

  @override
  String get allHostsExcludedMessage => '在设置中重新启用至少一台主机即可查询。';

  @override
  String get openSettings => '打开设置';

  @override
  String get unknownUser => '未知用户';

  @override
  String get resourceOverview => '资源概览';

  @override
  String get idleGpu => '空闲 GPU';

  @override
  String get noIdleGpu => '暂无空闲 GPU';

  @override
  String get userUsage => '用户占用';

  @override
  String get noGpuProcesses => '暂无 GPU 进程';

  @override
  String processCount(int count) {
    return '$count 进程';
  }

  @override
  String get neverRefreshed => '尚未刷新';

  @override
  String lastRefreshed(String time) {
    return '上次刷新 $time';
  }

  @override
  String autoRefreshStatus(String interval) {
    return '自动刷新 · ${interval}s';
  }

  @override
  String get online => '在线';

  @override
  String get error => '错误';

  @override
  String get noGpu => '无 GPU';

  @override
  String autoRefreshEnabledTooltip(String interval) {
    return '自动刷新中（${interval}s）';
  }

  @override
  String get autoRefreshDisabledTooltip => '自动刷新已关闭';

  @override
  String get statusLoading => '查询中';

  @override
  String get statusOnline => '在线';

  @override
  String get statusError => '错误';

  @override
  String get statusNoGpu => '无 GPU';

  @override
  String get statusIdle => '待查询';

  @override
  String get privateKeyPassphraseTitle => '私钥 Passphrase';

  @override
  String get sshPasswordTitle => 'SSH 密码';

  @override
  String hostLabel(String alias) {
    return '主机：$alias';
  }

  @override
  String get passwordLabel => '密码';

  @override
  String get passphraseHint => '输入私钥的 passphrase';

  @override
  String get passwordHint => '输入登录密码';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get unknownError => '未知错误';

  @override
  String get noGpuOrDriver => '未检测到 GPU 或未安装 NVIDIA 驱动';

  @override
  String get notQueriedYet => '尚未查询，点击右上角刷新按钮';

  @override
  String get gpuUtilization => 'GPU 利用率';

  @override
  String get cpuPerformance => 'CPU 性能';

  @override
  String get cpuUtilization => 'CPU 利用率';

  @override
  String get gpuMemory => '显存';

  @override
  String get systemMemory => '系统内存';

  @override
  String get logicalCores => '逻辑核心';

  @override
  String get cpuUsedCores => '占用核心';

  @override
  String get loadAverage => '负载';

  @override
  String get temperature => '温度';

  @override
  String get power => '功耗';

  @override
  String get noCpuProcesses => '暂无 CPU 进程数据';

  @override
  String cpuProcessCount(int count) {
    return '$count 个 CPU 进程';
  }

  @override
  String processCountWithMemory(int count, String memory) {
    return '$count 个进程 · $memory';
  }

  @override
  String runningElapsed(String elapsed) {
    return '运行 $elapsed';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String hostsSectionTitle(int enabled, int total) {
    return '主机（$enabled/$total 启用）';
  }

  @override
  String get noHostInConfig => '未在 ~/.ssh/config 中找到 Host';

  @override
  String get hostExcludeHint => '关闭即排除该主机，不参与查询';

  @override
  String get addHostThenRestart => '请先在 ~/.ssh/config 中添加 Host 后重启';

  @override
  String get metricsSectionTitle => '监控指标';

  @override
  String get showCpuMetrics => '显示 CPU 指标';

  @override
  String get showCpuMetricsSubtitle => '查询 CPU 利用率、内存和 CPU 占用最高的进程';

  @override
  String get notificationsTitle => '状态变化提醒';

  @override
  String get notificationsSubtitle => '仅发送 Windows/macOS 系统通知';

  @override
  String get sendTestSystemNotification => '发送测试系统通知';

  @override
  String get sendingTestSystemNotification => '正在发送测试系统通知';

  @override
  String get testSystemNotificationSent => '测试系统通知已发送。';

  @override
  String systemNotificationFailure(String error) {
    return '系统通知发送失败：$error';
  }

  @override
  String get hostAlert => '提醒 GPU 忙闲变化';

  @override
  String get hostAlertReady => '连续两次采样确认变化后发送系统通知';

  @override
  String get hostAlertPaused => '自动刷新已关闭，提醒暂停';

  @override
  String get alertArmedTooltip => 'GPU 状态提醒监测中';

  @override
  String get alertPausedTooltip => 'GPU 状态提醒已暂停';

  @override
  String get alertSendingTooltip => '正在发送 GPU 状态通知';

  @override
  String get alertSentTooltip => 'GPU 状态通知已发送';

  @override
  String alertErrorTooltip(String error) {
    return '系统通知发送失败：$error';
  }

  @override
  String get autoRefreshTitle => '自动刷新';

  @override
  String get enableAutoRefresh => '启用自动刷新';

  @override
  String autoRefreshSubtitle(String interval) {
    return '每隔 $interval 秒重复查询一次';
  }

  @override
  String get refreshInterval => '刷新间隔';

  @override
  String refreshIntervalRange(String min, String max) {
    return '范围 $min-$max 秒';
  }

  @override
  String autoRefreshTip(String sliderMax, String max) {
    return '提示：滑块上限 ${sliderMax}s，输入框可填到 ${max}s。';
  }

  @override
  String get desktopBehaviorTitle => '后台运行';

  @override
  String get closeToBackground => '关闭窗口时继续后台运行';

  @override
  String get closeToBackgroundWindowsSubtitle => '隐藏到系统托盘，监控和提醒继续运行';

  @override
  String get closeToBackgroundMacosSubtitle => '在后台继续运行；可从菜单栏图标或 Dock 打开应用';

  @override
  String get appearance => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get languageSystem => '跟随系统语言';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';
}
