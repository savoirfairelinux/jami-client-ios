# Jami iOS

This repository contains the iOS client implementation of Jami.

## Requirements

- MacOS version 12 or higher
- XCode version 13 or higher
- Homebrew (instructions could be found on https://brew.sh)
- Carthage (brew install carthage)

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

4. Build client dependencies

```bash
cd Ring && ./fetch-dependencies.sh
```

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
cd client-ios && ./compile-ios.sh --platform=all
cd Ring && ./fetch-dependencies.sh
```

The build script automatically detects whether daemon is available as a local submodule (`./daemon`) or as a sibling directory (`../daemon`). You can also set `DAEMON_DIR` explicitly to point to any jami-daemon checkout.

## XCFrameworks

The build process automatically generates XCFrameworks from the compiled static libraries. These XCFrameworks are located in the `xcframework` directory and include both device (arm64) and simulator (arm64, x86_64) architectures when built with `--platform=all`.

## Update translations

Update translations using the Transifex:

```bash
cd Ring
tx push -s
./update-translations.sh
```
