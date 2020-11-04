#!/bin/sh

####################################
## DOWNLOAD CARTHAGE DEPENDENCIES ##
####################################

# Bootstrap Carthage
./carthage.sh bootstrap --platform iOS --no-use-binaries --cache-builds

############################################
## DOWNLOAD WHIRLYGLOBEMAPLY DEPENDENCIES ##
############################################

cd WhirlyGlobeMaply
git submodule init
git submodule update
