# ofxLibwebsockets
* This a WIP reimplmentation of the original libwebsockets addon https://github.com/robotconscience/ofxLibwebsockets to update it to later versions of libwebsockets

* Add the power of [WebSockets](http://www.websocket.org/) to your openFrameworks project!
* openframeworks wrapper for libwebsockets (https://libwebsockets.org/) 
* implements both client and server functionality of libwebsockets
* includes support for sending text (strings) and binary data

## macOS and iOS

`libs/libwebsockets/lib/macos/libwebsockets.xcframework` is libwebsockets 4.1.5, static: macOS (arm64 + x86_64,
10.15+), iOS and iOS Simulator (iOS 15+). It uses the OpenSSL openFrameworks ships, so the addon needs nothing else.
Rebuild it (Xcode and CMake) with:

```sh
scripts/build_libwebsockets_apple.sh path/to/openFrameworks     # all slices
scripts/build_libwebsockets_apple.sh path/to/openFrameworks macos
```




## Linux libraries

libwebsockets 4.1.5, static, built with `-fPIC` (apps link as PIE, the default on current distros) against
the system's OpenSSL 3:

| Folder | For | Built on |
|---|---|---|
| `linux64` | x86_64 | Ubuntu 22.04: Ubuntu 22.04+, Debian 12+ |
| `linuxaarch64` | 64-bit ARM: Raspberry Pi OS 64-bit, ARM servers | Ubuntu 22.04 |
| `linuxarmv7l` | 32-bit Raspberry Pi OS Bookworm, Pi 2 and later | Debian Bookworm armhf |
| `linuxarmv6l` | 32-bit Raspberry Pi OS Bookworm, ARMv6 code (also Pi Zero / 1) | Debian Bookworm armhf, `-march=armv6` |

The system OpenSSL 3 (`libssl-dev`) is linked through `addon_config.mk`. Rebuild with Docker:

```sh
scripts/build_libwebsockets_linux.sh                  # all
scripts/build_libwebsockets_linux.sh arm64 armv6l     # some: amd64 arm64 armv7l armv6l
```

## Visual Studio libraries

libwebsockets 4.1.5, static, Release (`/MD`, also links into Debug builds) against openFrameworks' OpenSSL (`libs/openssl`):

| Folder | For |
|---|---|
| `vs/x64` | x86_64 |
| `vs/ARM64` | Windows on ARM, native |
| `vs/ARM64EC` | Windows on ARM, x64-compatible |

The projectGenerator picks the folder for each platform. Windows has its own `include/lws_config_vs.h`, which `include/lws_config.h` includes on `_WIN32`. Rebuild from Git Bash with Visual Studio and CMake installed, after downloading openFrameworks' libraries for each arch (`scripts/vs/download_libs.sh -a arm64` gets x64, ARM64 and ARM64EC):

```sh
scripts/build_libwebsockets_vs.sh                     # all
scripts/build_libwebsockets_vs.sh ARM64 ARM64EC       # some: x64 ARM64 ARM64EC
```

openFrameworks' OpenSSL 4 made `ASN1_STRING` opaque, so the script patches one line of libwebsockets 4.1.5 (`ASN1_STRING_get0_data`, fine on OpenSSL 3 too).