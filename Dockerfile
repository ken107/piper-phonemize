FROM debian:11.3 AS build
ARG TARGETARCH
ARG TARGETVARIANT

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV TOOLCHAIN_FILE=/wasm/modules/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    build-essential cmake ca-certificates curl pkg-config git python3 autogen automake autoconf libtool

RUN git clone --depth 1 https://github.com/emscripten-core/emsdk.git /wasm/modules/emsdk && \
    cd /wasm/modules/emsdk && \
    ./emsdk install 3.1.47 && \
    ./emsdk activate 3.1.47 && \
    sed -i -E 's/int\s+(iswalnum|iswalpha|iswblank|iswcntrl|iswgraph|iswlower|iswprint|iswpunct|iswspace|iswupper|iswxdigit)\(wint_t\)/\/\/\0/g' ./upstream/emscripten/cache/sysroot/include/wchar.h

RUN git clone --depth 1 https://github.com/rhasspy/espeak-ng.git /wasm/modules/espeak-ng && \
    cd /wasm/modules/espeak-ng && \
    ./autogen.sh && \
    ./configure && \
    make && \
    cd espeak-ng-data && \
    rm ru_dict lb_dict ar_dict

COPY ./ /wasm/modules/piper-phonemize/

RUN cd /wasm/modules/emsdk && \
    . ./emsdk_env.sh && \
    cd /wasm/modules/piper-phonemize && \
    emmake cmake -Bbuild -DCMAKE_INSTALL_PREFIX=install -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_FILE -DBUILD_TESTING=OFF -G "Unix Makefiles" -DCMAKE_CXX_FLAGS="-O3 -s INVOKE_RUN=0 -s MODULARIZE=1 -s EXPORT_NAME='createPiperPhonemize' -s EXPORTED_FUNCTIONS='[_main]' -s EXPORTED_RUNTIME_METHODS='[callMain, FS]' --preload-file /wasm/modules/espeak-ng/espeak-ng-data@/espeak-ng-data" && \
    emmake cmake --build build --config Release || true && \
    sed -i 's+$(MAKE) $(MAKESILENT) -f CMakeFiles/data.dir/build.make CMakeFiles/data.dir/build+#\0+g' /wasm/modules/piper-phonemize/build/e/src/espeak_ng_external-build/CMakeFiles/Makefile2 && \
    sed -i 's/using namespace std/\/\/\0/g' /wasm/modules/piper-phonemize/build/e/src/espeak_ng_external/src/speechPlayer/src/speechWaveGenerator.cpp && \
    emmake cmake --build build --config Release && \
    cd build && \
    tar cv piper_phonemize.js piper_phonemize.wasm piper_phonemize.data | gzip > piper-phonemize.tar.gz

# -----------------------------------------------------------------------------

FROM scratch

COPY --from=build /wasm/modules/piper-phonemize/build/piper-phonemize.tar.gz ./
