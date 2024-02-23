FROM debian:bullseye-slim

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH=/app/lib

WORKDIR /app

COPY dist/piper-phonemize_amd64.tar.gz /app/

RUN tar -xzf piper-phonemize_amd64.tar.gz && \
    rm piper-phonemize_amd64.tar.gz && \
    mv piper_phonemize/* ./ && \
    rmdir piper_phonemize

CMD /app/bin/piper_phonemize
