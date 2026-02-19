# PasteImagePathApp

PasteImagePathApp is a lightweight macOS menu bar app that turns clipboard images into file paths you can paste anywhere.

Default flow:
- Press global hotkey (default `Control + Option + V`).
- If clipboard contains an image, app writes it to a temp PNG file and pastes its absolute path.
- If clipboard does not contain an image, app performs a normal paste.

## Features

- Global configurable hotkey.
- Clipboard image to PNG path conversion.
- Automatic `Command + V` paste after conversion.
- Temporary on-screen preview of pasted image.
- Recent images menu with clickable re-paste of saved paths.
- Automatic cleanup of old temp files.

## Requirements

- macOS (AppKit-based app).
- Xcode 15+ recommended.
- Accessibility permission (required for synthesized `Command + V`).

## Build and Run (Xcode)

1. Open `PasteImagePathApp.xcodeproj`.
2. Select target `PasteImagePathApp`.
3. Build and run.
4. Grant Accessibility permission when prompted.

Accessibility can also be enabled manually at:
`System Settings -> Privacy & Security -> Accessibility`.

## Usage

1. Copy an image to clipboard.
2. Press your configured global hotkey (default `Control + Option + V`).
3. The image is saved as `clip-<timestamp>.png` under `NSTemporaryDirectory()` and its full path is pasted.

Menu bar actions:
- `Recent Images`: Re-paste any recent saved image path.
- `Preferences...`: Change hotkey.
- `Open Accessibility Settings`: Quick link for permissions.
- `Quit`: Exit app.

## Project Structure

- `PasteImagePathApp/main.swift`: Main app implementation and menu bar logic.
- `PasteImagePathApp/Assets.xcassets`: App assets.
- `PasteImagePathApp.xcodeproj`: Xcode project.
- `PasteImagePathMenuBar/`: Early/legacy implementation notes and files.

## Privacy and Security Notes

- The app only reads your clipboard locally.
- Images are written to local temporary storage.
- No network calls are made by the app.
- Temp images are periodically cleaned up.

## Contributing

Contributions are welcome. Please read:
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`

## Release

Use the root script:

```bash
./release
```

What it does:
- Bumps app version (`MARKETING_VERSION`) and build number (`CURRENT_PROJECT_VERSION`).
- Builds `Release` for target `PasteImagePathApp`.
- Packages the built app as `dist/PasteImagePathApp-vX.Y.Z.zip`.
- Creates a release commit and tag.
- Pushes commit/tag to `origin`.
- Creates a GitHub Release and uploads the zip artifact.

Options:

```bash
./release --part patch|minor|major
./release --version 1.2.3
./release --no-push
./release --no-release
```

Requirements:
- Clean git working tree.
- `gh` CLI installed and authenticated (`gh auth login`).
- `xcodebuild` available.

## License

MIT. See `LICENSE`.
