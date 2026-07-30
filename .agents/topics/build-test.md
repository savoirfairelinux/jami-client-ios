# Build/Test Workflow

- App project: `Ring/Ring.xcodeproj`; main scheme: `Ring`.
- Prefer the latest available iOS runtime unless the task requires a specific iOS version.
- Build the app:
  `xcodebuild -project Ring/Ring.xcodeproj -scheme Ring -configuration Debug -destination "$DESTINATION" build`
- Run tests:
  `xcodebuild -project Ring/Ring.xcodeproj -scheme Ring -configuration Debug -destination "$DESTINATION" test`
- **Rebuild the daemon when it changes:** the app links the C++ `daemon` submodule as prebuilt XCFrameworks in `xcframework/`. If daemon changed, rebuild it `./compile-ios.sh --platform=iPhoneSimulator` (or `iPhoneOS`/`all`).
- **Node.js is required to build.** `Ring/CollabEditor` is the collaborative
  editor; a build phase on the `Ring` target bundles it into the app with
  esbuild. Only its sources are committed. Install with `brew install node`. To
  work on it without Xcode: `npm ci` once, then `npm run build` in
  `Ring/CollabEditor`.
- **The editor's tests are JS, not XCTests.** Run them with `npm test` in
  `Ring/CollabEditor`; CI runs them from the `test` and `unit` fastlane lanes.

