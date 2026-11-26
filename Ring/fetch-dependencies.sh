#!/bin/sh

####################################
## DOWNLOAD CARTHAGE DEPENDENCIES ##
####################################

xcconfig=$(mktemp -t carthage-xcconfig)
trap 'rm -f "$xcconfig"' EXIT
echo "IPHONEOS_DEPLOYMENT_TARGET = 15.0" > "$xcconfig"

# Bootstrap Carthage
XCODE_XCCONFIG_FILE="$xcconfig" carthage bootstrap --use-xcframeworks --platform iOS --no-use-binaries --cache-builds
