import AppKit
import Carbon
import ApplicationServices

private let pngType = NSPasteboard.PasteboardType("public.png")
private let tiffType = NSPasteboard.PasteboardType("public.tiff")

private func log(_ message: String) {
    print("[PasteImagePath] \(message)")
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}

struct HotKeyConfig {
    static let defaultsKeyCode = "HotKeyKeyCode"
    static let defaultsModifiers = "HotKeyModifiers"
    static let defaultValue = HotKeyConfig(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey))

    let keyCode: UInt32
    let modifiers: UInt32

    static func load() -> HotKeyConfig {
        let defaults = UserDefaults.standard
        let keyCode = defaults.object(forKey: defaultsKeyCode) as? UInt32
        let modifiers = defaults.object(forKey: defaultsModifiers) as? UInt32
        if let keyCode, let modifiers {
            return HotKeyConfig(keyCode: keyCode, modifiers: modifiers)
        }
        return defaultValue
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(keyCode, forKey: Self.defaultsKeyCode)
        defaults.set(modifiers, forKey: Self.defaultsModifiers)
    }

    var modifierReleaseMask: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.maskControl) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.maskAlternate) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.maskShift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.maskCommand) }
        return flags
    }

    var displayString: String {
        "\(displayModifiers)\(displayKey)"
    }

    private var displayModifiers: String {
        var out = ""
        if modifiers & UInt32(controlKey) != 0 { out += "^" }
        if modifiers & UInt32(optionKey) != 0 { out += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { out += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { out += "⌘" }
        return out
    }

    private var displayKey: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Return: return "Return"
        case kVK_Space: return "Space"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        default: return "Key\(keyCode)"
        }
    }
}

private struct RecentImageEntry {
    let path: String
    let image: NSImage
}

private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var modifiers: UInt32 = 0
    if flags.contains(.control) { modifiers |= UInt32(controlKey) }
    if flags.contains(.option) { modifiers |= UInt32(optionKey) }
    if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
    if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
    return modifiers
}

final class HotKeyManager {
    private let signature = fourCharCode("PIPV")
    private let hotKeyID: UInt32 = 1
    private let onPress: () -> Void
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerInstalled = false
    private(set) var lastRegisterStatus: OSStatus = OSStatus(paramErr)
    private(set) var currentConfig = HotKeyConfig.defaultValue

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    @discardableResult
    func register(config: HotKeyConfig) -> OSStatus {
        if !eventHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

            let handlerStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, eventRef, userData in
                    guard let eventRef, let userData else { return OSStatus(eventNotHandledErr) }
                    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

                    var incoming = EventHotKeyID()
                    let status = GetEventParameter(
                        eventRef,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &incoming
                    )

                    guard status == noErr else { return status }
                    guard incoming.signature == manager.signature, incoming.id == manager.hotKeyID else {
                        return OSStatus(eventNotHandledErr)
                    }

                    manager.onPress()
                    return noErr
                },
                1,
                &eventType,
                userData,
                &eventHandlerRef
            )

            guard handlerStatus == noErr else {
                log("Failed to install hotkey event handler (\(handlerStatus)).")
                lastRegisterStatus = handlerStatus
                return handlerStatus
            }
            eventHandlerInstalled = true
        }

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let id = EventHotKeyID(signature: signature, id: hotKeyID)
        let registerStatus = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus == noErr {
            currentConfig = config
            log("Registered global hotkey: \(config.displayString).")
        } else {
            log("Failed to register global hotkey (\(registerStatus)).")
        }
        lastRegisterStatus = registerStatus
        return registerStatus
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var hotkeyStatusMenuItem: NSMenuItem?
    private var modifierMonitor: Any?
    private var pendingPaste = false
    private var pendingPasteTimeoutWorkItem: DispatchWorkItem?
    private var afterPasteAction: (() -> Void)?
    private var captureMonitorGlobal: Any?
    private var captureMonitorLocal: Any?
    private var captureTimeoutWorkItem: DispatchWorkItem?
    private var hotKeyConfig = HotKeyConfig.load()
    private var insertSpaceBeforePath: Bool {
        get { UserDefaults.standard.object(forKey: "InsertSpaceBeforePath") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "InsertSpaceBeforePath") }
    }
    private var isCapturingHotkey = false
    private var preferencesWindow: NSWindow?
    private var preferencesHotkeyValueLabel: NSTextField?
    private var preferencesStatusLabel: NSTextField?
    private var preferencesRecordButton: NSButton?
    private var aboutWindow: NSWindow?
    private var recentImagesMenu: NSMenu?
    private var recentImages: [RecentImageEntry] = []
    private let maxRecentImages = 6
    private var previewWindow: NSWindow?
    private var previewImageView: NSImageView?
    private var previewPathLabel: NSTextField?
    private var previewHideWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("App launched.")
        setupMenuBar()
        installModifierMonitor()
        cleanupOldTempFiles()

        if !isAccessibilityTrusted(prompt: true) {
            log("Accessibility permission not granted yet.")
        }

        hotKeyManager = HotKeyManager { [weak self] in
            DispatchQueue.main.async {
                self?.handlePasteHotKey()
            }
        }
        let status = hotKeyManager?.register(config: hotKeyConfig) ?? OSStatus(paramErr)
        updateHotkeyStatusMenu(status: status)
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "photo.badge.plus", accessibilityDescription: "Paste Image Path") {
            image.isTemplate = true
            item.button?.image = image
        }
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        let hotkeyItem = NSMenuItem(title: "Hotkey: Checking...", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        hotkeyStatusMenuItem = hotkeyItem
        let recentImagesItem = NSMenuItem(title: "Recent Images", action: nil, keyEquivalent: "")
        let recentSubmenu = NSMenu(title: "Recent Images")
        recentImagesItem.submenu = recentSubmenu
        recentImagesMenu = recentSubmenu
        menu.addItem(recentImagesItem)
        refreshRecentImagesMenu()
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About...", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        self.statusItem = item
    }

    private func updateHotkeyStatusMenu(status: OSStatus) {
        if status == noErr {
            hotkeyStatusMenuItem?.title = "Hotkey: Ready (\(hotKeyConfig.displayString))"
            log("Hotkey ready.")
        } else {
            hotkeyStatusMenuItem?.title = "Hotkey: Failed (\(hotKeyConfig.displayString), \(status))"
            log("Hotkey failed with OSStatus \(status).")
        }
        refreshPreferencesUI(status: status)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func openAuthorProfile() {
        guard let url = URL(string: "https://x.com/AlexNa") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func openGitHubRepo() {
        guard let url = URL(string: "https://github.com/AlexNa-Holdings/PasteImagePath") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            aboutWindow = makeAboutWindow()
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = makePreferencesWindow()
        }
        refreshPreferencesUI(status: hotKeyManager?.lastRegisterStatus ?? OSStatus(paramErr))
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleHotkeyRecording() {
        if isCapturingHotkey {
            stopHotkeyCapture()
            refreshPreferencesUI(status: hotKeyManager?.lastRegisterStatus ?? OSStatus(paramErr))
        } else {
            startHotkeyCapture()
        }
    }

    @objc private func toggleInsertSpace(_ sender: NSButton) {
        insertSpaceBeforePath = sender.state == .on
        log("Insert space before path: \(insertSpaceBeforePath)")
    }

    private func makePreferencesWindow() -> NSWindow {
        let frame = NSRect(x: 0, y: 0, width: 440, height: 280)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PasteImagePath Preferences"
        window.isReleasedWhenClosed = false
        window.center()

        let content = NSView(frame: frame)
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let titleLabel = NSTextField(labelWithString: "Global Hotkey")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)

        let hotkeyCaption = NSTextField(labelWithString: "Current:")
        hotkeyCaption.textColor = .secondaryLabelColor

        let hotkeyValue = NSTextField(labelWithString: hotKeyConfig.displayString)
        hotkeyValue.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)

        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.textColor = .secondaryLabelColor

        let recordButton = NSButton(title: "Record New Hotkey", target: self, action: #selector(toggleHotkeyRecording))
        recordButton.bezelStyle = .rounded

        let noteLabel = NSTextField(labelWithString: "Press a key combo that includes at least one modifier key.")
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.maximumNumberOfLines = 2
        noteLabel.lineBreakMode = .byWordWrapping

        let spaceCheckbox = NSButton(checkboxWithTitle: "Insert space before path", target: self, action: #selector(toggleInsertSpace(_:)))
        spaceCheckbox.state = insertSpaceBeforePath ? .on : .off

        let stack = NSStackView(views: [titleLabel, hotkeyCaption, hotkeyValue, statusLabel, recordButton, noteLabel, spaceCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20)
        ])

        preferencesHotkeyValueLabel = hotkeyValue
        preferencesStatusLabel = statusLabel
        preferencesRecordButton = recordButton

        return window
    }

    private func appVersionDisplayString() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, build != version {
            return "Version \(version) (\(build))"
        }
        return "Version \(version)"
    }

    private func makeAboutWindow() -> NSWindow {
        let frame = NSRect(x: 0, y: 0, width: 380, height: 220)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About PasteImagePathApp"
        window.isReleasedWhenClosed = false
        window.center()

        let content = NSView(frame: frame)
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let appNameLabel = NSTextField(labelWithString: "PasteImagePathApp")
        appNameLabel.font = NSFont.boldSystemFont(ofSize: 18)
        appNameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: appVersionDisplayString())
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let authorButton = NSButton(title: "Written by @AlexNa", target: self, action: #selector(openAuthorProfile))
        authorButton.isBordered = false
        authorButton.font = NSFont.systemFont(ofSize: 13)
        authorButton.contentTintColor = .linkColor

        let githubButton = NSButton(title: "GitHub Repository", target: self, action: #selector(openGitHubRepo))
        githubButton.isBordered = false
        githubButton.font = NSFont.systemFont(ofSize: 13)
        githubButton.contentTintColor = .linkColor

        let stack = NSStackView(views: [appNameLabel, versionLabel, authorButton, githubButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])

        return window
    }

    private func startHotkeyCapture() {
        stopHotkeyCapture()
        isCapturingHotkey = true
        preferencesStatusLabel?.stringValue = "Listening... press your desired hotkey."
        preferencesStatusLabel?.textColor = .systemBlue
        preferencesRecordButton?.title = "Cancel Recording"
        hotkeyStatusMenuItem?.title = "Hotkey: Recording..."
        log("Waiting for new hotkey combo.")

        captureMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleCapturedHotkey(event: event)
        }
        captureMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleCapturedHotkey(event: event)
            return nil
        }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.stopHotkeyCapture()
            let status = self.hotKeyManager?.lastRegisterStatus ?? OSStatus(paramErr)
            self.updateHotkeyStatusMenu(status: status)
            self.preferencesStatusLabel?.stringValue = "Recording timed out."
            self.preferencesStatusLabel?.textColor = .systemOrange
            log("Hotkey capture timed out.")
        }
        captureTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: timeout)
    }

    private func handleCapturedHotkey(event: NSEvent) {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            log("Ignoring hotkey without modifiers.")
            preferencesStatusLabel?.stringValue = "Hotkey must include at least one modifier."
            preferencesStatusLabel?.textColor = .systemOrange
            return
        }

        let newConfig = HotKeyConfig(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        stopHotkeyCapture()

        let status = hotKeyManager?.register(config: newConfig) ?? OSStatus(paramErr)
        if status == noErr {
            hotKeyConfig = newConfig
            hotKeyConfig.save()
            log("Hotkey changed to \(newConfig.displayString).")
            updateHotkeyStatusMenu(status: status)
            preferencesStatusLabel?.stringValue = "Saved."
            preferencesStatusLabel?.textColor = .systemGreen
        } else {
            log("Hotkey change failed (\(status)). Keeping previous hotkey.")
            let alert = NSAlert()
            alert.messageText = "Failed to set hotkey"
            alert.informativeText = "That key combo is unavailable (OSStatus \(status))."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            let fallbackStatus = hotKeyManager?.register(config: hotKeyConfig) ?? OSStatus(paramErr)
            updateHotkeyStatusMenu(status: fallbackStatus)
            preferencesStatusLabel?.stringValue = "That combo is unavailable."
            preferencesStatusLabel?.textColor = .systemRed
        }
    }

    private func stopHotkeyCapture() {
        isCapturingHotkey = false
        if let monitor = captureMonitorGlobal {
            NSEvent.removeMonitor(monitor)
            captureMonitorGlobal = nil
        }
        if let monitor = captureMonitorLocal {
            NSEvent.removeMonitor(monitor)
            captureMonitorLocal = nil
        }
        captureTimeoutWorkItem?.cancel()
        captureTimeoutWorkItem = nil
        preferencesRecordButton?.title = "Record New Hotkey"
    }

    private func refreshPreferencesUI(status: OSStatus) {
        preferencesHotkeyValueLabel?.stringValue = hotKeyConfig.displayString
        if isCapturingHotkey { return }
        if status == noErr {
            preferencesStatusLabel?.stringValue = "Hotkey is active."
            preferencesStatusLabel?.textColor = .secondaryLabelColor
        } else {
            preferencesStatusLabel?.stringValue = "Hotkey registration failed (\(status))."
            preferencesStatusLabel?.textColor = .systemRed
        }
    }

    private func handlePasteHotKey() {
        log("Hotkey pressed.")
        cleanupOldTempFiles()

        let pasteboard = NSPasteboard.general
        let originalClipboard = snapshotPasteboardItems(pasteboard)
        guard let imageData = pasteboard.data(forType: pngType) ?? pasteboard.data(forType: tiffType),
              let image = NSImage(data: imageData),
              let path = saveImageAsPNG(image: image) else {
            log("No image in clipboard. Forwarding normal paste.")
            queuePasteWhenHotkeyModifiersRelease(afterPaste: nil)
            return
        }

        pasteboard.clearContents()
        let pasteString = insertSpaceBeforePath ? " \(path)" : path
        pasteboard.setString(pasteString, forType: .string)
        log("Image saved and clipboard replaced with path: \(pasteString)")
        recordRecentImage(path: path, image: image)
        showPreview(image: image, path: path, seconds: 3.0)
        queuePasteWhenHotkeyModifiersRelease { [weak self] in
            self?.restorePasteboardItems(originalClipboard, after: 0.35)
        }
    }

    private func recordRecentImage(path: String, image: NSImage) {
        recentImages.removeAll { $0.path == path }
        recentImages.insert(RecentImageEntry(path: path, image: image), at: 0)
        if recentImages.count > maxRecentImages {
            recentImages.removeLast(recentImages.count - maxRecentImages)
        }
        refreshRecentImagesMenu()
    }

    private func refreshRecentImagesMenu() {
        guard let recentImagesMenu else { return }
        recentImagesMenu.removeAllItems()

        guard !recentImages.isEmpty else {
            let empty = NSMenuItem(title: "No pasted images yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recentImagesMenu.addItem(empty)
            return
        }

        for entry in recentImages {
            let title = URL(fileURLWithPath: entry.path).lastPathComponent
            let menuItem = NSMenuItem(title: title, action: #selector(pasteRecentImagePath(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = entry.path
            menuItem.toolTip = entry.path
            menuItem.image = thumbnailImage(for: entry.image, size: NSSize(width: 48, height: 48))
            recentImagesMenu.addItem(menuItem)
        }
    }

    private func thumbnailImage(for image: NSImage, size: NSSize) -> NSImage {
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail
    }

    @objc private func pasteRecentImagePath(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        guard FileManager.default.fileExists(atPath: path) else {
            log("Recent image path no longer exists: \(path)")
            recentImages.removeAll { $0.path == path }
            refreshRecentImagesMenu()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let pasteString = insertSpaceBeforePath ? " \(path)" : path
        pasteboard.setString(pasteString, forType: .string)
        log("Pasting saved image path: \(pasteString)")

        if let recent = recentImages.first(where: { $0.path == path }) {
            showPreview(image: recent.image, path: path, seconds: 2.0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.simulateCommandVNow()
        }
    }

    private func showPreview(image: NSImage, path: String, seconds: TimeInterval) {
        let window: NSWindow
        if let existing = previewWindow {
            window = existing
        } else {
            let frame = NSRect(x: 0, y: 0, width: 300, height: 220)
            let newWindow = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            newWindow.isOpaque = false
            newWindow.backgroundColor = NSColor.black.withAlphaComponent(0.80)
            newWindow.hasShadow = true
            newWindow.level = .statusBar
            newWindow.ignoresMouseEvents = true
            newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

            let content = NSView(frame: frame)
            content.wantsLayer = true
            content.layer?.cornerRadius = 12
            content.layer?.masksToBounds = true
            newWindow.contentView = content

            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: "")
            label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            label.textColor = .white
            label.lineBreakMode = .byTruncatingMiddle
            label.translatesAutoresizingMaskIntoConstraints = false

            content.addSubview(imageView)
            content.addSubview(label)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
                imageView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
                imageView.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
                imageView.heightAnchor.constraint(equalToConstant: 170),
                label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
                label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8)
            ])

            previewWindow = newWindow
            previewImageView = imageView
            previewPathLabel = label
            window = newWindow
        }

        previewImageView?.image = image
        previewPathLabel?.stringValue = URL(fileURLWithPath: path).lastPathComponent

        if let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame {
            let margin: CGFloat = 16
            let x = visibleFrame.maxX - window.frame.width - margin
            let y = visibleFrame.maxY - window.frame.height - margin
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window.orderFrontRegardless()

        previewHideWorkItem?.cancel()
        let hideWorkItem = DispatchWorkItem { [weak self] in
            self?.previewWindow?.orderOut(nil)
        }
        previewHideWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: hideWorkItem)
    }

    private func saveImageAsPNG(image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            log("Failed to convert clipboard image to PNG.")
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let fileName = "clip-\(formatter.string(from: Date())).png"
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(fileName)

        do {
            try pngData.write(to: url, options: .atomic)
            return url.path
        } catch {
            log("Failed writing PNG to /tmp: \(error.localizedDescription)")
            return nil
        }
    }

    private func installModifierMonitor() {
        modifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] _ in
            self?.attemptPendingPaste(trigger: "flagsChanged")
        }
    }

    private func queuePasteWhenHotkeyModifiersRelease(afterPaste: (() -> Void)?) {
        afterPasteAction = afterPaste
        pendingPaste = true
        attemptPendingPaste(trigger: "queued")

        pendingPasteTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pendingPaste else { return }
            log("Modifier release timeout reached. Sending Command+V anyway.")
            self.performPendingPaste()
        }
        pendingPasteTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    private func attemptPendingPaste(trigger: String) {
        guard pendingPaste else { return }
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let requiredModifiers = hotKeyConfig.modifierReleaseMask
        let stillHeld = !flags.intersection(requiredModifiers).isEmpty
        if !stillHeld {
            log("Hotkey modifiers released (\(trigger)). Sending Command+V.")
            performPendingPaste()
        }
    }

    private func performPendingPaste() {
        guard pendingPaste else { return }
        pendingPaste = false
        pendingPasteTimeoutWorkItem?.cancel()
        pendingPasteTimeoutWorkItem = nil
        simulateCommandVNow()
        afterPasteAction?()
        afterPasteAction = nil
    }

    private func simulateCommandVNow() {
        guard isAccessibilityTrusted(prompt: false) else {
            log("Cannot simulate Command+V because Accessibility permission is missing.")
            return
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            log("Failed to create keyboard events for Command+V.")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }

    private func snapshotPasteboardItems(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private func restorePasteboardItems(_ items: [NSPasteboardItem], after delay: TimeInterval) {
        guard !items.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects(items)
            log("Clipboard restored after path paste.")
        }
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func cleanupOldTempFiles() {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let expiry = Date().addingTimeInterval(-24 * 60 * 60)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for file in files where file.lastPathComponent.hasPrefix("clip-") && file.pathExtension.lowercased() == "png" {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified < expiry else {
                continue
            }

            do {
                try FileManager.default.removeItem(at: file)
                log("Deleted old temp file: \(file.path)")
            } catch {
                log("Failed deleting old temp file \(file.path): \(error.localizedDescription)")
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
