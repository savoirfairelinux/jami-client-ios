# Build/Test Workflow

- App project: `Ring/Ring.xcodeproj`; main scheme: `Ring`.
- Prefer the latest available iOS runtime unless the task requires a specific iOS version.
- Build the app:
  `xcodebuild -project Ring/Ring.xcodeproj -scheme Ring -configuration Debug -destination "$DESTINATION" build`
- Run tests:
  `xcodebuild -project Ring/Ring.xcodeproj -scheme Ring -configuration Debug -destination "$DESTINATION" test`
- **Rebuild the daemon when it changes:** the app links the C++ `daemon` submodule as prebuilt XCFrameworks in `xcframework/`. If daemon changed, rebuild it `./compile-ios.sh --platform=iPhoneSimulator` (or `iPhoneOS`/`all`).

