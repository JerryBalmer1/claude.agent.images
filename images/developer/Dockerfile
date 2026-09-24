# claude.pwsh.image.developer — the observing image.
#
# Same base, same PowerShell, same sentinel script as the leash image; the only
# difference is the policy switch (Observe) and its managed settings. Build it
# from the REPOSITORY ROOT, not from this directory:
#
#   docker build -f images/developer/Dockerfile -t claude.pwsh.image.developer .
#
# The context has to be the root because there is exactly one sentinel script
# (hooks/sentinel.ps1) and one vendored Ledger, and both images copy them.
#
# Keep BASE_IMAGE / PWSH_URL / PWSH_SHA256 identical to the root Dockerfile.
# tests/Image.Tests.ps1 asserts they have not drifted.

ARG BASE_IMAGE=ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3
ARG PWSH_URL=https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/powershell-7.6.6-linux-x64.tar.gz
ARG PWSH_SHA256=ddbc4a2d113bbd46d283cfedcbcd117a70caefd7673f41f2b4e0000badf103bc

FROM ${BASE_IMAGE}

ARG PWSH_URL
ARG PWSH_SHA256
ARG PESTER_VERSION=6.1.0
ARG CLAUDE_CODE_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive

# python3 as well as the leash set: the developer image runs the Ledger snake,
# and the snake is Python.
#
# python-is-python3 is here because `python` is the name the snake is invoked under, and
# Ubuntu 24.04 ships only `python3`. F10: that one missing alias is the sole cause of every
# in-container red -- all of them inside tests/python.Tests.ps1. Measured on this image:
# 163/4 without it, 167/167 with it.
#
# The leash image deliberately gets neither this nor python at all. It never spawns the
# snake: its entrypoint verifies and its sentinel appends, and both of those are PowerShell.
# Its 11 python.Tests.ps1 reds are by design, not a gap to close here.
#
# apt retries with a bounded backoff: five attempts, sleeping 2, 8, 18 and 32 seconds between
# them, then the build fails. `--error-on=any`, because a plain `apt-get update` exits 0 when it
# cannot resolve the mirror and the failure then surfaces at install as a missing package. One
# CI run failed on DNS for archive.ubuntu.com (I12). Measured in this base with --network none:
# five attempts, 96s, exit 1. The layer is the same in both Dockerfiles but for the package list.
RUN set -eu; \
    for attempt in 1 2 3 4 5; do \
        if apt-get -o Acquire::Retries=3 update --error-on=any \
            && apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
                ca-certificates \
                curl \
                git \
                less \
                libicu74 \
                libssl3 \
                locales \
                python-is-python3 \
                python3 \
                python3-pip \
                sudo; then \
            break; \
        fi; \
        if [ "$attempt" -eq 5 ]; then echo "apt: gave up after $attempt attempts" >&2; exit 1; fi; \
        echo "apt: attempt $attempt failed, retrying in $((attempt * attempt * 2))s" >&2; \
        sleep $((attempt * attempt * 2)); \
    done; \
    rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    curl -fsSL -o /tmp/powershell.tar.gz "${PWSH_URL}"; \
    printf '%s  /tmp/powershell.tar.gz\n' "${PWSH_SHA256}" | sha256sum -c -; \
    mkdir -p /opt/microsoft/powershell/7; \
    tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7; \
    chmod +x /opt/microsoft/powershell/7/pwsh; \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; \
    rm -f /tmp/powershell.tar.gz

COPY build/InContainer.Bootstrap.ps1 /opt/leash/build/InContainer.Bootstrap.ps1
RUN pwsh -NoProfile -File /opt/leash/build/InContainer.Bootstrap.ps1 \
        -PesterVersion "${PESTER_VERSION}" -Install

# Claude Code (native installer, version pinned by ARG).
#
# Installed under /opt/claude-code, NOT into root's home. The installer follows
# $HOME, and root's home is 0700, so the default install lands somewhere the
# non-root runtime user cannot even traverse: `claude --version` then fails at
# run time with "not found" while the build looked perfectly green. The
# `claude --version` line at the end of this layer is the assertion that keeps
# that from coming back.
ENV CLAUDE_HOME=/opt/claude-code
RUN set -eu; \
    mkdir -p "${CLAUDE_HOME}"; \
    curl -fsSL https://claude.ai/install.sh -o /tmp/install-claude.sh; \
    HOME="${CLAUDE_HOME}" bash /tmp/install-claude.sh "${CLAUDE_CODE_VERSION}"; \
    rm -f /tmp/install-claude.sh; \
    ln -sf "${CLAUDE_HOME}/.local/bin/claude" /usr/local/bin/claude; \
    chown -R root:root "${CLAUDE_HOME}"; \
    chmod -R a+rX "${CLAUDE_HOME}"; \
    claude --version

ENV DISABLE_AUTOUPDATER=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

COPY images/developer/managed-settings.json /etc/claude-code/managed-settings.json
RUN chown -R root:root /etc/claude-code \
    && chmod 0555 /etc/claude-code \
    && chmod 0555 /etc/claude-code/managed-settings.json

COPY hooks/ /opt/leash/hooks/
COPY config/sentinel.json /opt/leash/config/sentinel.json
COPY src/ /opt/leash/src/
COPY entrypoint.ps1 /opt/leash/entrypoint.ps1

# Same vendored Ledger as the leash image. The developer image observes rather
# than denies, but it still writes receipts, so it still needs the snake.
# core ships modules/ledger/ledger.psd1 (lowercase); the in-container contract is
# /opt/leash/ledger/Ledger.psd1, and on Linux that difference is a hard break -- measured:
# with a plain directory COPY, Test-Path /opt/leash/ledger/Ledger.psd1 is False and
# Import-Module fails. The files are therefore copied individually under the names the
# contract already expects. RootModule is 'ledger.psm1', so only the manifest is renamed.
COPY vendor/claude.agent.core/modules/ledger/ledger.psd1 /opt/leash/ledger/Ledger.psd1
COPY vendor/claude.agent.core/modules/ledger/ledger.psm1 /opt/leash/ledger/ledger.psm1
COPY vendor/claude.agent.core/modules/ledger/python/ /opt/leash/ledger/python/

RUN chown -R root:root /opt/leash && chmod -R 0555 /opt/leash

RUN useradd -m -s /bin/bash claude
USER claude

# Same assertion, now as the user that will actually run it.
RUN claude --version

ENV LEASH_MODE=Observe
# See the note in the root Dockerfile. The developer image observes rather than denies, but it
# still has no business starting without the binary it exists to watch.
ENV LEASH_REQUIRE_CLAUDE=1
ENTRYPOINT ["pwsh", "-NoProfile", "-File", "/opt/leash/entrypoint.ps1"]
CMD ["claude"]
