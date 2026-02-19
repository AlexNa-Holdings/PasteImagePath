# Contributing to PasteImagePathApp

Thanks for contributing.

## Development Setup

1. Open `PasteImagePathApp.xcodeproj` in Xcode.
2. Build and run target `PasteImagePathApp`.
3. Grant Accessibility permission so hotkey paste simulation works.

## Pull Request Guidelines

1. Keep changes focused and minimal.
2. Prefer small PRs with clear intent.
3. Include a short summary of:
   - What changed
   - Why it changed
   - How you tested it
4. Update docs when behavior changes.

## Coding Guidelines

- Follow existing code style in `PasteImagePathApp/main.swift`.
- Keep logs concise and useful.
- Avoid adding new dependencies unless necessary.
- Preserve AppKit/menu bar behavior and global hotkey reliability.

## Testing Checklist

- App launches without dock icon.
- Global hotkey works.
- Image clipboard converts to PNG path and pastes correctly.
- Non-image clipboard still performs normal paste.
- Recent images menu updates and entries are clickable.
- Accessibility prompt/handling works as expected.

## Reporting Issues

When filing issues, include:
- macOS version
- Xcode version (if relevant)
- Steps to reproduce
- Expected vs actual behavior
- Any console logs or screenshots
