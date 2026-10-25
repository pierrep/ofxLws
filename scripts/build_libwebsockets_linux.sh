#!/usr/bin/env bash
# Rebuilds the Linux libwebsockets libraries in Docker: static, -fPIC (apps
# link as PIE, the default on current distros), against OpenSSL 3.
#
#   scripts/build_libwebsockets_linux.sh                  # all
#   scripts/build_libwebsockets_linux.sh arm64 armv6l     # some
#
#   amd64   -> lib/linux64        x86_64, Ubuntu 22.04 (links on Ubuntu 22.04+, Debian 12+)
#   arm64   -> lib/linuxaarch64   64-bit ARM: Raspberry Pi OS 64-bit, ARM servers
#   armv7l  -> lib/linuxarmv7l    32-bit Raspberry Pi OS Bookworm (Pi 2 and later)
#   armv6l  -> lib/linuxarmv6l    32-bit Raspberry Pi OS Bookworm, ARMv6 code (also Pi Zero / 1)
#
# The 32-bit ARM builds use Debian Bookworm armhf (OpenSSL 3.0, glibc 2.36, as
# Raspberry Pi OS Bookworm). The options match include/libwebsockets/lws_config.h.
# DISABLE_WERROR: lws 4.1 uses EC_KEY functions that OpenSSL 3 deprecates (but
# still provides).
set -euo pipefail

LWS_VERSION=v4.1.5
ADDON=$(cd "$(dirname "$0")/.." && pwd)

for arch in ${*:-amd64 arm64 armv7l armv6l}; do
	cflags=
	case $arch in
		amd64)  platform=linux/amd64; image=ubuntu:22.04;    dir=linux64 ;;
		arm64)  platform=linux/arm64; image=ubuntu:22.04;    dir=linuxaarch64 ;;
		armv7l) platform=linux/arm/v7; image=debian:bookworm; dir=linuxarmv7l ;;
		armv6l) platform=linux/arm/v7; image=debian:bookworm; dir=linuxarmv6l
			cflags='-march=armv6+fp -mfpu=vfp -mfloat-abi=hard -marm' ;;
		*) echo "unknown arch: $arch (amd64, arm64, armv7l or armv6l)" >&2; exit 1 ;;
	esac
	echo "libwebsockets $LWS_VERSION, $arch -> libs/libwebsockets/lib/$dir"
	docker run --rm --platform "$platform" -v "$ADDON:/addon" "$image" bash -euo pipefail -c "
		export DEBIAN_FRONTEND=noninteractive
		apt-get -o Acquire::Retries=5 update -qq && apt-get -o Acquire::Retries=5 install -y -qq git cmake g++ make libssl-dev > /dev/null
		cd /tmp && git clone -q --depth 1 --branch $LWS_VERSION https://github.com/warmcat/libwebsockets lws
		cmake -S lws -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
			-DCMAKE_C_FLAGS='$cflags' \
			-DLWS_WITH_STATIC=ON -DLWS_WITH_SHARED=OFF -DLWS_WITH_HTTP2=ON -DLWS_IPV6=OFF \
			-DLWS_WITHOUT_TESTAPPS=ON -DLWS_WITH_MINIMAL_EXAMPLES=OFF \
			-DDISABLE_WERROR=ON > /dev/null
		cmake --build build -j\$(nproc) > /dev/null
		mkdir -p /addon/libs/libwebsockets/lib/$dir
		cp build/lib/libwebsockets.a /addon/libs/libwebsockets/lib/$dir/
		diff <(grep '^#define' /addon/libs/libwebsockets/include/lws_config.h | grep -v LWS_BUILD_HASH | sort) \
			<(grep '^#define' build/include/lws_config.h | grep -v LWS_BUILD_HASH | sort) \
			&& echo '  lws_config.h matches' || echo '  lws_config.h differs (above)'
		chown -R \$(stat -c %u:%g /addon) /addon/libs/libwebsockets/lib/$dir
	"
done
