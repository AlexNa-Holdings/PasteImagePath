# Build (Xcode)

1. Create a new macOS App project in Xcode (AppKit lifecycle is fine).
2. Delete generated SwiftUI/AppDelegate/Scene files.
3. Add `main.swift` from this folder to the target.
4. Replace the target `Info.plist` with this folder's `Info.plist` (or set `Application is agent (UIElement)` to `YES`).
5. In target Build Settings, ensure `INFOPLIST_FILE` points to this `Info.plist`.
6. Build and run.
7. On first hotkey use, grant Accessibility permission in:
   - System Settings > Privacy & Security > Accessibility.

Hotkey: `Control + Option + V`
