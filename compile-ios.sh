#! /bin/sh

export BUILDFORIOS=1
export MIN_IOS_VERSION=14.5
IOS_TARGET_PLATFORM=iPhoneSimulator
RELEASE=0

while test -n "$1"
do
  case "$1" in
    --platform=*)
      IOS_TARGET_PLATFORM="${1#--platform=}"
    ;;
    --host=*)
      HOST="${1#--host=}"
    ;;
    --release)
    RELEASE=1
    ;;
  esac
  shift
done

if test -z "$HOST"
then
  if [ "$IOS_TARGET_PLATFORM" = "all" ]
  then
    # Build for all three combinations
    ARCHS_PLATFORMS=("arm64:iPhoneOS" "arm64:iPhoneSimulator" "x86_64:iPhoneSimulator")
  elif [ "$IOS_TARGET_PLATFORM" = "iPhoneSimulator" ]
  then
    # Build for both simulator architectures
    ARCHS_PLATFORMS=("arm64:iPhoneSimulator" "x86_64:iPhoneSimulator")
  elif [ "$IOS_TARGET_PLATFORM" = "iPhoneOS" ]
  then
    ARCHS_PLATFORMS=("arm64:iPhoneOS")
  fi
else
  case "$HOST" in
    aarch64-*)
      if [ "$IOS_TARGET_PLATFORM" = "iPhoneSimulator" ]
      then
        ARCHS_PLATFORMS=("arm64:iPhoneSimulator")
      else
        ARCHS_PLATFORMS=("arm64:iPhoneOS")
      fi
    ;;
    x86_64-*)
      ARCHS_PLATFORMS=("x86_64:iPhoneSimulator")
    ;;
  esac
fi

IOS_TOP_DIR="$(pwd)"

if [ -z "$DAEMON_DIR" ]; then
  DAEMON_DIR="$(pwd)/../daemon"
  echo "DAEMON_DIR not provided attempting to find it in $DAEMON_DIR"
fi
if [ ! -d "$DAEMON_DIR" ]; then
  echo 'Daemon not found.'
  echo 'If you cloned the daemon in a custom location override' \
       'use DAEMON_DIR to point to it'
  echo "You can also use our meta repo which contains both:
        https://review.jami.net/admin/repos/jami-project"
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

for ARCH_PLATFORM in "${ARCHS_PLATFORMS[@]}"
do
  # Split the architecture and platform
  ARCH="${ARCH_PLATFORM%%:*}"
  IOS_TARGET_PLATFORM="${ARCH_PLATFORM#*:}"
  export IOS_TARGET_PLATFORM
  
  echo "Building for $IOS_TARGET_PLATFORM with architecture $ARCH"
  
  # Create a unique build directory for this combination
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

  # Specify contrib folder path but don't create it (bootstrap will create it)
  CONTRIB_FOLDER="$DAEMON_DIR/contrib/contrib-$BUILD_DIR"

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

# Create XCFrameworks instead of fat libraries
XCFRAMEWORK_DIR="$IOS_TOP_DIR/xcframework"
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

# Process each library
LIBFILES="$IOS_TOP_DIR/DEPS/${BUILD_DIRS[0]}/lib/"*.a
for f in $LIBFILES
do
  libFile=${f##*/}
  FRAMEWORK_NAME="${libFile%.a}"
  
  # Check if this library exists in at least one simulator build
  HAS_SIMULATOR_LIB=false
  for BUILD in "${SIMULATOR_BUILDS[@]}"; do
    if [ -f "$IOS_TOP_DIR/DEPS/$BUILD/lib/$libFile" ]; then
      HAS_SIMULATOR_LIB=true
      break
    fi
  done
  
  # Check if this library exists in at least one device build
  HAS_DEVICE_LIB=false
  for BUILD in "${DEVICE_BUILDS[@]}"; do
    if [ -f "$IOS_TOP_DIR/DEPS/$BUILD/lib/$libFile" ]; then
      HAS_DEVICE_LIB=true
      break
    fi
  done
  
  # Skip if the library doesn't exist for any platform
  if [ "$HAS_SIMULATOR_LIB" = "false" ] && [ "$HAS_DEVICE_LIB" = "false" ]; then
    echo "Skipping $FRAMEWORK_NAME - not available for any platform"
    continue
  fi
  
  echo "Processing $FRAMEWORK_NAME for XCFramework..."
  
  # Create temporary directories for device and simulator frameworks
  TEMP_DIR="$IOS_TOP_DIR/temp"
  mkdir -p "$TEMP_DIR"
  
  # Create framework for each platform
  FRAMEWORK_ARGS=""
  
  # Process device builds (typically just arm64)
  if [ ${#DEVICE_BUILDS[@]} -gt 0 ]; then
    DEVICE_DIR="$TEMP_DIR/device"
    mkdir -p "$DEVICE_DIR"
    
    if [ "$HAS_DEVICE_LIB" = "true" ]; then
      # Create fat library for device if multiple architectures
      if [ ${#DEVICE_BUILDS[@]} -gt 1 ]; then
        mkdir -p "$DEVICE_DIR/lib"
        LIPO_CMD="lipo -create"
        LIPO_INPUTS=0
        for BUILD in "${DEVICE_BUILDS[@]}"; do
          if [ -f "$IOS_TOP_DIR/DEPS/$BUILD/lib/$libFile" ]; then
            LIPO_CMD+=" $IOS_TOP_DIR/DEPS/$BUILD/lib/$libFile"
            LIPO_INPUTS=$((LIPO_INPUTS+1))
          fi
        done
        
        if [ $LIPO_INPUTS -gt 0 ]; then
          $LIPO_CMD -output "$DEVICE_DIR/lib/$libFile"
        fi
      else
        # Just copy the single architecture file if it exists
        if [ -f "$IOS_TOP_DIR/DEPS/${DEVICE_BUILDS[0]}/lib/$libFile" ]; then
          mkdir -p "$DEVICE_DIR/lib"
          cp "$IOS_TOP_DIR/DEPS/${DEVICE_BUILDS[0]}/lib/$libFile" "$DEVICE_DIR/lib/$libFile"
        fi
      fi
    else
      # Create a dummy library for device if it doesn't exist
      echo "Creating dummy device library for $FRAMEWORK_NAME"
      mkdir -p "$DEVICE_DIR/lib"

      # Create a dummy object file first
      echo "void dummy_function() {}" > "$TEMP_DIR/dummy.c"
      $CC -c "$TEMP_DIR/dummy.c" -o "$TEMP_DIR/dummy.o"

      # Create a static library with the dummy object
      ar -rc "$DEVICE_DIR/lib/$libFile" "$TEMP_DIR/dummy.o"
    fi
    
    # Create framework structure
    mkdir -p "$DEVICE_DIR/$FRAMEWORK_NAME.framework"
    cp "$DEVICE_DIR/lib/$libFile" "$DEVICE_DIR/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
    
    # Create a minimal Info.plist
    cat > "$DEVICE_DIR/$FRAMEWORK_NAME.framework/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>org.jami.${FRAMEWORK_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${FRAMEWORK_NAME}</string>
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
    
    FRAMEWORK_ARGS+=" -framework $DEVICE_DIR/$FRAMEWORK_NAME.framework"
  fi
  
  # Process simulator builds
  if [ ${#SIMULATOR_BUILDS[@]} -gt 0 ]; then
    SIM_DIR="$TEMP_DIR/simulator"
    mkdir -p "$SIM_DIR"
    
    if [ "$HAS_SIMULATOR_LIB" = "true" ]; then
      # Create fat library for simulator if multiple architectures
      if [ ${#SIMULATOR_BUILDS[@]} -gt 1 ]; then
        mkdir -p "$SIM_DIR/lib"
        LIPO_CMD="lipo -create"
        LIPO_INPUTS=0
        for BUILD in "${SIMULATOR_BUILDS[@]}"; do
          if [ -f "$IOS_TOP_DIR/DEPS/$BUILD/lib/$libFile" ]; then
            LIPO_CMD+=" $IOS_TOP_DIR/DEPS/$BUILD/lib/$libFile"
            LIPO_INPUTS=$((LIPO_INPUTS+1))
          fi
        done
        
        if [ $LIPO_INPUTS -gt 0 ]; then
          $LIPO_CMD -output "$SIM_DIR/lib/$libFile"
        fi
      else
        # Just copy the single architecture file if it exists
        if [ -f "$IOS_TOP_DIR/DEPS/${SIMULATOR_BUILDS[0]}/lib/$libFile" ]; then
          mkdir -p "$SIM_DIR/lib"
          cp "$IOS_TOP_DIR/DEPS/${SIMULATOR_BUILDS[0]}/lib/$libFile" "$SIM_DIR/lib/$libFile"
        fi
      fi
    else
      # Create a dummy library for simulator if it doesn't exist
      echo "Creating dummy simulator library for $FRAMEWORK_NAME"
      mkdir -p "$SIM_DIR/lib"

      # Create a dummy object file first
      echo "void dummy_function() {}" > "$TEMP_DIR/dummy.c"
      $CC -c "$TEMP_DIR/dummy.c" -o "$TEMP_DIR/dummy.o"

      # Create a static library with the dummy object
      ar -rc "$SIM_DIR/lib/$libFile" "$TEMP_DIR/dummy.o"
    fi
    
    # Create framework structure
    mkdir -p "$SIM_DIR/$FRAMEWORK_NAME.framework"
    cp "$SIM_DIR/lib/$libFile" "$SIM_DIR/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
    
    # Create a minimal Info.plist
    cat > "$SIM_DIR/$FRAMEWORK_NAME.framework/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>org.jami.${FRAMEWORK_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${FRAMEWORK_NAME}</string>
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
    
    FRAMEWORK_ARGS+=" -framework $SIM_DIR/$FRAMEWORK_NAME.framework"
  fi
  
  # Create XCFramework
  xcrun xcodebuild -create-xcframework $FRAMEWORK_ARGS -output "$XCFRAMEWORK_DIR/$FRAMEWORK_NAME.xcframework"
  echo "Created $FRAMEWORK_NAME.xcframework"
  
  # Clean up temporary directories
  rm -rf "$TEMP_DIR"
done

echo "XCFrameworks created in $XCFRAMEWORK_DIR"
echo "Headers copied to $XCFRAMEWORK_DIR/include"
echo "You can now link these XCFrameworks in your Xcode project"
