#! /bin/sh

export BUILDFORIOS=1
export MIN_IOS_VERSION=11
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

if [ ! `which gas-preprocessor.pl` ]
then
  echo 'gas-preprocessor.pl not found. Trying to install...'
  (curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
    -o /usr/local/bin/gas-preprocessor.pl \
    && chmod +x /usr/local/bin/gas-preprocessor.pl) \
    || exit 1
fi

IOS_TOP_DIR="$(pwd)"

if [ -z "$DAEMON_DIR" ]; then
  DAEMON_DIR="$(pwd)/../daemon"
  echo "DAEMON_DIR not provided trying to find it in $DAEMON_DIR"
fi
if [ ! -d "$DAEMON_DIR" ]; then
  echo 'Daemon not found.'
  echo 'If you cloned the daemon in a custom location override' \
       'use DAEMON_DIR to point to it'
  echo "You can also use our meta repo which contains both:
        https://gerrit-ring.savoirfairelinux.com/#/admin/projects/ring-project"
  exit 1
fi

if [ -z "$NPROC"  ]; then
  NPROC=`sysctl -n hw.ncpu || echo -n 1`
fi

export IOS_TARGET_PLATFORM
echo "Building for $IOS_TARGET_PLATFORM for $ARCHS"

cd $DAEMON_DIR

for ARCH in "${ARCHS[@]}"
do
  mkdir -p contrib/native-$ARCH
  cd contrib/native-$ARCH

  if [ "$ARCH" = "arm64" ]
  then
    HOST=aarch64-apple-darwin_ios
    IOS_TARGET_PLATFORM="iPhoneOS"
  else
    HOST=$ARCH-apple-darwin_ios
    IOS_TARGET_PLATFORM="iPhoneSimulator"
  fi
  export IOS_TARGET_PLATFORM

  SDKROOT=`xcode-select -print-path`/Platforms/${IOS_TARGET_PLATFORM}.platform/Developer/SDKs/${IOS_TARGET_PLATFORM}${SDK_VERSION}.sdk

  SDK="`echo "print '${IOS_TARGET_PLATFORM}'.lower()" | python`"

  CC="xcrun -sdk $SDK clang"
  CXX="xcrun -sdk $SDK clang++"

  SDKROOT="$SDKROOT" ../bootstrap --host="$HOST" --disable-libav --enable-ffmpeg

  echo "Building contrib"
  make fetch
  make -j$NPROC || exit 1

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
  cd build-ios-$ARCH

  RING_CONF="--host=$HOST \
             --without-dbus \
             --enable-static \
             --disable-shared \
             --prefix=$IOS_TOP_DIR/DEPS/$ARCH"

  if [ "$RELEASE" = "0" ]
  then
    RING_CONF+=" --enable-debug"
  fi

  $DAEMON_DIR/configure $RING_CONF \
                        CC="$CC $CFLAGS" \
                        CXX="$CXX $CXXFLAGS" \
                        OBJCXX="$CXX $CXXFLAGS" \
                        LD="$LD" \
                        CFLAGS="$CFLAGS" \
                        CXXFLAGS="$CXXFLAGS" \
                        LDFLAGS="$LDFLAGS" || exit 1

  # We need to copy this file or else it's just an empty file
  rsync -a $DAEMON_DIR/src/buildinfo.cpp ./src/buildinfo.cpp

  make -j$NPROC || exit 1
  make install || exit 1

  rsync -ar $DAEMON_DIR/contrib/$HOST/lib/*.a $IOS_TOP_DIR/DEPS/$ARCH/lib/
  cd $IOS_TOP_DIR/DEPS/$ARCH/lib/
  for i in *.a ; do mv "$i" "${i/-$HOST.a/.a}" ; done

  cd $DAEMON_DIR
done

cd $IOS_TOP_DIR

FAT_DIR=$IOS_TOP_DIR/fat
mkdir -p $FAT_DIR

if ((${#ARCHS[@]} == "2"))
then
  mkdir -p $FAT_DIR/lib
  echo "Making fat lib for ${ARCHS[0]} and ${ARCHS[1]}"
  LIBFILES=$IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/*.a
  for f in $LIBFILES
  do
    libFile=${f##*/}
    echo "Processing $libFile lib..."
    #There is only 2 ARCH max... So let's make it simple
    lipo -create  "$IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/$libFile"  \
                  "$IOS_TOP_DIR/DEPS/${ARCHS[1]}/lib/$libFile" \
                  -output "$FAT_DIR/lib/$libFile"
  done
else
  echo "No need for fat lib"
  rsync -ar --delete $IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/*.a $FAT_DIR/lib
fi

rsync -ar --delete $IOS_TOP_DIR/DEPS/${ARCHS[0]}/include/* $FAT_DIR/include
