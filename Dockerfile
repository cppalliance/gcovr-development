# Dockerfile for gcovr-development
# Builds Boost.JSON with coverage and generates production .info files
#
# Usage:
#   docker build -t gcovr-dev .
#   docker run -v $(pwd)/output:/output gcovr-dev

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc-13 \
    g++-13 \
    git \
    wget \
    curl \
    python3 \
    python3-pip \
    python3-venv \
    libcapture-tiny-perl \
    libdatetime-perl \
    libjson-xs-perl \
    && rm -rf /var/lib/apt/lists/*

# Set gcc-13 as default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100 \
    && update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-13 100

# Install lcov v2.3
WORKDIR /tmp
RUN git clone --depth 1 -b v2.3 https://github.com/linux-test-project/lcov.git \
    && cd lcov && make install && cd .. && rm -rf lcov

# Set up Python venv with gcovr 8.3
RUN python3 -m venv /opt/gcovr-venv
ENV PATH="/opt/gcovr-venv/bin:$PATH"
RUN pip install --upgrade pip && pip install gcovr==8.4

# Create workspace
WORKDIR /workspace

# Environment variables for boost-ci
ENV SELF=json
ENV B2_TOOLSET=gcc-13
ENV B2_COMPILER=gcc-13
ENV B2_CXXSTD=11
ENV GCOV=gcov-13
ENV LCOV_VERSION=v2.3
ENV LCOV_BRANCH_COVERAGE=1
ENV LCOV_OPTIONS="--rc branch_coverage=1 --ignore-errors inconsistent,mismatch,unused"

# Copy the entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Output directory for coverage files
RUN mkdir -p /output

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
