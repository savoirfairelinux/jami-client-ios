#!/bin/bash
EXPECTED_VERSION="SwiftGen v5.1.1 (Stencil v0.9.0, StencilSwiftKit v2.1.0, SwiftGenKit v2.1.0)"

# Here execute the various SwiftGen commands you need
run_swiftgen() {
	if [ ! "$PROJECT_DIR" -o ! $"PROJECT_NAME" ]; then echo "Some variables are not set. Please run from an Xcode build phase"; exit 1; fi
	SRCDIR="$PROJECT_DIR/$PROJECT_NAME"
	OUTDIR="$SRCDIR/Constants/Generated"
	TPLDIR=$(dirname $0)

	echo "SwiftGen: Generating files..."
	swiftgen storyboards "$SRCDIR" -t swift3 --output "$OUTDIR/Storyboards.swift"
	swiftgen xcassets "$SRCDIR/Resources/Images.xcassets" -t swift3 --output "$OUTDIR/Images.swift"
	swiftgen strings -t structured-swift3 "$SRCDIR/Resources/en.lproj/Localizable.strings" --output "$OUTDIR/Strings.swift"
}

# Main script to check if SwiftGen is installed, check the version, and run it only if version matches
if which swiftgen >/dev/null; then
	run_swiftgen
else
	echo "warning: SwiftGen not installed, download it from https://github.com/SwiftGen/SwiftGen"
fi
