# Third-Party Notices

This file supplements `LICENSE`; it does not replace it. Include this file,
`LICENSE`, `COPYING.GPL-2.0`, `COPYING.LGPL-2.1`, and `COPYING.LibreSSL`
with source and binary distributions of SIPMan.

## SIPMan

SIPMan is licensed under the GNU General Public License version 3 or later.
See `LICENSE`.

Some first-party source files retain copyright notices from the original
Telephone project authors. Those notices are preserved in the source files.

## Linked Libraries

The macOS app currently links the following third-party static libraries from
`ThirdParty/`:

- PJSIP / pjproject 2.10: `pjsua`, `pjsip-ua`, `pjsip-simple`, `pjsip`,
  `pjmedia-codec`, `pjmedia`, `pjmedia-audiodev`, `pjnath`, `pjlib-util`,
  and `pj`.
- PJSIP-bundled media libraries: `resample`, `srtp`, `gsmcodec`, `speex`,
  and `ilbccodec`.
- LibreSSL 3.1.5: `libcrypto` and `libssl`.
- Opus 1.3.1: `libopus`.

The PJSIP install directory also contains libraries that SIPMan does not link
today, including `g7221codec`, `pjsua2`, and `pjmedia-videodev`. Do not treat
those as cleared for redistribution merely because they are present in a local
build directory.

## PJSIP / pjproject 2.10

PJSIP is dual-licensed. SIPMan uses it under the open-source GPL path:
GPL-2.0-or-later. SIPMan itself is GPL-3.0-or-later, so the combined app is
distributed under GPL-3.0-or-later. See `COPYING.GPL-2.0` and `LICENSE`.

Copyright notices observed in the vendored headers include:

- Copyright (C) 2008-2013 Teluu Inc.
- Copyright (C) 2003-2008 Benny Prijono

SIPMan builds pjproject with the configuration documented in `README.md`.
PJSIP bundles or links further third-party code. The components relevant to the
current SIPMan build are listed below.

### PJSIP-bundled resample

The current build links `libresample-arm-apple-darwin.a`. PJSIP documents this
as High Quality Sample Rate Conversion from
`https://ccrma.stanford.edu/~jos/resample/`, licensed under LGPL-2.1. See
`COPYING.LGPL-2.1`.

### PJSIP-bundled libSRTP

SIPMan links PJSIP's bundled libSRTP.

Copyright (c) 2001-2017 Cisco Systems, Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- Neither the name of the Cisco Systems, Inc. nor the names of its contributors
  may be used to endorse or promote products derived from this software without
  specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

### PJSIP-bundled Speex

SIPMan links PJSIP's bundled Speex library.

Copyright 2002-2008 Xiph.org Foundation
Copyright 2002-2008 Jean-Marc Valin
Copyright 2005-2007 Analog Devices Inc.
Copyright 2005-2008 Commonwealth Scientific and Industrial Research
Organisation (CSIRO)
Copyright 1993, 2002, 2006 David Rowe
Copyright 2003 EpicGames
Copyright 1992-1994 Jutta Degener, Carsten Bormann

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- Neither the name of the Xiph.org Foundation nor the names of its contributors
  may be used to endorse or promote products derived from this software without
  specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

### PJSIP-bundled GSM 06.10

SIPMan links PJSIP's bundled GSM codec library.

Copyright 1992, 1993, 1994 by Jutta Degener and Carsten Bormann,
Technische Universitaet Berlin

Any use of this software is permitted provided that this notice is not removed
and that neither the authors nor the Technische Universitaet Berlin are deemed
to have made any representations as to the suitability of this software for any
purpose nor are held responsible for any defects of this software. THERE IS
ABSOLUTELY NO WARRANTY FOR THIS SOFTWARE.

As a matter of courtesy, the authors request to be informed about uses this
software has found, about bugs in this software, and about any improvements
that may be of general interest.

Berlin, 28.11.1994
Jutta Degener
Carsten Bormann

### PJSIP-bundled iLBC

SIPMan currently links `libilbccodec-arm-apple-darwin.a`. In pjproject 2.10,
the bundled iLBC source files carry:

Copyright (C) The Internet Society (2004). All Rights Reserved.

Before distributing binaries, either verify the exact iLBC source/license terms
for the pjproject version being shipped, or rebuild PJSIP with
`PJMEDIA_HAS_ILBC_CODEC` set to `0` and remove `-lilbccodec-arm-apple-darwin`
from the app link flags.

### PJSIP-bundled G.722.1/C

PJSIP documents G.722.1/C as separately licensed by Poly/Polycom. SIPMan's
current PJSIP config has `PJMEDIA_HAS_G7221_CODEC` disabled and the app does
not link `libg7221codec-arm-apple-darwin.a`. Do not enable or link this codec
without confirming distribution rights.

## LibreSSL 3.1.5

SIPMan links `libcrypto.a` and `libssl.a` from LibreSSL 3.1.5.

LibreSSL files are retained under the copyright of their authors. New additions
are ISC licensed as per OpenBSD's normal licensing policy, or placed in the
public domain. LibreSSL also contains OpenSSL-derived code under the original
OpenSSL and SSLeay license terms. See `COPYING.LibreSSL`.

Required acknowledgements from the LibreSSL/OpenSSL license texts:

This product includes software developed by the OpenSSL Project for use in the
OpenSSL Toolkit (http://www.openssl.org/).

This product includes cryptographic software written by Eric Young
(eay@cryptsoft.com).

This product includes software written by Tim Hudson (tjh@cryptsoft.com).

## Opus 1.3.1

SIPMan links Opus 1.3.1.

Copyright 2001-2011 Xiph.Org, Skype Limited, Octasic, Jean-Marc Valin,
Timothy B. Terriberry, CSIRO, Gregory Maxwell, Mark Borgerding, Erik de Castro
Lopo

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- Neither the name of Internet Society, IETF or IETF Trust, nor the names of
  specific contributors, may be used to endorse or promote products derived
  from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Opus is subject to royalty-free patent licenses specified at:

- Xiph.Org Foundation: https://datatracker.ietf.org/ipr/1524/
- Microsoft Corporation: https://datatracker.ietf.org/ipr/1914/
- Broadcom Corporation: https://datatracker.ietf.org/ipr/1526/

## Distribution Checklist

- Include `LICENSE`, `COPYING.GPL-2.0`, `COPYING.LGPL-2.1`,
  `COPYING.LibreSSL`, and this file in source and binary distributions.
- Provide the complete corresponding source for SIPMan and the statically
  linked GPL/LGPL components, including scripts/configuration needed to rebuild
  the shipped object code.
- Keep PJSIP's G.722.1/C codec disabled unless separate licensing is confirmed.
- Revisit this file whenever PJSIP, LibreSSL, Opus, or codec build flags change.
