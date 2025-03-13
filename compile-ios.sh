#! /bin/sh

export BUILDFORIOS=1
export MIN_IOS_VERSION=14.5
IOS_TARGET_PLATFORM=iPhoneSimulator
RELEASE=0

# Display help information
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Build Jami for iOS platforms"
  echo ""
  echo "Options:"
  echo "  --platform=PLATFORM   Specify the target platform (iPhoneOS, iPhoneSimulator, all)"
  echo "                        iPhoneOS: Build for physical iPhone devices (arm64)"
  echo "                        iPhoneSimulator: Build for iPhone simulators (arm64, x86_64)"
  echo "                        all: Build for both devices and simulators"
  echo "  --arch=ARCH           Specify a specific architecture for simulator builds (arm64 or x86_64)"
  echo "                        Note: This option is only used when building for iPhoneSimulator"
  echo "  --release             Build in release mode with optimizations"
  echo "  --help                Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --platform=iPhoneOS                           # Build for iPhone devices"
  echo "  $0 --platform=iPhoneSimulator                    # Build for all simulator architectures"
  echo "  $0 --platform=iPhoneSimulator --arch=arm64       # Build only for arm64 simulator"
  echo "  $0 --platform=iPhoneSimulator --arch=x86_64      # Build only for x86_64 simulator"
  echo "  $0 --platform=all --release                      # Build for all platforms in release mode"
  exit 0
}

# Process command line arguments
while test -n "$1"
do
  case "$1" in
    --platform=*)
      IOS_TARGET_PLATFORM="${1#--platform=}"
    ;;
    --arch=*)
      ARCH_ARG="${1#--arch=}"
      # Convert simple architecture names to compiler triplets
      case "$ARCH_ARG" in
        arm64)
          ARCH="aarch64-apple-darwin_ios"
          ;;
        x86_64)
          ARCH="x86_64-apple-darwin_ios"
          ;;
        *)
          # Assume it's already a compiler triplet
          ARCH="$ARCH_ARG"
          ;;
      esac
    ;;
    --release)
      RELEASE=1
    ;;
    --help)
      show_help
    ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
    ;;
  esac
  shift
done

if [ "$IOS_TARGET_PLATFORM" = "all" ]
then
  ARCHS_PLATFORMS=("arm64:iPhoneOS" "arm64:iPhoneSimulator" "x86_64:iPhoneSimulator")
elif [ "$IOS_TARGET_PLATFORM" = "iPhoneSimulator" ]
then
  # For simulator, check if a specific architecture was requested
  if [ -n "$ARCH" ]
  then
    case "$ARCH" in
      aarch64-*)
        ARCHS_PLATFORMS=("arm64:iPhoneSimulator")
        ;;
      x86_64-*)
        ARCHS_PLATFORMS=("x86_64:iPhoneSimulator")
        ;;
      *)
        echo "Warning: Unrecognized host architecture for simulator: $ARCH"
        echo "Using default simulator architectures"
        ARCHS_PLATFORMS=("arm64:iPhoneSimulator" "x86_64:iPhoneSimulator")
        ;;
    esac
  else
    # No specific architecture requested, build for all simulator architectures
    ARCHS_PLATFORMS=("arm64:iPhoneSimulator" "x86_64:iPhoneSimulator")
  fi
elif [ "$IOS_TARGET_PLATFORM" = "iPhoneOS" ]
then
  # For device builds, always use arm64 regardless of --arch
  if [ -n "$ARCH" ] && [[ "$ARCH" != aarch64-* ]]; then
    echo "Warning: --arch parameter is ignored for iPhoneOS builds (always uses arm64)"
  fi
  ARCHS_PLATFORMS=("arm64:iPhoneOS")
fi

IOS_TOP_DIR="$(pwd)"

if [ -z "$DAEMON_DIR" ]; then
  DAEMON_DIR="$(pwd)/../daemon"
  echo "DAEMON_DIR not provided attempting to find it in $DAEMON_DIR"
fi
if [ ! -d "$DAEMON_DIR" ]; then
  echo 'Daemon not found.'
  exit 1
fi

if [ ! $(which gas-preprocessor.pl) ]
then
  echo 'gas-preprocessor.pl not found. Attempting to install…'
  mkdir -p "$DAEMON_DIR/extras/tools/build/bin/"
  (curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
    -o "$DAEMON_DIR/extras/tools/build/bin/gas-preprocessor.pl" \
    && chmod +x "$DAEMON_DIR/extras/tools/build/bin/gas-preprocessor.pl")
  export PATH="$DAEMON_DIR/extras/tools/build/bin:$PATH"
fi

if [ -z "$NPROC"  ]; then
  NPROC=$(sysctl -n hw.ncpu || echo -n 1)
fi

echo "Building for ${ARCHS_PLATFORMS[@]}"

cd "$DAEMON_DIR"

# clean build artifacts
# remove existing DEPS folder if it exists
DEPS_DIR="$IOS_TOP_DIR/DEPS"
if [ -d "$DEPS_DIR" ]; then
  rm -rf "$DEPS_DIR"
fi

# remove existing XCFramework folder if it exists
XCFRAMEWORK_DIR="$IOS_TOP_DIR/xcframework"
if [ -d "$XCFRAMEWORK_DIR" ]; then
  rm -rf "$XCFRAMEWORK_DIR"
fi

for ARCH_PLATFORM in "${ARCHS_PLATFORMS[@]}"
do
  # Split the architecture and platform
  ARCH="${ARCH_PLATFORM%%:*}"
  IOS_TARGET_PLATFORM="${ARCH_PLATFORM#*:}"
  export IOS_TARGET_PLATFORM

  echo "Building for $IOS_TARGET_PLATFORM with architecture $ARCH"

  BUILD_DIR="$ARCH-$IOS_TARGET_PLATFORM"
  mkdir -p "contrib/native-$BUILD_DIR"
  cd "contrib/native-$BUILD_DIR"

  if [ "$ARCH" = "arm64" ]
  then
    HOST=aarch64-apple-darwin_ios
  else
    HOST="$ARCH"-apple-darwin_ios
  fi

  SDKROOT=$(xcode-select -print-path)/Platforms/${IOS_TARGET_PLATFORM}.platform/Developer/SDKs/${IOS_TARGET_PLATFORM}${SDK_VERSION}.sdk

  host=$(sw_vers -productVersion)
  if [ "12.0" \> "$host" ]
  then
      SDK="$(echo "print '${IOS_TARGET_PLATFORM}'.lower()" | python)"
  else
      SDK="$(echo "print('${IOS_TARGET_PLATFORM}'.lower())" | python3)"
  fi

  CC="xcrun -sdk $SDK clang"
  CXX="xcrun -sdk $SDK clang++"

  CONTRIB_FOLDER="$DAEMON_DIR/contrib/$BUILD_DIR"

  # Parameters for pjproject build
  if [ "$IOS_TARGET_PLATFORM" = "iPhoneSimulator" ]; then
    MIN_IOS="-mios-simulator-version-min=$MIN_IOS_VERSION"
  else
    MIN_IOS="-miphoneos-version-min=$MIN_IOS_VERSION"
  fi

  DEVPATH=$(xcrun --sdk $SDK --show-sdk-platform-path)/Developer
  export DEVPATH
  export MIN_IOS

  # Print DEVPATH and MIN_IOS
  echo "DEVPATH: $DEVPATH"
  echo "MIN_IOS: $MIN_IOS"

  # Pass IOS_TARGET_PLATFORM to bootstrap so it can be used in rules.mak files
  SDKROOT="$SDKROOT" ../bootstrap --host="$HOST" --disable-libav --disable-plugin --disable-libarchive --enable-ffmpeg --prefix="$CONTRIB_FOLDER"

  echo "Building contrib"
  make fetch
  make -j"$NPROC" || exit 1

  cd ../..
  echo "Building daemon"

  CFLAGS="-arch $ARCH -isysroot $SDKROOT"
  if [ "$IOS_TARGET_PLATFORM" = "iPhoneOS" ]
  then
    CFLAGS+=" -miphoneos-version-min=$MIN_IOS_VERSION -fembed-bitcode"
  else
    CFLAGS+=" -mios-simulator-version-min=$MIN_IOS_VERSION"
  fi

  if [ "$RELEASE" = "1" ]
  then
    CFLAGS+=" -O3"
  fi

  CXXFLAGS="-stdlib=libc++ -std=c++17 $CFLAGS"
  LDFLAGS="$CFLAGS"

  ./autogen.sh || exit 1
  mkdir -p "build-ios-$BUILD_DIR"
  cd "build-ios-$BUILD_DIR"

  JAMI_CONF="--host=$HOST \
             --without-dbus \
             --disable-plugin \
             --disable-libarchive \
             --enable-static \
             --without-natpmp \
             --disable-shared \
             --prefix=$IOS_TOP_DIR/DEPS/$BUILD_DIR \
             --with-contrib=$CONTRIB_FOLDER"

  if [ "$RELEASE" = "0" ]
  then
    JAMI_CONF+=" --enable-debug"
  fi

  "$DAEMON_DIR"/configure $JAMI_CONF \
                        CC="$CC $CFLAGS" \
                        CXX="$CXX $CXXFLAGS" \
                        OBJCXX="$CXX $CXXFLAGS" \
                        LD="$LD" \
                        CFLAGS="$CFLAGS" \
                        CXXFLAGS="$CXXFLAGS" \
                        LDFLAGS="$LDFLAGS" || exit 1

  # We need to copy this file or else it's just an empty file
  rsync -a "$DAEMON_DIR/src/buildinfo.cpp" ./src/buildinfo.cpp

  make -j"$NPROC" || exit 1
  make install || exit 1

  # Use the specified contrib folder for copying libraries and headers
  rsync -ar "$CONTRIB_FOLDER/lib/"*.a "$IOS_TOP_DIR/DEPS/$BUILD_DIR/lib/"
  # copy headers for extension
  rsync -ar "$CONTRIB_FOLDER/include/opendht" "$IOS_TOP_DIR/DEPS/$BUILD_DIR/include/"
  rsync -ar "$CONTRIB_FOLDER/include/msgpack.hpp" "$IOS_TOP_DIR/DEPS/$BUILD_DIR/include/"
  rsync -ar "$CONTRIB_FOLDER/include/gnutls" "$IOS_TOP_DIR/DEPS/$BUILD_DIR/include/"
  rsync -ar "$CONTRIB_FOLDER/include/json" "$IOS_TOP_DIR/DEPS/$BUILD_DIR/include/"
  rsync -ar "$CONTRIB_FOLDER/include/msgpack" "$IOS_TOP_DIR/DEPS/$BUILD_DIR/include/"
  rsync -ar "$CONTRIB_FOLDER/include/yaml-cpp" "$IOS_TOP_DIR/DEPS/$BUILD_DIR/include/"
  rsync -ar "$CONTRIB_FOLDER/include/libavutil" "$IOS_TOP_DIR/DEPS/$BUILD_DIR/include/"
  rsync -ar "$CONTRIB_FOLDER/include/fmt" "$IOS_TOP_DIR/DEPS/$BUILD_DIR/include/"
  cd "$IOS_TOP_DIR/DEPS/$BUILD_DIR/lib/"
  for i in *.a ; do mv "$i" "${i/-$HOST.a/.a}" ; done

  cd "$DAEMON_DIR"
done

cd "$IOS_TOP_DIR"

# Create XCFrameworks

mkdir -p "$XCFRAMEWORK_DIR"

# Copy headers to a common location
mkdir -p "$XCFRAMEWORK_DIR/include"
if [ -d "$IOS_TOP_DIR/DEPS/${ARCHS_PLATFORMS[0]%%:*}-${ARCHS_PLATFORMS[0]#*:}/include/" ]; then
  rsync -ar --delete "$IOS_TOP_DIR/DEPS/${ARCHS_PLATFORMS[0]%%:*}-${ARCHS_PLATFORMS[0]#*:}/include/"* "$XCFRAMEWORK_DIR/include"
else
  echo "Warning: No include directory found for ${ARCHS_PLATFORMS[0]}"
fi

echo "Creating XCFrameworks..."

# Get list of all libraries from the first build directory
BUILD_DIRS=()
for ARCH_PLATFORM in "${ARCHS_PLATFORMS[@]}"
do
  BUILD_DIRS+=("${ARCH_PLATFORM%%:*}-${ARCH_PLATFORM#*:}")
done

# Group build directories by platform
DEVICE_BUILDS=()
SIMULATOR_BUILDS=()

for BUILD_DIR in "${BUILD_DIRS[@]}"
do
  if [[ "$BUILD_DIR" == *-iPhoneOS ]]; then
    DEVICE_BUILDS+=("$BUILD_DIR")
  elif [[ "$BUILD_DIR" == *-iPhoneSimulator ]]; then
    SIMULATOR_BUILDS+=("$BUILD_DIR")
  fi
done

# Function to create Info.plist for frameworks
create_info_plist() {
  local framework_path="$1"
  local framework_name="$2"

  cat > "$framework_path/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${framework_name}</string>
    <key>CFBundleIdentifier</key>
    <string>com.jami.${framework_name}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${framework_name}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>${MIN_IOS_VERSION}</string>
</dict>
</plist>
EOF
}

# Function to create framework for a platform
create_framework() {
  local PLATFORM_DIR="$1"
  local FRAMEWORK_NAME="$2"
  local LIB_FILE="$3"
  local SDK="$4"

  mkdir -p "$PLATFORM_DIR/lib"

  # Check if library exists in any of the builds for this platform
  local LIB_PATHS=()
  local BUILDS=("${@:5}")

  for BUILD in "${BUILDS[@]}"; do
    if [ -f "$IOS_TOP_DIR/DEPS/$BUILD/lib/$LIB_FILE" ]; then
      LIB_PATHS+=("$IOS_TOP_DIR/DEPS/$BUILD/lib/$LIB_FILE")
      echo "Found $LIB_FILE in $BUILD" >&2
    fi
  done

  if [ ${#LIB_PATHS[@]} -gt 0 ]; then
    if [ ${#LIB_PATHS[@]} -gt 1 ]; then
      # Multiple libraries found, use lipo to combine them
      echo "Combining multiple $SDK libraries for $FRAMEWORK_NAME" >&2
      lipo -create "${LIB_PATHS[@]}" -output "$PLATFORM_DIR/lib/$LIB_FILE"
    else
      # Only one library found
      cp "${LIB_PATHS[0]}" "$PLATFORM_DIR/lib/$LIB_FILE"
    fi

    # Print architectures in the library for debugging
    echo "Architectures in $FRAMEWORK_NAME for $SDK:" >&2
    lipo -info "$PLATFORM_DIR/lib/$LIB_FILE" >&2
  else
    # Create a dummy library
    echo "Creating dummy $SDK library for $FRAMEWORK_NAME" >&2
    echo "void dummy_function() {}" > "$TEMP_DIR/dummy.c"
    xcrun -sdk $SDK clang -c "$TEMP_DIR/dummy.c" -o "$TEMP_DIR/dummy.o"
    ar -rc "$PLATFORM_DIR/lib/$LIB_FILE" "$TEMP_DIR/dummy.o"
  fi

  # Create framework structure
  mkdir -p "$PLATFORM_DIR/$FRAMEWORK_NAME.framework"
  cp "$PLATFORM_DIR/lib/$LIB_FILE" "$PLATFORM_DIR/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
  create_info_plist "$PLATFORM_DIR/$FRAMEWORK_NAME.framework" "$FRAMEWORK_NAME"

  printf "%s" "-framework $PLATFORM_DIR/$FRAMEWORK_NAME.framework"
}

# Process each library
LIBFILES="$IOS_TOP_DIR/DEPS/${BUILD_DIRS[0]}/lib/"*.a
for f in $LIBFILES
do
  libFile=${f##*/}
  FRAMEWORK_NAME="${libFile%.a}"

  echo "Processing $FRAMEWORK_NAME for XCFramework..."

  # Create temporary directory
  TEMP_DIR="$IOS_TOP_DIR/temp"
  mkdir -p "$TEMP_DIR"

  # Create frameworks for each platform
  DEVICE_FRAMEWORK=$(create_framework "$TEMP_DIR/device" "$FRAMEWORK_NAME" "$libFile" "iphoneos" "${DEVICE_BUILDS[@]}")
  SIM_FRAMEWORK=$(create_framework "$TEMP_DIR/simulator" "$FRAMEWORK_NAME" "$libFile" "iphonesimulator" "${SIMULATOR_BUILDS[@]}")

  # Create XCFramework
  xcrun xcodebuild -create-xcframework $DEVICE_FRAMEWORK $SIM_FRAMEWORK -output "$XCFRAMEWORK_DIR/$FRAMEWORK_NAME.xcframework"
  echo "Created $FRAMEWORK_NAME.xcframework"

  # Clean up temporary directories
  rm -rf "$TEMP_DIR"
done

# Special check for libvpx.xcframework, because vpx disabled for arm64 simulator
if [ ! -d "$XCFRAMEWORK_DIR/libvpx.xcframework" ]; then
  echo "libvpx.xcframework not found, creating it manually..."

  # Create temporary directory
  TEMP_DIR="$IOS_TOP_DIR/temp_vpx"
  mkdir -p "$TEMP_DIR"

  # Create frameworks for each platform
  DEVICE_FRAMEWORK=$(create_framework "$TEMP_DIR/device" "libvpx" "libvpx.a" "iphoneos" "${DEVICE_BUILDS[@]}")
  SIM_FRAMEWORK=$(create_framework "$TEMP_DIR/simulator" "libvpx" "libvpx.a" "iphonesimulator" "${SIMULATOR_BUILDS[@]}")

  # Create XCFramework
  xcrun xcodebuild -create-xcframework $DEVICE_FRAMEWORK $SIM_FRAMEWORK -output "$XCFRAMEWORK_DIR/libvpx.xcframework"
  echo "Created libvpx.xcframework"

  # Clean up temporary directories
  rm -rf "$TEMP_DIR"
fi

echo "XCFrameworks created in $XCFRAMEWORK_DIR"
echo "Headers copied to $XCFRAMEWORK_DIR/include"
