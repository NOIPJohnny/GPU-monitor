import Cocoa
import Carbon.HIToolbox
import FlutterMacOS
import SwiftUI
import ApplicationServices

final class MenuBarSnapshotStore: ObservableObject {
  @Published var snapshot = MenuBarSnapshot()

  func update(_ arguments: Any?) {
    guard let dictionary = arguments as? [String: Any] else { return }
    snapshot = MenuBarSnapshot(dictionary: dictionary)
  }
}

struct MenuBarSnapshot {
  var language = "en"
  var themeMode = "system"
  var isRefreshing = false
  var autoRefresh = false
  var intervalSeconds = 10.0
  var menuBarShortcut = "cmd+shift+g"
  var lastRefreshedAt: Date?
  var hosts: [MenuBarHostSnapshot] = []

  init() {}

  init(dictionary: [String: Any]) {
    language = dictionary["language"] as? String == "zh" ? "zh" : "en"
    themeMode = dictionary["themeMode"] as? String ?? "system"
    isRefreshing = dictionary["isRefreshing"] as? Bool ?? false
    autoRefresh = dictionary["autoRefresh"] as? Bool ?? false
    intervalSeconds = MenuBarValue.double(dictionary["intervalSeconds"]) ?? 10
    menuBarShortcut = dictionary["menuBarShortcut"] as? String ?? "cmd+shift+g"
    lastRefreshedAt = MenuBarValue.date(dictionary["lastRefreshedAt"])
    hosts = MenuBarValue.dictionaries(dictionary["hosts"]).map {
      MenuBarHostSnapshot(dictionary: $0)
    }
  }

  var onlineHostCount: Int {
    hosts.filter { $0.status == "success" }.count
  }

  var gpuCount: Int {
    hosts.filter { $0.status == "success" }.reduce(0) { $0 + $1.gpus.count }
  }

  var idleGpuCount: Int {
    hosts.reduce(0) { count, host in
      count + host.gpus.filter { gpu in
        let lowUtil = gpu.gpuUtil == nil || gpu.gpuUtil! < 10
        let lowMemory = gpu.memUsed == nil || gpu.memUsed! < 1024
        return host.status == "success" && gpu.processes.isEmpty && lowUtil && lowMemory
      }.count
    }
  }
}

struct MenuBarHostSnapshot: Identifiable {
  let alias: String
  let status: String
  let errorMessage: String?
  let fetchedAt: Date?
  let gpus: [MenuBarGpuSnapshot]

  var id: String { alias }

  init(dictionary: [String: Any]) {
    alias = dictionary["alias"] as? String ?? "-"
    status = dictionary["status"] as? String ?? "idle"
    errorMessage = dictionary["errorMessage"] as? String
    fetchedAt = MenuBarValue.date(dictionary["fetchedAt"])
    gpus = MenuBarValue.dictionaries(dictionary["gpus"]).map {
      MenuBarGpuSnapshot(dictionary: $0)
    }
  }
}

struct MenuBarGpuSnapshot {
  let index: Int
  let gpuUtil: Int?
  let memUsed: Int?
  let memTotal: Int?
  let processes: [MenuBarProcessSnapshot]

  init(dictionary: [String: Any]) {
    index = MenuBarValue.int(dictionary["index"]) ?? 0
    gpuUtil = MenuBarValue.int(dictionary["gpuUtil"])
    memUsed = MenuBarValue.int(dictionary["memUsed"])
    memTotal = MenuBarValue.int(dictionary["memTotal"])
    processes = MenuBarValue.dictionaries(dictionary["processes"]).map {
      MenuBarProcessSnapshot(dictionary: $0)
    }
  }
}

struct MenuBarProcessSnapshot {
  let user: String?
  let usedMemory: Int?

  init(dictionary: [String: Any]) {
    user = dictionary["user"] as? String
    usedMemory = MenuBarValue.int(dictionary["usedMemory"])
  }
}

private struct NativeMenuBarShortcut {
  let keyCode: UInt32
  let modifiers: UInt32

  init?(rawValue: String) {
    let parts = rawValue.lowercased().split(separator: "+").map(String.init)
    guard parts.count >= 2, let keyCode = Self.keyCodes[parts.last!] else {
      return nil
    }

    var modifiers: UInt32 = 0
    var seen = Set<String>()
    for modifier in parts.dropLast() {
      guard seen.insert(modifier).inserted else { return nil }
      switch modifier {
      case "cmd": modifiers |= UInt32(cmdKey)
      case "ctrl": modifiers |= UInt32(controlKey)
      case "alt": modifiers |= UInt32(optionKey)
      case "shift": modifiers |= UInt32(shiftKey)
      default: return nil
      }
    }
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  private static let keyCodes: [String: UInt32] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6,
    "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
    "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21,
    "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31,
    "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45,
    "m": 46, "space": 49, "f1": 122, "f2": 120, "f3": 99, "f4": 118,
    "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
    "f11": 103, "f12": 111,
  ]
}

private enum MenuBarValue {
  static func dictionaries(_ value: Any?) -> [[String: Any]] {
    if let array = value as? [Any] {
      return array.compactMap { $0 as? [String: Any] }
    }
    if let array = value as? NSArray {
      return array.compactMap { $0 as? [String: Any] }
    }
    return []
  }

  static func int(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? NSNumber { return value.intValue }
    return nil
  }

  static func double(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? NSNumber { return value.doubleValue }
    return nil
  }

  static func date(_ value: Any?) -> Date? {
    guard let value = value as? String else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }
}

final class MenuBarPanelController: NSObject {
  private let channel: FlutterMethodChannel
  private let store = MenuBarSnapshotStore()
  private weak var mainWindow: NSWindow?
  private var statusItem: NSStatusItem?
  private var panel: MenuBarPanelWindow?
  private var globalMouseMonitor: Any?
  private var localMouseMonitor: Any?
  private var hotKeyRef: EventHotKeyRef?
  private var hotKeyHandlerRef: EventHandlerRef?
  private var resizeScheduled = false
  private var panelAnchorFrame: NSRect?
  private var preferOwnAnchor = false

  private static let hotKeySignature: OSType = 0x4750554D
  private static let hotKeyHandler: EventHandlerUPP = { _, _, userData in
    guard let userData = userData else { return noErr }
    let controller = Unmanaged<MenuBarPanelController>
      .fromOpaque(userData)
      .takeUnretainedValue()
    DispatchQueue.main.async {
      controller.handleHotKey()
    }
    return noErr
  }

  init(channel: FlutterMethodChannel, mainWindow: NSWindow) {
    self.channel = channel
    self.mainWindow = mainWindow
    super.init()
  }

  func start() {
    guard statusItem == nil else { return }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      let image: NSImage
      if #available(macOS 11.0, *), let symbol = NSImage(
        systemSymbolName: "cpu",
        accessibilityDescription: "GPU Monitor"
      ) {
        image = symbol
      } else {
        image = (NSApp.applicationIconImage.copy() as? NSImage) ?? NSImage()
      }
      image.isTemplate = true
      image.size = NSSize(width: 16, height: 16)
      button.image = image
      button.toolTip = "GPU Monitor"
      button.target = self
      button.action = #selector(statusItemClicked)
      button.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    statusItem = item
    panel = MenuBarPanelWindow(
      store: store,
      onRefresh: { [weak self] in self?.requestRefresh() },
      onSettings: { [weak self] in self?.openSettings() },
      onOpenMainWindow: { [weak self] in self?.showMainWindow() },
      onContentSizeChanged: { [weak self] in self?.schedulePanelResize() }
    )
    registerGlobalShortcut(store.snapshot.menuBarShortcut)
    installMouseMonitors()
  }

  func updateSnapshot(_ arguments: Any?) {
    let previousShortcut = store.snapshot.menuBarShortcut
    store.update(arguments)
    if previousShortcut != store.snapshot.menuBarShortcut {
      registerGlobalShortcut(store.snapshot.menuBarShortcut)
    }
    if panel?.isVisible == true {
      schedulePanelResize()
    }
  }

  @objc private func statusItemClicked() {
    togglePanel()
  }

  private func handleHotKey() {
    let shouldShow = panel?.isVisible != true
    let shouldUseAccessibility = statusItemScreenFrame() == nil && iBarApplication() != nil
    var usedAccessibility = false

    if shouldUseAccessibility {
      usedAccessibility = pressOwnStatusItemThroughAccessibility()
    }
    if !usedAccessibility {
      statusItem?.button?.performClick(nil)
    }

    preferOwnAnchor = usedAccessibility
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
      guard let self = self else { return }
      if shouldShow {
        if self.panel?.isVisible == true {
          self.resizeAndPositionPanel(refreshAnchor: true)
        } else {
          self.showPanel()
        }
      } else if self.panel?.isVisible == true {
        self.hidePanel()
      }
    }
  }

  private func togglePanel() {
    if panel?.isVisible == true {
      hidePanel()
    } else {
      showPanel()
    }
  }

  private func showPanel() {
    guard let panel = panel, statusItem?.button != nil else { return }
    NSApp.unhideWithoutActivation()
    resizeAndPositionPanel(refreshAnchor: true)
    panel.orderFrontRegardless()
    panel.makeKey()
    positionPanelWhenReady(retriesRemaining: 5)
  }

  private func positionPanelWhenReady(retriesRemaining: Int) {
    guard retriesRemaining > 0 else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
      guard let self = self, self.panel?.isVisible == true else { return }
      self.resizeAndPositionPanel(refreshAnchor: true)
      self.positionPanelWhenReady(retriesRemaining: retriesRemaining - 1)
    }
  }

  private func schedulePanelResize() {
    guard panel?.isVisible == true, !resizeScheduled else { return }
    resizeScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard self.panel?.isVisible == true else {
        self.resizeScheduled = false
        return
      }
      self.resizePanel()
      self.positionPanelIfPossible()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
        guard let self = self else { return }
        self.resizeScheduled = false
        guard self.panel?.isVisible == true else { return }
        self.resizePanel()
        self.positionPanelIfPossible()
      }
    }
  }

  private func installMouseMonitors() {
    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      guard let self = self, self.panel?.isVisible == true else { return }
      self.hidePanel()
    }
    localMouseMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] event in
      guard let self = self, self.panel?.isVisible == true else { return event }
      if self.isPanelEvent(event) || self.isStatusItemEvent(event) {
        return event
      }
      self.hidePanel()
      return event
    }
  }

  private func isPanelEvent(_ event: NSEvent) -> Bool {
    guard let panel = panel else { return false }
    if event.window === panel { return true }
    return panel.frame.contains(NSEvent.mouseLocation)
  }

  private func isStatusItemEvent(_ event: NSEvent) -> Bool {
    guard let button = statusItem?.button,
          let window = button.window,
          event.window === window else {
      return false
    }
    let buttonFrame = button.convert(button.bounds, to: nil)
    return buttonFrame.contains(event.locationInWindow)
  }

  private func resizeAndPositionPanel(refreshAnchor: Bool = false) {
    resizePanel()
    positionPanelIfPossible(refreshAnchor: refreshAnchor)
  }

  private func resizePanel() {
    guard let panel = panel else { return }
    let screen = statusItem?.button?.window?.screen ?? NSScreen.main
    guard let screen = screen else { return }

    let width: CGFloat = 520
    let visibleFrame = screen.visibleFrame
    let maxHeight = max(240, min(720, visibleFrame.height - 32))
    panel.contentView?.invalidateIntrinsicContentSize()
    panel.contentView?.layoutSubtreeIfNeeded()
    let measuredHeight = panel.contentView?.fittingSize.height ?? 520
    let height = min(max(measuredHeight, 240), maxHeight)
    panel.setContentSize(NSSize(width: width, height: height))
  }

  private func positionPanelIfPossible(refreshAnchor: Bool = false) {
    guard let panel = panel else { return }
    if refreshAnchor || panelAnchorFrame == nil {
      panelAnchorFrame = resolvedPanelAnchorFrame()
    }
    guard let anchorFrame = panelAnchorFrame else { return }
    let screen = screenForAnchor(anchorFrame)
    guard let screen = screen else { return }
    let visibleFrame = screen.visibleFrame
    let width = panel.frame.width
    let height = panel.frame.height
    let x = min(
      max(anchorFrame.midX - width / 2, visibleFrame.minX + 8),
      visibleFrame.maxX - width - 8
    )
    let belowY = anchorFrame.minY - height - 8
    let y = belowY >= visibleFrame.minY
      ? belowY
      : min(anchorFrame.maxY + 8, visibleFrame.maxY - height - 8)
    panel.setFrameOrigin(NSPoint(x: x, y: y))
  }

  private func resolvedPanelAnchorFrame() -> NSRect? {
    if preferOwnAnchor, let ownFrame = statusItemScreenFrame() {
      return ownFrame
    }
    if let ownFrame = statusItemScreenFrame() {
      return ownFrame
    }
    if let iBarFrame = iBarAnchorFrame() {
      return iBarFrame
    }
    return fallbackAnchorFrame()
  }

  private func screenForAnchor(_ anchorFrame: NSRect) -> NSScreen? {
    NSScreen.screens.first { $0.frame.intersects(anchorFrame) } ?? NSScreen.main
  }

  private func fallbackAnchorFrame() -> NSRect? {
    guard let screen = statusItem?.button?.window?.screen ?? NSScreen.main else {
      return nil
    }
    let visibleFrame = screen.visibleFrame
    return NSRect(
      x: visibleFrame.maxX - 36,
      y: visibleFrame.maxY,
      width: 24,
      height: 22
    )
  }

  private func iBarApplication() -> NSRunningApplication? {
    NSWorkspace.shared.runningApplications.first(where: {
      let identity = [
        $0.localizedName,
        $0.bundleIdentifier,
        $0.executableURL?.lastPathComponent,
      ]
      .compactMap { $0?.lowercased() }
      .joined(separator: " ")
      return identity.contains("ibar")
    })
  }

  private func iBarAnchorFrame() -> NSRect? {
    guard let application = iBarApplication() else { return nil }
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    guard AXIsProcessTrustedWithOptions(options as CFDictionary) else { return nil }

    let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
    guard let extrasMenuBar = accessibilityValue(applicationElement, "AXExtrasMenuBar") else {
      return nil
    }
    let extrasElement = extrasMenuBar as AXUIElement

    let candidates = accessibilityChildren(extrasElement).compactMap { element -> (NSRect, String)? in
      guard let frame = accessibilityFrame(element) else { return nil }
      let role = accessibilityValue(element, kAXRoleAttribute as String) as? String ?? ""
      guard role == "AXMenuItem" || role == "AXMenuBarItem" || role == "AXButton" else {
        return nil
      }
      let title = accessibilityValue(element, kAXTitleAttribute as String) as? String ?? ""
      return (frame, title)
    }
    guard !candidates.isEmpty else { return nil }
    return candidates.first(where: { $0.1.lowercased().contains("ibar") })?.0
      ?? candidates.max(by: { $0.0.midX < $1.0.midX })?.0
  }

  private func pressOwnStatusItemThroughAccessibility() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    guard AXIsProcessTrustedWithOptions(options as CFDictionary) else { return false }

    let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
    guard let extrasMenuBar = accessibilityValue(application, "AXExtrasMenuBar") else {
      return false
    }
    let extrasElement = extrasMenuBar as AXUIElement
    let candidates = accessibilityChildren(extrasElement).filter { element in
      let role = accessibilityValue(element, kAXRoleAttribute as String) as? String ?? ""
      return role == "AXMenuItem" || role == "AXMenuBarItem" || role == "AXButton"
    }
    guard let statusItem = candidates.first else { return false }
    return AXUIElementPerformAction(statusItem, kAXPressAction as CFString) == .success
  }

  private func accessibilityValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }
    return value
  }

  private func accessibilityChildren(_ element: AXUIElement) -> [AXUIElement] {
    guard let value = accessibilityValue(element, kAXChildrenAttribute as String) else {
      return []
    }
    return value as? [AXUIElement] ?? []
  }

  private func accessibilityFrame(_ element: AXUIElement) -> NSRect? {
    guard let positionReference = accessibilityValue(element, kAXPositionAttribute as String),
          let sizeReference = accessibilityValue(element, kAXSizeAttribute as String) else {
      return nil
    }
    let positionValue = positionReference as AXValue
    let sizeValue = sizeReference as AXValue
    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue, .cgPoint, &position),
          AXValueGetValue(sizeValue, .cgSize, &size),
          size.width > 0,
          size.height > 0 else {
      return nil
    }

    let topY = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
    return NSRect(
      x: position.x,
      y: topY - position.y - size.height,
      width: size.width,
      height: size.height
    )
  }

  private func statusItemScreenFrame() -> NSRect? {
    guard let button = statusItem?.button,
          let window = button.window else {
      return nil
    }
    let buttonFrame = button.convert(button.bounds, to: nil)
    let screenFrame = window.convertToScreen(buttonFrame)
    guard screenFrame.width > 0, screenFrame.height > 0 else { return nil }
    return screenFrame
  }

  private func hidePanel() {
    panel?.orderOut(nil)
    preferOwnAnchor = false
  }

  private func requestRefresh() {
    guard !store.snapshot.isRefreshing else { return }
    channel.invokeMethod("refresh", arguments: nil)
  }

  private func openSettings() {
    showMainWindow()
    channel.invokeMethod("openSettings", arguments: nil)
  }

  private func showMainWindow() {
    hidePanel()
    mainWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func registerGlobalShortcut(_ rawValue: String) {
    unregisterGlobalShortcut()
    guard let shortcut = NativeMenuBarShortcut(rawValue: rawValue) else { return }

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    let installStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      Self.hotKeyHandler,
      1,
      &eventType,
      userData,
      &hotKeyHandlerRef
    )
    guard installStatus == noErr else { return }

    let hotKeyId = EventHotKeyID(signature: Self.hotKeySignature, id: 1)
    let registerStatus = RegisterEventHotKey(
      shortcut.keyCode,
      shortcut.modifiers,
      hotKeyId,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    if registerStatus != noErr {
      unregisterGlobalShortcut()
    }
  }

  private func unregisterGlobalShortcut() {
    if let hotKeyRef = hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
    if let hotKeyHandlerRef = hotKeyHandlerRef {
      RemoveEventHandler(hotKeyHandlerRef)
    }
    hotKeyRef = nil
    hotKeyHandlerRef = nil
  }

  func stop() {
    hidePanel()
    unregisterGlobalShortcut()
    if let globalMouseMonitor = globalMouseMonitor {
      NSEvent.removeMonitor(globalMouseMonitor)
    }
    if let localMouseMonitor = localMouseMonitor {
      NSEvent.removeMonitor(localMouseMonitor)
    }
    globalMouseMonitor = nil
    localMouseMonitor = nil
    if let statusItem = statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
    }
    statusItem = nil
    panel = nil
  }
}

final class MenuBarPanelWindow: NSPanel {
  init(
    store: MenuBarSnapshotStore,
    onRefresh: @escaping () -> Void,
    onSettings: @escaping () -> Void,
    onOpenMainWindow: @escaping () -> Void,
    onContentSizeChanged: @escaping () -> Void
  ) {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )

    let rootView = MenuBarPanelView(
      store: store,
      onRefresh: onRefresh,
      onSettings: onSettings,
      onOpenMainWindow: onOpenMainWindow,
      onContentSizeChanged: onContentSizeChanged
    )
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.autoresizingMask = [.width, .height]
    contentView = hostingView

    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [.transient, .moveToActiveSpace]
    hidesOnDeactivate = false
    becomesKeyOnlyIfNeeded = true
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

struct MenuBarPanelView: View {
  @ObservedObject var store: MenuBarSnapshotStore
  let onRefresh: () -> Void
  let onSettings: () -> Void
  let onOpenMainWindow: () -> Void
  let onContentSizeChanged: () -> Void

  private var strings: MenuBarStrings {
    MenuBarStrings(language: store.snapshot.language)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        PanelButton(
          systemName: store.snapshot.isRefreshing ? "hourglass" : "arrow.clockwise",
          help: strings.refresh,
          action: onRefresh
        )
        .disabled(store.snapshot.isRefreshing)
        PanelButton(systemName: "gearshape", help: strings.settings, action: onSettings)
        Spacer()
        PanelButton(
          systemName: "macwindow",
          help: strings.openMainWindow,
          action: onOpenMainWindow
        )
      }

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Circle()
          .fill(summaryColor)
          .frame(width: 10, height: 10)
        Text(summaryText)
          .font(.system(size: 14, weight: .semibold))
        Spacer()
        if let date = store.snapshot.lastRefreshedAt {
          Text(timeText(date))
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
      }

      if store.snapshot.autoRefresh {
        Text(strings.autoRefresh(store.snapshot.intervalSeconds))
          .font(.system(size: 11))
          .foregroundColor(.secondary)
      }

      Divider()

      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading, spacing: 10) {
          if store.snapshot.hosts.isEmpty {
            EmptyPanelState(strings: strings, onRefresh: onRefresh)
          } else {
            ForEach(store.snapshot.hosts) { host in
              MenuBarHostView(
                host: host,
                strings: strings,
                initiallyExpanded: host.alias == firstSuccessAlias,
                onContentSizeChanged: onContentSizeChanged
              )
            }
          }
        }
      }
      .frame(maxHeight: 560)
    }
    .padding(14)
    .frame(width: 520, alignment: .topLeading)
    .background(VisualEffectView())
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
    )
    .preferredColorScheme(preferredColorScheme)
  }

  private var preferredColorScheme: ColorScheme? {
    switch store.snapshot.themeMode {
    case "light": return .light
    case "dark": return .dark
    default: return nil
    }
  }

  private var summaryText: String {
    "\(store.snapshot.onlineHostCount)/\(store.snapshot.hosts.count) \(strings.hosts) · " +
      "\(store.snapshot.gpuCount) \(strings.gpus) · \(store.snapshot.idleGpuCount) \(strings.idle)"
  }

  private var firstSuccessAlias: String? {
    store.snapshot.hosts.first { $0.status == "success" }?.alias
  }

  private var summaryColor: Color {
    let hosts = store.snapshot.hosts
    if hosts.isEmpty || hosts.allSatisfy({ $0.status == "idle" || $0.status == "loading" }) {
      return .gray
    }
    if hosts.allSatisfy({ $0.status == "error" }) { return .red }
    if hosts.contains(where: { $0.status == "error" || $0.status == "noGpu" }) {
      return .orange
    }
    return .green
  }

  private func timeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    formatter.locale = Locale(identifier: store.snapshot.language == "zh" ? "zh_CN" : "en_US_POSIX")
    return formatter.string(from: date)
  }
}

private struct PanelButton: View {
  let systemName: String
  let help: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .frame(width: 28, height: 28)
    }
    .buttonStyle(PlainButtonStyle())
    .help(help)
  }
}

private struct EmptyPanelState: View {
  let strings: MenuBarStrings
  let onRefresh: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Text(strings.noHosts)
        .font(.system(size: 13))
        .foregroundColor(.secondary)
      Button(strings.refresh, action: onRefresh)
        .buttonStyle(PlainButtonStyle())
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
  }
}

private struct MenuBarHostView: View {
  let host: MenuBarHostSnapshot
  let strings: MenuBarStrings
  let initiallyExpanded: Bool
  let onContentSizeChanged: () -> Void
  @State private var expanded: Bool

  init(
    host: MenuBarHostSnapshot,
    strings: MenuBarStrings,
    initiallyExpanded: Bool,
    onContentSizeChanged: @escaping () -> Void
  ) {
    self.host = host
    self.strings = strings
    self.initiallyExpanded = initiallyExpanded
    self.onContentSizeChanged = onContentSizeChanged
    _expanded = State(initialValue: initiallyExpanded)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button(action: {
        expanded.toggle()
        onContentSizeChanged()
      }) {
        HStack(spacing: 8) {
          Circle()
            .fill(statusColor)
            .frame(width: 9, height: 9)
          Text(host.alias)
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1)
          Spacer()
          if let date = host.fetchedAt {
            Text(timeText(date))
              .font(.system(size: 11))
              .foregroundColor(.secondary)
          }
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(PlainButtonStyle())
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())

      if expanded {
        hostBody
      }
    }
    .padding(10)
    .background(Color.primary.opacity(0.045))
    .overlay(
      RoundedRectangle(cornerRadius: 11, style: .continuous)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
  }

  @ViewBuilder
  private var hostBody: some View {
    switch host.status {
    case "success":
      VStack(alignment: .leading, spacing: 6) {
        ForEach(Array(stride(from: 0, to: host.gpus.count, by: 4)), id: \.self) { start in
          HStack(alignment: .top, spacing: 6) {
            ForEach(0..<4, id: \.self) { offset in
              if start + offset < host.gpus.count {
                MenuBarGpuCard(gpu: host.gpus[start + offset], strings: strings)
              } else {
                Spacer().frame(maxWidth: .infinity)
              }
            }
          }
        }
        if host.gpus.isEmpty {
          Text(strings.noGpu)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
      }
    case "loading":
      HStack(spacing: 8) {
        ProgressView().scaleEffect(0.7)
        Text(strings.querying)
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
    case "error":
      Text(host.errorMessage ?? strings.queryFailed)
        .font(.system(size: 12))
        .foregroundColor(.red)
        .lineLimit(3)
    case "noGpu":
      Text(strings.noGpu)
        .font(.system(size: 12))
        .foregroundColor(.orange)
    default:
      Text(strings.notQueried)
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
  }

  private var statusColor: Color {
    switch host.status {
    case "success": return .green
    case "error": return .red
    case "noGpu": return .orange
    case "loading": return .blue
    default: return .gray
    }
  }

  private func timeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
  }
}

private struct MenuBarUserUsage: Identifiable {
  let user: String
  let memory: Int

  var id: String { user }
}

private struct MenuBarGpuCard: View {
  let gpu: MenuBarGpuSnapshot
  let strings: MenuBarStrings

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("GPU\(gpu.index)")
          .font(.system(size: 11, weight: .semibold))
        Spacer()
      }
      MenuBarMetricRow(
        label: strings.utilization,
        value: gpu.gpuUtil.map { "\($0)%" } ?? "N/A"
      )
      MenuBarProgressBar(value: gpu.gpuUtil.map { Double($0) / 100 }, color: .blue)
      MenuBarMetricRow(label: strings.memory, value: memoryText)
      MenuBarProgressBar(value: memoryFraction, color: .purple)
      if users.isEmpty {
        Text(strings.noUsers)
          .font(.system(size: 9))
          .foregroundColor(.secondary)
      } else {
        ForEach(users.prefix(2)) { usage in
          HStack(spacing: 3) {
            Circle().fill(Color.blue).frame(width: 4, height: 4)
            Text(usage.user).lineLimit(1)
            Spacer()
            Text(memory(usage.memory))
          }
          .font(.system(size: 9))
        }
        if users.count > 2 {
          Text("+\(users.count - 2) \(strings.moreUsers)")
            .font(.system(size: 9))
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(6)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(Color(nsColor: .controlBackgroundColor).opacity(0.62))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private var memoryText: String {
    guard let total = gpu.memTotal else { return "N/A" }
    return "\(memory(gpu.memUsed ?? 0)) / \(memory(total))"
  }

  private var memoryFraction: Double? {
    guard let used = gpu.memUsed, let total = gpu.memTotal, total > 0 else { return nil }
    return min(max(Double(used) / Double(total), 0), 1)
  }

  private var users: [MenuBarUserUsage] {
    var memoryByUser: [String: Int] = [:]
    for process in gpu.processes {
      let user = process.user ?? strings.unknownUser
      memoryByUser[user, default: 0] += process.usedMemory ?? 0
    }
    return memoryByUser.keys.sorted().map { user in
      MenuBarUserUsage(user: user, memory: memoryByUser[user] ?? 0)
    }
  }

  private func memory(_ value: Int) -> String {
    if value >= 1024 { return String(format: "%.1fG", Double(value) / 1024) }
    return "\(value)M"
  }
}

private struct MenuBarMetricRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      Text(value).fontWeight(.semibold)
    }
    .font(.system(size: 10))
    .foregroundColor(.secondary)
  }
}

private struct MenuBarProgressBar: View {
  let value: Double?
  let color: Color

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.primary.opacity(0.1))
        if let value = value {
          Capsule()
            .fill(color)
            .frame(width: geometry.size.width * CGFloat(value))
        }
      }
    }
    .frame(height: 5)
  }
}

private struct VisualEffectView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct MenuBarStrings {
  let language: String

  var refresh: String { language == "zh" ? "刷新" : "Refresh" }
  var settings: String { language == "zh" ? "设置" : "Settings" }
  var openMainWindow: String { language == "zh" ? "打开主窗口" : "Open main window" }
  var hosts: String { language == "zh" ? "台主机" : "hosts" }
  var gpus: String { language == "zh" ? "块 GPU" : "GPUs" }
  var idle: String { language == "zh" ? "空闲" : "idle" }
  var utilization: String { language == "zh" ? "利用率" : "Utilization" }
  var memory: String { language == "zh" ? "显存" : "Memory" }
  var querying: String { language == "zh" ? "查询中" : "Querying" }
  var queryFailed: String { language == "zh" ? "查询失败" : "Query failed" }
  var noGpu: String { language == "zh" ? "未检测到 GPU" : "No GPU detected" }
  var notQueried: String { language == "zh" ? "尚未查询" : "Not queried yet" }
  var noHosts: String { language == "zh" ? "没有可监控的主机" : "No hosts to monitor" }
  var noUsers: String { language == "zh" ? "暂无用户" : "No users" }
  var unknownUser: String { language == "zh" ? "未知用户" : "Unknown user" }
  var moreUsers: String { language == "zh" ? "个用户" : "more users" }

  func autoRefresh(_ interval: Double) -> String {
    let value = interval == interval.rounded()
      ? String(Int(interval))
      : String(format: "%.1f", interval)
    return language == "zh" ? "自动刷新 · \(value)s" : "Auto refresh · \(value)s"
  }
}
