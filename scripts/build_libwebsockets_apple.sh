#!/usr/bin/env bash
# Builds libs/libwebsockets/lib/macos/libwebsockets.xcframework (static, the
# openFrameworks layout): macOS (arm64 + x86_64), iOS and iOS Simulator, against
# the OpenSSL openFrameworks ships (libs/openssl). tvOS isn't supported: its SDK
# has no net/route.h, which libwebsockets' socket code needs.
#
#   scripts/build_libwebsockets_apple.sh [path/to/openFrameworks] [slice...]
#     slices: macos ios ios-simulator (default: all)
#
# Needs Xcode and CMake (CMAKE_POLICY_VERSION_MINIMUM: lws 4.1 predates CMake 4).
# LWS_HAVE_PIPE2=OFF: new SDKs declare pipe2() for newer OS versions only, so
# lws' compile check passes but it's null at runtime on older ones (a crash in
# lws_create_context); pipe() works everywhere.
# The options match include/libwebsockets/lws_config.h.
set -euo pipefail

LWS_VERSION=v4.1.5
ADDON=$(cd "$(dirname "$0")/.." && pwd)
OF=$(cd "${1:-$ADDON/../..}" && pwd); shift || true
SSL=$OF/libs/openssl
[ -f "$SSL/include/openssl/ssl.h" ] || { echo "no OpenSSL in $SSL: pass the openFrameworks folder (after download_libs)" >&2; exit 1; }
SLICES=${*:-macos ios ios-simulator}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git -c advice.detachedHead=false clone -q --depth 1 --branch $LWS_VERSION https://github.com/warmcat/libwebsockets "$WORK/lws"
# openFrameworks ships OpenSSL 4, where ASN1_STRING is opaque: read it through
# ASN1_STRING_get0_data (OpenSSL 1.1+) instead of ->data
sed -i '' 's/(const char \*)as->data;/(const char *)ASN1_STRING_get0_data(as);/' "$WORK/lws/lib/tls/openssl/openssl-x509.c"
grep -q 'ASN1_STRING_get0_data(as)' "$WORK/lws/lib/tls/openssl/openssl-x509.c"

libs=()
for slice in $SLICES; do
	case $slice in
		macos)          sys=Darwin; sdk=macosx;           archs="arm64;x86_64"; min=10.15; xc=macos-arm64_x86_64 ;;
		ios)            sys=iOS;    sdk=iphoneos;         archs="arm64";        min=15.0;  xc=ios-arm64 ;;
		ios-simulator)  sys=iOS;    sdk=iphonesimulator;  archs="arm64;x86_64"; min=15.0;  xc=ios-arm64_x86_64-simulator ;;
		*) echo "unknown slice: $slice" >&2; exit 1 ;;
	esac
	echo "libwebsockets $LWS_VERSION: $slice ($archs, min $min)"
	b="$WORK/build-$slice"
	cmake -S "$WORK/lws" -B "$b" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		-DCMAKE_SYSTEM_NAME=$sys -DCMAKE_OSX_SYSROOT=$sdk -DCMAKE_OSX_ARCHITECTURES="$archs" \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=$min -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DLWS_OPENSSL_INCLUDE_DIRS="$SSL/include" \
		-DLWS_OPENSSL_LIBRARIES="$SSL/lib/macos/libssl.xcframework/$xc/libssl.a;$SSL/lib/macos/libcrypto.xcframework/$xc/libcrypto.a" \
		-DLWS_WITH_STATIC=ON -DLWS_WITH_SHARED=OFF -DLWS_WITH_HTTP2=ON -DLWS_IPV6=OFF \
		-DLWS_WITHOUT_TESTAPPS=ON -DLWS_WITH_MINIMAL_EXAMPLES=OFF -DDISABLE_WERROR=ON \
		-DLWS_HAVE_PIPE2=OFF > "$b.log" 2>&1 \
		|| { tail -20 "$b.log"; exit 1; }
	cmake --build "$b" -j"$(sysctl -n hw.ncpu)" >> "$b.log" 2>&1 || { grep -m10 "error" "$b.log"; exit 1; }
	libs+=(-library "$b/lib/libwebsockets.a")
	diff <(grep '^#define' "$ADDON/libs/libwebsockets/include/lws_config.h" | grep -v LWS_BUILD_HASH | sort) \
		<(grep '^#define' "$b/include/lws_config.h" | grep -v LWS_BUILD_HASH | sort) \
		&& echo '  lws_config.h matches' || echo '  lws_config.h differs (above)'
done

out="$ADDON/libs/libwebsockets/lib/macos/libwebsockets.xcframework"
rm -rf "$out"
mkdir -p "$(dirname "$out")"
xcodebuild -create-xcframework "${libs[@]}" -output "$out" > /dev/null
echo "-> ${out#$ADDON/}"
