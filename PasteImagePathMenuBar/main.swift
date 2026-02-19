import AppKit
import Carbon
import ApplicationServices

private let hotKeySignature: OSType = 0x43564F50 // 'CVOP'
private let hotKeyID: UInt32 = 1
private let controlOptionVKeyCode: UInt32 = 9 // 'V' on ANSI keyboard

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        requestAccessibilityIfNeeded()
        cleanupOldTempFiles()
        registerGlobalHotKey()
        print("[PasteImagePath] App started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "ClipPath"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Paste Image Path Now", action: #selector(handleHotkeyAction), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func registerGlobalHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let userData, let eventRef else { return noErr }
            let app = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )

            if status == noErr,
               hkID.signature == hotKeySignature,
               hkID.id == hotKeyID {
                DispatchQueue.main.async {
                    app.handleHotkeyAction()
                }
            }
            return noErr
        }

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            userData,
            &hotKeyHandlerRef
        )

        guard installStatus == noErr else {
            print("[PasteImagePath] Failed to install hotkey handler: \(installStatus)")
            return
        }

        let hk = EventHotKeyID(signature: hotKeySignature, id: hotKeyID)
        let registerStatus = RegisterEventHotKey(
            controlOptionVKeyCode,
            UInt32(controlKey | optionKey),
            hk,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus == noErr {
            print("[PasteImagePath] Registered Ctrl+Option+V")
        } else {
            print("[PasteImagePath] Failed to register hotkey: \(registerStatus)")
        }
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("[PasteImagePath] Accessibility trusted: \(trusted)")
    }

    private func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @objc private func handleHotkeyAction() {
        if !hasAccessibilityPermission(prompt: true) {
            print("[PasteImagePath] Accessibility permission missing; cannot synthesize Cmd+V")
            return
        }

        if let path = saveClipboardImageToTemp() {
            setClipboardString(path)
            print("[PasteImagePath] Image saved and clipboard replaced with path: \(path)")
        } else {
            print("[PasteImagePath] No image in clipboard; performing normal paste")
        }

        simulateCommandV()
    }

    private func saveClipboardImageToTemp() -> String? {
        let pb = NSPasteboard.general
        let pngType = NSPasteboard.PasteboardType("public.png")
        let tiffType = NSPasteboard.PasteboardType("public.tiff")

        let sourceData: Data
        if let data = pb.data(forType: pngType) {
            sourceData = data
            print("[PasteImagePath] Clipboard image type: public.png")
        } else if let data = pb.data(forType: tiffType) {
            sourceData = data
            print("[PasteImagePath] Clipboard image type: public.tiff")
        } else {
            return nil
        }

        guard let image = NSImage(data: sourceData) else {
            print("[PasteImagePath] Failed to decode clipboard image")
            return nil
        }

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            print("[PasteImagePath] Failed to convert image to PNG")
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "/tmp/clip-\(timestamp).png"
        do {
            try pngData.write(to: URL(fileURLWithPath: path), options: .atomic)
            return URL(fileURLWithPath: path).path
        } catch {
            print("[PasteImagePath] Failed to write PNG to /tmp: \(error)")
            return nil
        }
    }

    private func setClipboardString(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }

    private func simulateCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("[PasteImagePath] Failed to create CGEventSource")
            return
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(controlOptionVKeyCode), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(controlOptionVKeyCode), keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func cleanupOldTempFiles() {
        let fm = FileManager.default
        let tmpURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)

        guard let files = try? fm.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return
        }

        for file in files where file.lastPathComponent.hasPrefix("clip-") && file.pathExtension.lowercased() == "png" {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate else { continue }
            if modified < cutoff {
                do {
                    try fm.removeItem(at: file)
                    print("[PasteImagePath] Removed old temp file: \(file.path)")
                } catch {
                    print("[PasteImagePath] Failed removing \(file.path): \(error)")
                }
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
