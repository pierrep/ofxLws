# ofxLibwebsockets
* This a WIP reimplmentation of the original libwebsockets addon https://github.com/robotconscience/ofxLibwebsockets to update it to later versions of libwebsockets

* Add the power of [WebSockets](http://www.websocket.org/) to your openFrameworks project!
* openframeworks wrapper for libwebsockets (https://libwebsockets.org/) 
* implements both client and server functionality of libwebsockets
* includes support for sending text (strings) and binary data




## Linux libraries

`libs/libwebsockets/lib/linux64` (x86_64) and `linuxaarch64` (64-bit ARM: Raspberry Pi OS 64-bit, ARM
servers) are libwebsockets 4.1.5, static, built with `-fPIC` (so apps link as PIE, the default on current
distros) against OpenSSL 3, on Ubuntu 22.04: they link on Ubuntu 22.04+, Debian 12+ and Raspberry Pi OS
Bookworm. Rebuild them with Docker:

```sh
scripts/build_libwebsockets_linux.sh           # both
scripts/build_libwebsockets_linux.sh arm64     # or amd64
```
