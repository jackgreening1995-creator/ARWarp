# Contributing to ARWarp

Thank you for your interest in contributing.

## Getting Started

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen
   ```
2. Generate the Xcode project:
   ```bash
   xcodegen generate --spec project.yml
   ```
3. Open `ARWarp.xcodeproj` in Xcode 16+.
4. Run the tests to confirm everything works:
   ```bash
   xcodebuild -project ARWarp.xcodeproj -scheme ARWarp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build test
   ```

## Development Workflow

- Fork the repository and create a feature branch from `main`.
- Keep changes focused — one feature or fix per pull request.
- Add or update tests for any new or changed functionality.
- Run the full build and test suite before submitting.
- Follow the existing code style (Swift 5.9 conventions, no force-unwrapping in framework code).
- Update documentation if your change affects the public API or setup instructions.

## Pull Request Checklist

- [ ] Tests pass locally (`xcodebuild ... test`)
- [ ] Project builds cleanly (`xcodegen generate` then `xcodebuild ... build`)
- [ ] New code follows existing patterns and conventions
- [ ] Relevant documentation is updated
- [ ] No new compiler warnings

## Reporting Issues

Use the issue templates to report bugs or request features. Include:
- Device model and iOS version
- Steps to reproduce
- Expected vs actual behavior
- Any relevant logs or screenshots

## Code of Conduct

Be respectful and constructive. This is an experimental project — questions, ideas, and feedback are welcome.
