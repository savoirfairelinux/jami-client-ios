#!/bin/sh

####################################
## DOWNLOAD CARTHAGE DEPENDENCIES ##
####################################

# Bootstrap Carthage
carthage bootstrap --use-xcframeworks --platform iOS --no-use-binaries --cache-builds
