#!/bin/sh

####################################
## DOWNLOAD CARTHAGE DEPENDENCIES ##
####################################

# Bootstrap Carthage
carthage update --use-xcframeworks --platform iOS --no-use-binaries --cache-builds
