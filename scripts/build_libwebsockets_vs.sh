#!/usr/bin/env bash
# Rebuilds the Visual Studio libwebsockets libraries: static, Release (/MD), against
# openFrameworks' OpenSSL (libs/openssl). Run from Git Bash / MSYS2 with Visual Studio
# and CMake installed.
#
#   scripts/build_libwebsockets_vs.sh                    # all
#   scripts/build_libwebsockets_vs.sh ARM64 ARM64EC      # some
#
#   x64      -> lib/vs/x64
#   ARM64    -> lib/vs/ARM64      Windows on ARM, native
#   ARM64EC  -> lib/vs/ARM64EC    Windows on ARM, x64-compatible
#
# Needs openFrameworks' OpenSSL for each arch in libs/openssl/lib/vs/<arch>
# (scripts/vs/download_libs.sh -a arm64 gets x64, ARM64 and ARM64EC).
# OF_ROOT defaults to ../../.. from the addon; LWS_VS_GENERATOR to Visual Studio 17 2022.
#
# Windows needs its own lws_config.h: it's written to include/lws_config_vs.h, which
# include/lws_config.h includes on _WIN32. The options match the Linux libraries
# (build_libwebsockets_linux.sh). The release (/MD) C library also links into Debug (/MDd)
# apps, as OF's OpenSSL does.
set -euo pipefail

LWS_VERSION=v4.1.5
ADDON=$(cd "$(dirname "$0")/.." && pwd)
OF_ROOT=${OF_ROOT:-$(cd "$ADDON/../.." && pwd)}
GENERATOR=${LWS_VS_GENERATOR:-Visual Studio 17 2022}
INCLUDE_DIR=$ADDON/libs/libwebsockets/include
BUILD=$ADDON/build/vs

if ! command -v cmake > /dev/null; then
	echo "cmake not found (install CMake, or add Visual Studio's to PATH)" >&2; exit 1
fi

mkdir -p "$BUILD"
if [ ! -d "$BUILD/lws" ]; then
	git -c advice.detachedHead=false clone -q --depth 1 --branch $LWS_VERSION https://github.com/warmcat/libwebsockets "$BUILD/lws"
fi
# OpenSSL 4 (openFrameworks' OpenSSL) made ASN1_STRING opaque. ASN1_STRING_get0_data is
# OpenSSL 1.1.0+, so this is fine on OpenSSL 3 too.
sed -i 's/(const char \*)as->data;/(const char *)ASN1_STRING_get0_data(as);/' \
	"$BUILD/lws/lib/tls/openssl/openssl-x509.c"

for arch in ${*:-x64 ARM64 ARM64EC}; do
	case $arch in
		x64|ARM64|ARM64EC) ;;
		*) echo "unknown arch: $arch (x64, ARM64 or ARM64EC)" >&2; exit 1 ;;
	esac
	ssl=$OF_ROOT/libs/openssl/lib/vs/$arch
	if [ ! -f "$ssl/libssl.lib" ] || [ ! -f "$ssl/libcrypto.lib" ]; then
		echo "no OpenSSL for $arch in $ssl (scripts/vs/download_libs.sh -a arm64)" >&2; exit 1
	fi
	echo "libwebsockets $LWS_VERSION, $arch -> libs/libwebsockets/lib/vs/$arch"
	b=$BUILD/build-$arch
	rm -rf "$b"
	# CMAKE_INSTALL_PREFIX: fixed, ARM64EC would default to Program Files (x86) (only lws_config.h paths)
	# DISABLE_WERROR: lws 4.1 uses OpenSSL functions newer OpenSSL deprecates (but still provides)
	# CMAKE_POLICY_VERSION_MINIMUM: CMake 4 refuses lws 4.1's cmake_minimum_required (CMake 3 ignores it)
	# CMAKE_EXE_LINKER_FLAGS: lws test-links its OpenSSL feature checks (LWS_HAVE_* in lws_config.h),
	# static OpenSSL needs these system libs or every check fails. Not in LWS_OPENSSL_LIBRARIES,
	# lws makes those paths absolute.
	cmake -S "$BUILD/lws" -B "$b" -G "$GENERATOR" -A "$arch" \
		-DLWS_WITH_STATIC=ON -DLWS_WITH_SHARED=OFF -DLWS_WITH_HTTP2=ON -DLWS_IPV6=OFF \
		-DLWS_WITHOUT_TESTAPPS=ON -DLWS_WITH_MINIMAL_EXAMPLES=OFF \
		-DDISABLE_WERROR=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		-DCMAKE_INSTALL_PREFIX="C:/Program Files/libwebsockets" \
		-DLWS_OPENSSL_INCLUDE_DIRS="$(cygpath -m "$OF_ROOT/libs/openssl/include")" \
		-DLWS_OPENSSL_LIBRARIES="$(cygpath -m "$ssl/libssl.lib");$(cygpath -m "$ssl/libcrypto.lib")" \
		-DCMAKE_EXE_LINKER_FLAGS="ws2_32.lib crypt32.lib advapi32.lib user32.lib" \
		> "$b.log" || { tail -30 "$b.log"; exit 1; }
	# _CL_=-WX-: lws turns on /WX for MSVC whatever DISABLE_WERROR says; _CL_ comes after it.
	# A dash, not a slash: MSYS would turn /WX- into a path
	_CL_=-WX- cmake --build "$b" --config Release --target websockets -- -m -v:m >> "$b.log" \
		|| { grep -E 'error|Error' "$b.log" | head -30; exit 1; }
	mkdir -p "$ADDON/libs/libwebsockets/lib/vs/$arch"
	cp "$b/lib/Release/websockets_static.lib" "$ADDON/libs/libwebsockets/lib/vs/$arch/"

	# one Windows lws_config.h for every arch: the first build writes it, the rest must match
	config=$b/include/lws_config.h
	if [ ! -f "$INCLUDE_DIR/lws_config_vs.h" ]; then
		cp "$config" "$INCLUDE_DIR/lws_config_vs.h"
		echo "  wrote include/lws_config_vs.h"
	elif diff <(grep '^#define' "$INCLUDE_DIR/lws_config_vs.h" | grep -v LWS_BUILD_HASH | sort) \
		<(grep '^#define' "$config" | grep -v LWS_BUILD_HASH | sort); then
		echo "  lws_config_vs.h matches"
	else
		echo "  lws_config_vs.h differs (above)"
	fi
done
