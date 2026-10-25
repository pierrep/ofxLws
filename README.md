# ofxLibwebsockets
* This a WIP reimplmentation of the original libwebsockets addon https://github.com/robotconscience/ofxLibwebsockets to update it to later versions of libwebsockets

* Add the power of [WebSockets](http://www.websocket.org/) to your openFrameworks project!
* openframeworks wrapper for libwebsockets (https://libwebsockets.org/) 
* implements both client and server functionality of libwebsockets
* includes support for sending text (strings) and binary data




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
