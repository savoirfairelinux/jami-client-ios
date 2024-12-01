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
    ARCHS=("arm64" "x86_64")
  elif [ "$IOS_TARGET_PLATFORM" = "iPhoneSimulator" ]
  then
    ARCHS=("x86_64")
  elif [ "$IOS_TARGET_PLATFORM" = "iPhoneOS" ]
  then
    ARCHS=("arm64")
  fi
else
  ARCHS=("${HOST%%-*}")
  case "$HOST" in
    aarch64-*)
      IOS_TARGET_PLATFORM="iPhoneOS"
      ARCHS=("arm64")
    ;;
    x86_64-*)
      IOS_TARGET_PLATFORM="iPhoneSimulator"
      ARCHS=("x86_64")
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

export IOS_TARGET_PLATFORM
echo "Building for $IOS_TARGET_PLATFORM for $ARCHS"

cd "$DAEMON_DIR"

for ARCH in "${ARCHS[@]}"
do
  mkdir -p "contrib/native-$ARCH"
  cd "contrib/native-$ARCH"

  if [ "$ARCH" = "arm64" ]
  then
    HOST=aarch64-apple-darwin_ios
    IOS_TARGET_PLATFORM="iPhoneOS"
  else
    HOST="$ARCH"-apple-darwin_ios
    IOS_TARGET_PLATFORM="iPhoneSimulator"
  fi
  export IOS_TARGET_PLATFORM

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

  SDKROOT="$SDKROOT" ../bootstrap --host="$HOST" --disable-libav --disable-plugin --disable-libarchive --enable-ffmpeg

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
  mkdir -p "build-ios-$ARCH"
  cd "build-ios-$ARCH"

  JAMI_CONF="--host=$HOST \
             --without-dbus \
             --disable-plugin \
             --disable-libarchive \
             --enable-static \
             --without-natpmp \
             --disable-shared \
             --prefix=$IOS_TOP_DIR/DEPS/$ARCH"

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

  rsync -ar "$DAEMON_DIR/contrib/$HOST/lib/"*.a "$IOS_TOP_DIR/DEPS/$ARCH/lib/"
  # copy headers for extension
  rsync -ar "$DAEMON_DIR/contrib/$HOST/include/opendht" "$IOS_TOP_DIR/DEPS/$ARCH/include/"
  rsync -ar $DAEMON_DIR/contrib/$HOST/include/msgpack.hpp "$IOS_TOP_DIR/DEPS/$ARCH/include/"
  rsync -ar $DAEMON_DIR/contrib/$HOST/include/gnutls "$IOS_TOP_DIR/DEPS/$ARCH/include/"
  rsync -ar $DAEMON_DIR/contrib/$HOST/include/json "$IOS_TOP_DIR/DEPS/$ARCH/include/"
  rsync -ar $DAEMON_DIR/contrib/$HOST/include/msgpack "$IOS_TOP_DIR/DEPS/$ARCH/include/"
  rsync -ar $DAEMON_DIR/contrib/$HOST/include/yaml-cpp "$IOS_TOP_DIR/DEPS/$ARCH/include/"
  rsync -ar $DAEMON_DIR/contrib/$HOST/include/libavutil "$IOS_TOP_DIR/DEPS/$ARCH/include/"
  rsync -ar $DAEMON_DIR/contrib/$HOST/include/fmt "$IOS_TOP_DIR/DEPS/$ARCH/include/"
  cd "$IOS_TOP_DIR/DEPS/$ARCH/lib/"
  for i in *.a ; do mv "$i" "${i/-$HOST.a/.a}" ; done

  cd "$DAEMON_DIR"
done

cd "$IOS_TOP_DIR"

FAT_DIR="$IOS_TOP_DIR/fat"
mkdir -p "$FAT_DIR"

if ((${#ARCHS[@]} == "2"))
then
  mkdir -p "$FAT_DIR/lib"
  echo "Making fat lib for ${ARCHS[0]} and ${ARCHS[1]}"
  LIBFILES="$IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/"*.a
  for f in $LIBFILES
  do
    libFile=${f##*/}
    echo "Processing $libFile lib…"
    #There is only 2 ARCH max… So let's make it simple
    lipo -create  "$IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/$libFile"  \
                  "$IOS_TOP_DIR/DEPS/${ARCHS[1]}/lib/$libFile" \
                  -output "$FAT_DIR/lib/$libFile"
  done
else
  echo "No need for fat lib"
  rsync -ar --delete "$IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/"*.a "$FAT_DIR/lib"
fi

rsync -ar --delete "$IOS_TOP_DIR/DEPS/${ARCHS[0]}/include/"* "$FAT_DIR/include"
