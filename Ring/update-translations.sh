#!/bin/bash

# don't fail on unknown byte sequences
export LC_CTYPE=C

tx pull -af --minimum-perc=1

if [ "$(uname)" == "Darwin" ]; then
    option="-I"
else
    option="-i"
fi

for file in `find . -name '*.strings'`; do
    # Convert file if encoding is utf-16le
    if [ `file $option $file | awk '{print $3;}'` = "charset=utf-16le" ]; then
        echo "Converting $file..."
        iconv -f UTF-16LE -t UTF-8 $file > $file.8
        cp -f $file.8 $file
        rm $file.8
    fi
done
