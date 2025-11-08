FROM mcr.microsoft.com/devcontainers/rust:1-trixie

USER root

# Install needed packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install build-essential cmake ninja-build cppcheck valgrind clang lldb llvm gdb \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

ARG USERNAME=vscode