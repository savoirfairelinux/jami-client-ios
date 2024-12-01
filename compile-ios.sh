#!/bin/bash

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

if [ "$IOS_TARGET_PLATFORM" = "all" ]; then
  PLATFORMS=("iPhoneOS" "iPhoneSimulator")
  ARCHS_IOS=("arm64")
  ARCHS_SIMULATOR=("x86_64" "arm64")
else
  PLATFORMS=("$IOS_TARGET_PLATFORM")
  if [ "$IOS_TARGET_PLATFORM" = "iPhoneOS" ]; then
    ARCHS=("arm64")
  elif [ "$IOS_TARGET_PLATFORM" = "iPhoneSimulator" ]; then
    ARCHS=("x86_64" "arm64")
  fi
fi

if [ -z "$NPROC" ]; then
  NPROC=$(sysctl -n hw.ncpu || echo -n 1)
fi

if [ -z "$DAEMON_DIR" ]; then
  DAEMON_DIR="$(pwd)/../daemon"
  echo "DAEMON_DIR not provided, trying to find it in $DAEMON_DIR"
fi
if [ ! -d "$DAEMON_DIR" ]; then
  echo "Daemon not found."
  echo "If you cloned the daemon in a custom location, override it using DAEMON_DIR to point to it."
  exit 1
fi

if [ ! $(which gas-preprocessor.pl) ]; then
  echo "gas-preprocessor.pl not found. Trying to install..."
  mkdir -p "$DAEMON_DIR/extras/tools/build/bin/"
  (curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
    -o "$DAEMON_DIR/extras/tools/build/bin/gas-preprocessor.pl" \
    && chmod +x "$DAEMON_DIR/extras/tools/build/bin/gas-preprocessor.pl")
  export PATH="$DAEMON_DIR/extras/tools/build/bin:$PATH"
fi

IOS_TOP_DIR="$(pwd)"
FAT_DIR="$IOS_TOP_DIR/fat"
mkdir -p "$FAT_DIR/lib"

for PLATFORM in "${PLATFORMS[@]}"; do
  if [ "$PLATFORM" = "iPhoneOS" ]; then
    ARCHS=("${ARCHS_IOS[@]}")
  else
    ARCHS=("${ARCHS_SIMULATOR[@]}")
  fi

  host=$(sw_vers -productVersion)
  if [ "12.0" \> "$host" ]
  then
      SDK="$(echo "print '${PLATFORM}'.lower()" | python)"
  else
      SDK="$(echo "print('${PLATFORM}'.lower())" | python3)"
  fi

  IOS_TARGET_PLATFORM=$PLATFORM
  export IOS_TARGET_PLATFORM


  for ARCH in "${ARCHS[@]}"; do
    echo "Building for $PLATFORM $ARCH"
    BUILD_DIR="$DAEMON_DIR/contrib/native-$PLATFORM-$ARCH"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [ "$ARCH" = "arm64" ] && [ "$PLATFORM" = "iPhoneOS" ]; then
      HOST=aarch64-apple-darwin
    elif [ "$ARCH" = "arm64" ] && [ "$PLATFORM" = "iPhoneSimulator" ]; then
      HOST=aarch64-apple-darwin
    else
      HOST="$ARCH"-apple-darwin
    fi

    echo "HOST: $HOST"

    # Set SDKROOT dynamically based on PLATFORM
    SDKROOT=$(xcode-select -print-path)/Platforms/$PLATFORM.platform/Developer/SDKs/$PLATFORM${SDK_VERSION}.sdk

    # Validate SDKROOT
    if [ ! -d "$SDKROOT" ]; then
      echo "Error: SDKROOT does not exist: $SDKROOT"
      exit 1
    fi
    echo "*****"
    echo $SDK
    echo "SDKROOT: $SDKROOT"

    # Define compilers and flags
    CC="xcrun -sdk $SDK clang"
    CXX="xcrun -sdk $SDK clang++"

    echo "Running bootstrap for $PLATFORM $ARCH"
    SDKROOT="$SDKROOT" ../bootstrap --host="$HOST" \
                                     --disable-libav \
                                     --disable-plugin \
                                     --disable-libarchive \
                                     --enable-ffmpeg

    echo "Building contrib"
    CURRENT_DIR="$(pwd)"
    echo $CURRENT_DIR
    make fetch
    make -j"$NPROC" || exit 1

    cd "$DAEMON_DIR"

    CFLAGS="-arch $ARCH -isysroot $SDKROOT"
    CXXFLAGS="$CFLAGS -stdlib=libc++"
    LDFLAGS="-arch $ARCH -isysroot $SDKROOT -L$BUILD_DIR/lib"
    echo "Building daemon for $PLATFORM $ARCH"

    CFLAGS="-arch $ARCH -isysroot $SDKROOT"
    if [ "$PLATFORM" = "iPhoneOS" ]; then
      CFLAGS+=" -miphoneos-version-min=$MIN_IOS_VERSION -fembed-bitcode"
    else
      CFLAGS+=" -mios-simulator-version-min=$MIN_IOS_VERSION"
    fi

    if [ "$RELEASE" = "1" ]; then
      CFLAGS+=" -O3"
    fi

    CXXFLAGS="-stdlib=libc++ -std=c++17 $CFLAGS"
    LDFLAGS="$CFLAGS"

    ./autogen.sh || exit 1
    BUILD_ARCH_DIR="$DAEMON_DIR/build-$PLATFORM-$ARCH"
    mkdir -p "$BUILD_ARCH_DIR"
    cd "$BUILD_ARCH_DIR"

    JAMI_CONF="--host=$HOST \
               --without-dbus \
               --disable-plugin \
               --disable-libarchive \
               --enable-static \
               --without-natpmp \
               --disable-shared \
               --prefix=$IOS_TOP_DIR/DEPS/$PLATFORM/$ARCH"

    if [ "$RELEASE" = "0" ]; then
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

    make -j"$NPROC" || exit 1
    make install || exit 1

    rsync -ar "$DAEMON_DIR/contrib/$HOST/lib/"*.a "$IOS_TOP_DIR/DEPS/$PLATFORM/$ARCH/lib/"
    rsync -ar "$DAEMON_DIR/contrib/$HOST/include/" "$IOS_TOP_DIR/DEPS/$PLATFORM/$ARCH/include/"

    cd "$IOS_TOP_DIR"
  done
done

echo "Creating fat libraries"
LIBFILES=""
if [ -d "$IOS_TOP_DIR/DEPS/iPhoneSimulator/arm64/lib" ]; then
  LIBFILES="$IOS_TOP_DIR/DEPS/iPhoneSimulator/arm64/lib/"*.a
elif [ -d "$IOS_TOP_DIR/DEPS/iPhoneSimulator/x86_64/lib" ]; then
  LIBFILES="$IOS_TOP_DIR/DEPS/iPhoneSimulator/x86_64/lib/"*.a
elif [ -d "$IOS_TOP_DIR/DEPS/iPhoneOS/arm64/lib" ]; then
  LIBFILES="$IOS_TOP_DIR/DEPS/iPhoneOS/arm64/lib/"*.a
fi

if [ -z "$LIBFILES" ]; then
  echo "No libraries found to create fat libraries. Exiting."
  exit 1
fi

for libFile in $LIBFILES; do
  lib=$(basename "$libFile")
  echo "Processing $lib"

  lipoInputs=()
  if [ -f "$IOS_TOP_DIR/DEPS/iPhoneOS/arm64/lib/$lib" ]; then
    lipoInputs+=("$IOS_TOP_DIR/DEPS/iPhoneOS/arm64/lib/$lib")
  fi
  if [ -f "$IOS_TOP_DIR/DEPS/iPhoneSimulator/arm64/lib/$lib" ]; then
    lipoInputs+=("$IOS_TOP_DIR/DEPS/iPhoneSimulator/arm64/lib/$lib")
  fi
  if [ -f "$IOS_TOP_DIR/DEPS/iPhoneSimulator/x86_64/lib/$lib" ]; then
    lipoInputs+=("$IOS_TOP_DIR/DEPS/iPhoneSimulator/x86_64/lib/$lib")
  fi

  if [ ${#lipoInputs[@]} -eq 0 ]; then
    echo "Warning: No architectures found for $lib. Skipping."
    continue
  fi

  echo "Creating fat library for $lib"
  lipo -create "${lipoInputs[@]}" -output "$FAT_DIR/lib/$lib"
done

if [ -d "$IOS_TOP_DIR/DEPS/iPhoneOS/arm64/include/" ]; then
  rsync -ar "$IOS_TOP_DIR/DEPS/iPhoneOS/arm64/include/" "$FAT_DIR/include/"
elif [ -d "$IOS_TOP_DIR/DEPS/iPhoneSimulator/arm64/include/" ]; then
  rsync -ar "$IOS_TOP_DIR/DEPS/iPhoneSimulator/arm64/include/" "$FAT_DIR/include/"
elif [ -d "$IOS_TOP_DIR/DEPS/iPhoneSimulator/x86_64/include/" ]; then
  rsync -ar "$IOS_TOP_DIR/DEPS/iPhoneSimulator/x86_64/include/" "$FAT_DIR/include/"
else
  echo "No headers found to copy. Exiting."
  exit 1
fi
