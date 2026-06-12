# Build/Test Workflow

- App project: `Ring/Ring.xcodeproj`; main scheme: `Ring`.
- Prefer the latest available iOS runtime unless the task requires a specific iOS version.
- Build the app:
  `xcodebuild -project Ring/Ring.xcodeproj -scheme Ring -configuration Debug -destination "$DESTINATION" build`
- Run tests:
  `xcodebuild -project Ring/Ring.xcodeproj -scheme Ring -configuration Debug -destination "$DESTINATION" test`
