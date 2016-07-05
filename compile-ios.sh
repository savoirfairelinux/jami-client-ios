#! /bin/sh

export BUILDFORIOS=1
MIN_IOS_VERSION=8.0
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
  if [ "$IOS_TARGET_PLATFORM" = "iPhoneSimulator" ]
  then
      ARCHS=("x86_64")
  elif [ "$IOS_TARGET_PLATFORM" = "iPhoneOS" ]
  then
      ARCHS=("arm64")
  fi
else
    ARCHS=("${HOST%%-*}")
  case "$HOST" in
    armv7-*)
        IOS_TARGET_PLATFORM="iPhoneOS"
    ;;
    aarch64-*)
        IOS_TARGET_PLATFORM="iPhoneOS"
        ARCHS=("arm64")
    ;;
    x86_64-*)
        IOS_TARGET_PLATFORM="iPhoneSimulator"
    ;;
  esac
fi

export IOS_TARGET_PLATFORM
echo "Building for $IOS_TARGET_PLATFORM for $ARCHS"

SDKROOT=`xcode-select -print-path`/Platforms/${IOS_TARGET_PLATFORM}.platform/Developer/SDKs/${IOS_TARGET_PLATFORM}${SDK_VERSION}.sdk

if [ ! `which gas-preprocessor.pl` ]
then
	echo 'gas-preprocessor.pl not found. Trying to install...'
	(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
		-o /usr/local/bin/gas-preprocessor.pl \
		&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
		|| exit 1
fi

SDK="`echo "print '${IOS_TARGET_PLATFORM}'.lower()" | python`"

CC="xcrun -sdk $SDK clang"
CXX="xcrun -sdk $SDK clang++"

IOS_TOP_DIR="$(pwd)"
DAEMON_DIR="$(pwd)/../daemon"

cd $DAEMON_DIR

# TEMPORARY (until everything is merged)
git checkout master
git fetch https://gerrit-ring.savoirfairelinux.com/ring-daemon refs/changes/27/4427/8 && git cherry-pick FETCH_HEAD
git fetch https://gerrit-ring.savoirfairelinux.com/ring-daemon refs/changes/25/4425/7 && git cherry-pick FETCH_HEAD
git fetch https://gerrit-ring.savoirfairelinux.com/ring-daemon refs/changes/63/4363/17 && git cherry-pick FETCH_HEAD
git fetch https://gerrit-ring.savoirfairelinux.com/ring-daemon refs/changes/97/4397/19 && git cherry-pick FETCH_HEAD
git fetch https://gerrit-ring.savoirfairelinux.com/ring-daemon refs/changes/33/4433/6 && git cherry-pick FETCH_HEAD

for ARCH in "${ARCHS[@]}"
do
	mkdir -p contrib/native-$ARCH
	cd contrib/native-$ARCH

    if test -z "$HOST"
    then
        if [ "$ARCH" = "arm64" ]
        then
            HOST=aarch64-apple-darwin_ios
        else
            HOST=$ARCH-apple-darwin_ios
        fi
    fi

	SDKROOT="$SDKROOT" ../bootstrap --host="$HOST" --disable-libav --enable-ffmpeg

	echo "Building contrib"
    make fetch
	make -j4 || exit 1

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

    CXXFLAGS="-std=c++11 -stdlib=libc++ $CFLAGS"
    LDFLAGS="$CFLAGS"

	./autogen.sh || exit 1
	mkdir -p "build-ios-$ARCH"
    cd build-ios-$ARCH

    RING_CONF="--host=$HOST \
			  --without-dbus \
              --enable-static \
              --disable-shared \
              --disable-video \
              --prefix=$IOS_TOP_DIR/DEPS/$ARCH"

    if [ "$RELEASE" = "0" ]
    then
        RING_CONF+=" --enable-debug"
    fi

	$DAEMON_DIR/configure $RING_CONF \
                            CC="$CC $CFLAGS" \
                            CXX="$CXX $CXXFLAGS" \
                            LD="$LD" \
                            CFLAGS="$CFLAGS" \
                            CXXFLAGS="$CXXFLAGS" \
                            LDFLAGS="$LDFLAGS" || exit 1

    # We need to copy this file or else it's just an empty file
    rsync -a $DAEMON_DIR/src/buildinfo.cpp ./src/buildinfo.cpp

    make -j4 || exit 1
    make install || exit 1

    rsync -ar $DAEMON_DIR/contrib/$HOST/lib/*.a $IOS_TOP_DIR/DEPS/$ARCH/lib/
    cd $IOS_TOP_DIR/DEPS/$ARCH/lib/
    for i in *.a ; do mv "$i" "${i/-$HOST.a/.a}" ; done

    cd $DAEMON_DIR
done

cd $IOS_TOP_DIR

FAT_DIR=$IOS_TOP_DIR/fat
mkdir -p $FAT_DIR

if ((${#ARCHS[@]} > "1"))
then
    echo "Making fat lib for $ARCHS"
    LIBFILES=$IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/*.a
    for f in $LIBFILES
    do
        echo "Processing $f lib..."
        #There is only 2 ARCH max... So let's make it simple
        lipo -create "$IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/$f"  \
        						 "$IOS_TOP_DIR/DEPS/${ARCHS[1]}/lib/$f" \
        						 -output "$FAT_DIR/lib/$f"
    done
else
    echo "No need for fat lib"
    rsync -ar --delete $IOS_TOP_DIR/DEPS/${ARCHS[0]}/lib/*.a $FAT_DIR/lib
fi

rsync -ar --delete $IOS_TOP_DIR/DEPS/${ARCHS[0]}/include/* $FAT_DIR/include
