#!/usr/bin/env bash
# Rebuilds libs/libwebsockets/lib/linux64 (x86_64) and linuxaarch64 (64-bit ARM:
# Raspberry Pi OS 64-bit, ARM servers) in Docker: static, -fPIC (apps link as
# PIE, the default on current distros), against OpenSSL 3.
#
#   scripts/build_libwebsockets_linux.sh           # both
#   scripts/build_libwebsockets_linux.sh arm64     # or amd64
#
# Built on Ubuntu 22.04 (glibc 2.35, OpenSSL 3.0), so the libraries link on
# Ubuntu 22.04+, Debian 12+ and Raspberry Pi OS Bookworm. The options match
# libs/libwebsockets/include/lws_config.h. DISABLE_WERROR: lws 4.1 uses EC_KEY
# functions that OpenSSL 3 deprecates (but still provides).
set -euo pipefail

LWS_VERSION=v4.1.5
ADDON=$(cd "$(dirname "$0")/.." && pwd)

for arch in ${*:-amd64 arm64}; do
	case $arch in
		amd64) dir=linux64 ;;
		arm64) dir=linuxaarch64 ;;
		*) echo "unknown arch: $arch (amd64 or arm64)" >&2; exit 1 ;;
	esac
	echo "libwebsockets $LWS_VERSION, linux/$arch -> libs/libwebsockets/lib/$dir"
	docker run --rm --platform "linux/$arch" -v "$ADDON:/addon" ubuntu:22.04 bash -euo pipefail -c "
		export DEBIAN_FRONTEND=noninteractive
		apt-get update -qq && apt-get install -y -qq git cmake g++ make libssl-dev > /dev/null
		cd /tmp && git clone -q --depth 1 --branch $LWS_VERSION https://github.com/warmcat/libwebsockets lws
		cmake -S lws -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
			-DLWS_WITH_STATIC=ON -DLWS_WITH_SHARED=OFF -DLWS_WITH_HTTP2=ON -DLWS_IPV6=OFF \
			-DLWS_WITHOUT_TESTAPPS=ON -DLWS_WITH_MINIMAL_EXAMPLES=OFF \
			-DDISABLE_WERROR=ON > /dev/null
		cmake --build build -j\$(nproc) > /dev/null
		mkdir -p /addon/libs/libwebsockets/lib/$dir
		cp build/lib/libwebsockets.a /addon/libs/libwebsockets/lib/$dir/
		cp build/include/lws_config.h /tmp/lws_config.$dir.h
		diff <(grep '^#define' /addon/libs/libwebsockets/include/lws_config.h | grep -v LWS_BUILD_HASH | sort) \
			<(grep '^#define' /tmp/lws_config.$dir.h | grep -v LWS_BUILD_HASH | sort) \
			&& echo '  lws_config.h matches' || echo '  lws_config.h differs (above)'
		chown -R \$(stat -c %u:%g /addon) /addon/libs/libwebsockets/lib/$dir
	"
done
