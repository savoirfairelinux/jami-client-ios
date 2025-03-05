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

1. Clone the project

```bash
git clone https://review.jami.net/jami-project
```

2. Initialize repositories

```bash
cd jami-project && ./build.py --init
```

3. Install dependencies

```bash
./build.py --dependencies --distribution IOS
```

4. Build daemon and contributions (choose one option):

   **Option A: For iPhone device only**
   ```bash
   cd client-ios && ./compile-ios.sh --platform=iPhoneOS
   ```

   **Option B: For simulator only**
   ```bash
   cd client-ios && ./compile-ios.sh --platform=iPhoneSimulator
   ```

   **Option C: For both iPhone device and simulator**
   ```bash
   cd client-ios && ./compile-ios.sh --platform=all
   ```

   **Additional options:**
   ```
   --release         Build in release mode with optimizations
   --host=ARCH       Specify a specific architecture for simulator builds (arm64 or x86_64)
                     Note: This option is only used when building for simulator
   --help            Display detailed help information
   ```

5. Build client dependencies

```bash
cd Ring && ./fetch-dependencies.sh
```

## XCFrameworks

The build process automatically generates XCFrameworks from the compiled static libraries. These XCFrameworks are located in the `xcframework` directory and include both device (arm64) and simulator (arm64, x86_64) architectures when built with `--platform=all`.

## Update translations

Update translations using the Transifex:

```bash
cd Ring
tx push -s
./update-translations.sh
```
