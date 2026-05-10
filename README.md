# SIPMan

SIPMan is a native macOS SIP softphone for engineers who need a small,
practical tool for testing and operating SIP systems in the field.

It is designed around the workflows that come up during SIP deployment,
support, and troubleshooting: registering an account, placing and
receiving calls, sending SIP MESSAGE traffic, reviewing recent calls, and
checking live diagnostics from the PJSIP stack while a call is active.

## Who It Is For

SIPMan is primarily aimed at:

- Field engineers testing PBX, SBC, carrier, or hosted SIP platforms.
- VoIP support teams reproducing customer call and registration issues.
- Developers working on SIP infrastructure who need a focused desktop
  endpoint.
- Lab users who want a simple Mac softphone with useful diagnostics
  close at hand.

It is not trying to be a consumer collaboration app. The interface should
stay compact, calm, and task-focused so it can sit beside packet captures,
server logs, and monitoring tools during live investigations.

## What It Does

- Registers a SIP account from the macOS app.
- Places outbound calls from a keypad-first interface.
- Handles active calls in the main window with DTMF, mute, duration, and
  hang-up controls.
- Tracks recent inbound, outbound, and missed calls.
- Provides a SIP MESSAGE data model and conversation UI foundation.
- Surfaces account diagnostics, in-call media statistics, and a rolling
  live SIP log from PJSIP.
- Stores SIP credentials in the macOS Keychain.

## Interface Overview

The main window is a single compact shell:

- **Keypad** is the default workflow for entering numbers and starting
  calls.
- **Messages** is the future SIP MESSAGE conversation area.
- **History** shows recent call activity with basic direction filters.
- **Settings** contains account configuration, diagnostics, and the live
  SIP log.

During a call, SIPMan keeps the call controls in the main keypad area so
the user can send DTMF tones and hang up without managing a second call
window.

## Repository Layout

- `Telephone/` contains the macOS app source.
- `Domain/`, `UseCases/`, and related test targets contain shared model
  and behavior code.
- `ThirdParty/` contains tracked configuration and patches for locally
  built dependencies. Built third-party products are ignored by Git.
- `scripts/` contains repeatable build, bootstrap, and test helpers.
- `THIRD_PARTY_NOTICES.md` documents linked third-party libraries and
  redistribution notes.

## Building

The third-party libraries are installed into `ThirdParty/`. Those build
products are intentionally ignored by Git.

To build the dependencies for a local Apple Silicon Debug build:

    $ scripts/bootstrap-third-party.sh

Then build SIPMan:

    $ scripts/build-app.sh

To build and launch the app:

    $ scripts/build-app.sh --open

SIPMan stores SIP passwords in Keychain. For interactive smoke testing,
use a signed Debug build so macOS sees a stable app identity. If this
script reports that no valid signing identity is available, create a Mac
Development or Apple Development certificate in Xcode. Unsigned builds
are still available for compile checks:

    $ scripts/build-app.sh --unsigned

Unsigned builds are intentionally not the default because launching
rebuilt ad-hoc binaries can make macOS ask for Keychain access again.

## Testing

Run the local arm64 XCTest suite:

    $ scripts/test.sh

Run an individual shared test scheme:

    $ scripts/test.sh --scheme TelephoneTests

## Contributing and Security

SIPMan is still early-stage, but contributions are welcome when they keep the
project focused on field SIP testing and diagnostics.

- See `CONTRIBUTING.md` for setup, testing, bug reports, and pull request
  expectations.
- See `CODE_OF_CONDUCT.md` for community behavior expectations.
- See `SECURITY.md` for private vulnerability reporting and sensitive log
  handling.
- See `CHANGELOG.md` for completed changes.

## Licensing

SIPMan is GPL-3.0-or-later. See `LICENSE`.

Third-party dependency notices are maintained in
`THIRD_PARTY_NOTICES.md`. Source and binary distributions should include
that file along with `COPYING.GPL-2.0`, `COPYING.LGPL-2.1`, and
`COPYING.LibreSSL`.

## Manual Dependency Build Reference

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

    $ ./configure --prefix=/path/to/SIPMan/ThirdParty/Opus --disable-shared CFLAGS='-arch arm64 -Os -mmacosx-version-min=13.5'
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

    $ ./configure --prefix=/path/to/SIPMan/ThirdParty/LibreSSL --disable-shared CFLAGS='-arch arm64 -Os -mmacosx-version-min=13.5'
    $ make
    $ make install

### PJSIP

Download:

    $ curl -o pjproject-2.10.tar.gz https://codeload.github.com/pjsip/pjproject/tar.gz/2.10
    $ tar xzvf pjproject-2.10.tar.gz
    $ cd pjproject-2.10

Install SIPMan's PJSIP configuration:

    $ cp /path/to/SIPMan/ThirdParty/PJSIP/config_site.h pjlib/include/pj/config_site.h

Patch:

    $ patch -p0 -i /path/to/SIPMan/ThirdParty/PJSIP/patches/sock_qos_darwin.patch
    $ patch -p0 -i /path/to/SIPMan/ThirdParty/PJSIP/patches/os_core_unix.patch
    $ patch -p0 -i /path/to/SIPMan/ThirdParty/PJSIP/patches/coreaudio_dev.patch

Build and install. Remove `--with-opus` if Opus is not required:

    $ ./configure --prefix=/path/to/SIPMan/ThirdParty/PJSIP --with-opus=/path/to/SIPMan/ThirdParty/Opus --with-ssl=/path/to/SIPMan/ThirdParty/LibreSSL --disable-video --disable-libyuv --disable-libwebrtc --host=arm-apple-darwin CFLAGS='-arch arm64 -Os -DNDEBUG -mmacosx-version-min=13.5' CXXFLAGS='-arch arm64 -Os -DNDEBUG -mmacosx-version-min=13.5'
    $ make dep
    $ make lib
    $ make install

Build SIPMan, if you have not already:

    $ scripts/build-app.sh

## Maintenance Notes

Keep `CHANGELOG.md` updated with completed changes. When app/runtime
behavior changes, bump `CURRENT_PROJECT_VERSION` in the Xcode project.
Documentation-only changes do not normally require a build number bump.
