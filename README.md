Telephone is a VoIP SIP softphone for Mac. It allows you to make phone
calls over the Internet or your company network. If your phone line
supports SIP protocol, you can use it on your Mac instead of a
physical phone anywhere you have a decent network connection.

## Softphone Interface

The account window hosts the new SwiftUI softphone shell. It keeps the
main workflow focused on keypad dialing, SIP MESSAGE conversations,
call history, account diagnostics, and a compact active-call panel.

The active-call panel appears only while a call is in progress and can
expand to show PJSIP media/debug stats collected from the active audio
stream.

## Building

The third-party libraries are installed into `ThirdParty/`. Those
build products are intentionally ignored by Git.

To build the dependencies for a local Apple Silicon Debug build:

    $ scripts/bootstrap-third-party.sh

Then build Telephone:

    $ xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -derivedDataPath /tmp/telephone-deriveddata CODE_SIGNING_ALLOWED=NO build

## Testing

Run the local arm64 XCTest suite:

    $ scripts/test.sh

Run an individual shared test scheme:

    $ scripts/test.sh --scheme TelephoneTests

The dependency build can also be run manually.

The commands below build arm64 static libraries for a local Apple
Silicon Debug build. For a redistributable universal build, add
`-arch x86_64` to the `CFLAGS` and `CXXFLAGS` values as needed.

### Opus

Opus codec is optional.

Download:

    $ curl -O https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz
    $ tar xzvf opus-1.3.1.tar.gz
    $ cd opus-1.3.1

Build and install:

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/Opus --disable-shared CFLAGS='-arch arm64 -Os -mmacosx-version-min=13.5'
    $ make
    $ make install

### LibreSSL

Download:

    $ curl -O https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-3.1.5.tar.gz
    $ curl -O https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-3.1.5.tar.gz.asc
    $ gpg --verify libressl-3.1.5.tar.gz.asc
    $ tar xzvf libressl-3.1.5.tar.gz
    $ cd libressl-3.1.5

Build and install:

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/LibreSSL --disable-shared CFLAGS='-arch arm64 -Os -mmacosx-version-min=13.5'
    $ make
    $ make install

### PJSIP

Download:

    $ curl -o pjproject-2.10.tar.gz https://codeload.github.com/pjsip/pjproject/tar.gz/2.10
    $ tar xzvf pjproject-2.10.tar.gz
    $ cd pjproject-2.10

Install Telephone's PJSIP configuration:

    $ cp /path/to/Telephone/ThirdParty/PJSIP/config_site.h pjlib/include/pj/config_site.h

Patch:

    $ patch -p0 -i /path/to/Telephone/ThirdParty/PJSIP/patches/sock_qos_darwin.patch
    $ patch -p0 -i /path/to/Telephone/ThirdParty/PJSIP/patches/os_core_unix.patch
    $ patch -p0 -i /path/to/Telephone/ThirdParty/PJSIP/patches/coreaudio_dev.patch

Build and install (remove `--with-opus` option if you don’t need Opus):

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/PJSIP --with-opus=/path/to/Telephone/ThirdParty/Opus --with-ssl=/path/to/Telephone/ThirdParty/LibreSSL --disable-video --disable-libyuv --disable-libwebrtc --host=arm-apple-darwin CFLAGS='-arch arm64 -Os -DNDEBUG -mmacosx-version-min=13.5' CXXFLAGS='-arch arm64 -Os -DNDEBUG -mmacosx-version-min=13.5'
    $ make dep
    $ make lib
    $ make install

Build Telephone, if you have not already:

    $ xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -derivedDataPath /tmp/telephone-deriveddata CODE_SIGNING_ALLOWED=NO build

## Contribution

For the legal reasons, pull requests are not accepted. Please feel
free to share your thoughts and ideas by commenting on the issues.
