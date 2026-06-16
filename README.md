# GPU Monitor

一个用于通过 SSH 查询多台机器 GPU 状态的 Flutter 桌面小工具。

![interface](interface.png)

## 功能

- 从 `~/.ssh/config` 读取主机配置。
- 通过 SSH 执行 `nvidia-smi`，查询 GPU 利用率、显存、温度和功耗。
- 按主机展示查询结果，并区分正常、无 GPU、错误和加载状态。
- 支持选择启用的主机、手动刷新、自动刷新间隔和浅色/深色主题。

## 构建与运行

先确认已安装 Flutter，并按目标平台启用桌面支持：

```bash
flutter doctor
flutter pub get
flutter test
```

### Windows

```powershell
flutter config --enable-windows-desktop
flutter run -d windows
flutter build windows
```

构建产物位于：

```text
build/windows/x64/runner/Release/gpu_monitor.exe
```

### macOS

macOS 构建需要安装 Xcode，并启用 macOS 桌面支持：

```bash
flutter config --enable-macos-desktop
flutter run -d macos
flutter build macos
```

构建产物位于：

```text
build/macos/Build/Products/Release/GPU Monitor.app
```

### GitHub Actions 自动发布

仓库包含 `.github/workflows/release.yml`，推送 `v*` tag 时会自动构建 Windows 和 macOS 包，并上传到 GitHub Release：

```bash
git tag v1.0.0
git push origin v1.0.0
```

也可以在 GitHub 的 Actions 页面手动触发该 workflow，并填写 `v1.0.0` 这样的 release tag。自动发布会生成：

```text
GPU-Monitor-Windows.zip
GPU-Monitor-macOS.zip
```

当前 macOS 包未做 Developer ID 签名和 notarization，首次打开时可能会提示来源无法验证。
