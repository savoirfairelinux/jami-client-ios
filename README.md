# Jami iOS

This repository contains the iOS client implementation of Jami.

## Requirements

- macOS 12 or higher
- Xcode 13 or higher
- [Homebrew](https://brew.sh)
- Carthage (`brew install carthage`)

## Build instructions

Supported archs are: arm64 for iPhoneOS and arm64, x86_64 for iPhoneSimulator
Minimum supported version is: 14.5

### Standalone (recommended)

1. Clone the repository with the daemon submodule

```bash
git clone --recurse-submodules https://review.jami.net/jami-client-ios
cd jami-client-ios
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init
```

2. Install dependencies

```bash
brew install carthage
```

3. Build daemon and contributions (choose one option):

   **Option A: For iPhone device only**
   ```bash
   ./compile-ios.sh --platform=iPhoneOS
   ```

   **Option B: For simulator only**
   ```bash
   ./compile-ios.sh --platform=iPhoneSimulator
   ```

   **Option C: For both iPhone device and simulator**
   ```bash
   ./compile-ios.sh --platform=all
   ```

   **Additional options:**
   ```
   --release         Build in release mode with optimizations
   --arch=ARCH       Specify a specific architecture for simulator builds (arm64 or x86_64)
                     Note: This option is only used when building for iPhoneSimulator
   --help            Display detailed help information
   ```

4. Fetch Carthage dependencies

```bash
cd Ring && ./fetch-dependencies.sh
```

5. Open `Ring/Ring.xcodeproj` in Xcode and build the project.

### Using jami-project (alternative)

You can also build client-ios as part of the jami-project monorepo:

1. Clone and initialize jami-project

```bash
git clone https://review.jami.net/jami-project
cd jami-project && ./build.py --init
```

2. Install dependencies

```bash
./build.py --dependencies --distribution IOS
```

3. Build daemon and client

```bash
cd client-ios && DAEMON_DIR=../daemon ./compile-ios.sh --platform=all
cd Ring && ./fetch-dependencies.sh
```

> **Note:** In the monorepo layout the daemon lives at `../daemon` rather than as a submodule, so `DAEMON_DIR` must be set explicitly as shown above.

## XCFrameworks

The build process automatically generates XCFrameworks from the compiled static libraries. These XCFrameworks are located in the `xcframework` directory and include both device (arm64) and simulator (arm64, x86_64) architectures when built with `--platform=all`.

## Update translations

Update translations using Transifex:

```bash
cd Ring
tx push -s
./update-translations.sh
```
