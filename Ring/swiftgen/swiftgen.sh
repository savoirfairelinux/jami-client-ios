#!/bin/bash
EXPECTED_VERSION="SwiftGen v4.2.1 (Stencil v0.9.0, StencilSwiftKit v1.0.2, SwiftGenKit v1.1.0)"

# Here execute the various SwiftGen commands you need
run_swiftgen() {
	if [ ! "$PROJECT_DIR" -o ! $"PROJECT_NAME" ]; then echo "Some variables are not set. Please run from an Xcode build phase"; exit 1; fi
	SRCDIR="$PROJECT_DIR/$PROJECT_NAME"
	OUTDIR="$SRCDIR/Constants/Generated"
	TPLDIR=$(dirname $0)

	echo "SwiftGen: Generating files..."
	swiftgen storyboards "$SRCDIR" -p "$TPLDIR/storyboards.stencil" --output "$OUTDIR/Storyboards.swift"
	swiftgen images "$SRCDIR/Resources/Images.xcassets" -p "$TPLDIR/images.stencil" --output "$OUTDIR/Images.swift"
	swiftgen strings "$SRCDIR/Resources/en.lproj/Localizable.strings" -p "$TPLDIR/strings.stencil" --output "$OUTDIR/Strings.swift"
}



# Main script to check if SwiftGen is installed, check the version, and run it only if version matches
if which swiftgen >/dev/null; then
	CURRENT_VERSION=`swiftgen --version`
	if [ "$CURRENT_VERSION" != "$EXPECTED_VERSION" ]; then
		echo "error: SwiftGen version mismatch (expected ${EXPECTED_VERSION%% \(*\)}, got ${CURRENT_VERSION%% \(*\)})"
		exit 1
	fi

	run_swiftgen
else
	echo "warning: SwiftGen not installed, download it from https://github.com/SwiftGen/SwiftGen"
fi
