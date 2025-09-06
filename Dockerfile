FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        build-essential \
        flex \
        bison \
        libssl-dev \
        libelf-dev \
        bc \
        curl \
        xz-utils \
        cpio \
        python3 \
        gcc \
        make \
        libc6-dev \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python

WORKDIR /linux-kernel