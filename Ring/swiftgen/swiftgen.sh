#!/bin/bash

# Here execute the various SwiftGen commands you need
run_swiftgen() {
	if [ ! "$PROJECT_DIR" -o ! $"PROJECT_NAME" ]; then echo "Some variables are not set. Please run from an Xcode build phase"; exit 1; fi
	SRCDIR="$PROJECT_DIR/$PROJECT_NAME"
	OUTDIR="$SRCDIR/Constants/Generated"
	TPLDIR=$(dirname $0)

	echo "SwiftGen: Generating files..."
	swiftgen storyboards "$SRCDIR" -t swift5 --output "$OUTDIR/Storyboards.swift"
	swiftgen xcassets "$SRCDIR/Resources/Images.xcassets" -t swift5 --output "$OUTDIR/Images.swift"
	swiftgen strings -t structured-swift5 "$SRCDIR/Resources/en.lproj/Localizable.strings" --output "$OUTDIR/Strings.swift"
}

# Main script to check if SwiftGen is installed, check the version, and run it only if version matches
if which swiftgen >/dev/null; then
	run_swiftgen
else
	echo "warning: SwiftGen not installed, download it from https://github.com/SwiftGen/SwiftGen"
fi
