# Jami iOS

This repository is for the porting of Jami to iOS.

## Requirements

- MacOS version 12 or higher
- XCode version 13 or higher
- Homebrew (instructions could be found on https://brew.sh)
- Carthage (``brew install carthage``)

## Buil instructions

Supported archs are: arm64
Minimum supported version is: 14.5

- clone the project

```git clone https://review.jami.net/jami-project```

- init repositories

```cd jami-project && ./build.py --init```

- install dependencies

```./build.py --dependencies --distribution IOS```

- build daemon and contributions

```cd client-ios && ./compile-ios.sh --platform=iPhoneOS```

- build client dependencies

```cd Ring && ./fetch-dependencies.sh```

## Update translations

Update translations using the Transifex:

```
   cd Ring
   tx push -s
   ./update-translations.sh
```
