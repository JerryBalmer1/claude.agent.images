# claude.pwsh.image.leash — the enforcing image.
#
# Base is pinned by digest, not by tag. mcr.microsoft.com/powershell:* is NOT
# used: the PowerShell-team MCR images were deprecated and last published
# 2025-02, so a 7.6 tag does not exist there. See prompts/assessment.2026-09-21
# .json, where the claim "mcr.microsoft.com/powershell:7.6-ubuntu-22.04 is a
# valid base" is recorded as rejected. PowerShell comes from the GitHub release
# tarball instead, with its SHA256 verified before extract.
#
# Keep BASE_IMAGE / PWSH_URL / PWSH_SHA256 identical to
# images/developer/Dockerfile. tests/Image.Tests.ps1 asserts they have not
# drifted, because "same base for the developer image" is exactly the kind of
# promise that quietly stops being true.

ARG BASE_IMAGE=ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3
ARG PWSH_URL=https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/powershell-7.6.6-linux-x64.tar.gz
ARG PWSH_SHA256=ddbc4a2d113bbd46d283cfedcbcd117a70caefd7673f41f2b4e0000badf103bc

FROM ${BASE_IMAGE}

ARG PWSH_URL
ARG PWSH_SHA256
ARG PESTER_VERSION=6.1.0
ARG CLAUDE_CODE_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive

# libicu74 and libssl3 are pwsh's runtime dependencies on 24.04. Without them
# the binary extracts cleanly and then refuses to start, which is a confusing
# failure to debug three layers later.
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
                sudo; then \
            break; \
        fi; \
        if [ "$attempt" -eq 5 ]; then echo "apt: gave up after $attempt attempts" >&2; exit 1; fi; \
        echo "apt: attempt $attempt failed, retrying in $((attempt * attempt * 2))s" >&2; \
        sleep $((attempt * attempt * 2)); \
    done; \
    rm -rf /var/lib/apt/lists/*

# PowerShell 7.6.x from the pinned tarball. Verify, then extract. Never the
# other way round.
RUN set -eu; \
    curl -fsSL -o /tmp/powershell.tar.gz "${PWSH_URL}"; \
    printf '%s  /tmp/powershell.tar.gz\n' "${PWSH_SHA256}" | sha256sum -c -; \
    mkdir -p /opt/microsoft/powershell/7; \
    tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7; \
    chmod +x /opt/microsoft/powershell/7/pwsh; \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; \
    rm -f /tmp/powershell.tar.gz

# Image-level floor, asserted at build time so a bad base fails here rather than
# in a test run an hour later. This does not change `#Requires -Version 7.4`
# anywhere: that is a language floor, this is an image floor.
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

# Managed settings: root-owned, read-only, highest precedence. 0555 on the
# directory as well as the file — a writable directory means the file can be
# replaced by unlink-and-create, which read-only on the file alone does not stop.
COPY managed-settings.json /etc/claude-code/managed-settings.json
RUN chown -R root:root /etc/claude-code \
    && chmod 0555 /etc/claude-code \
    && chmod 0555 /etc/claude-code/managed-settings.json

COPY hooks/ /opt/leash/hooks/
COPY src/ /opt/leash/src/
COPY entrypoint.ps1 /opt/leash/entrypoint.ps1

# The snake. Vendored as a git submodule and copied from the build context, so
# the image carries exactly the Ledger commit this repo pins rather than
# whatever happens to be lying around on the machine doing the build.
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

# The sentinel takes -Mode from managed-settings.json; this is the default it
# falls back to. Both say Enforce, deliberately: if one is edited the other
# still holds the line.
ENV LEASH_MODE=Enforce
# `RUN claude --version` above proves it at BUILD time. This makes the entrypoint prove it
# again at BOOT, and print the version while it is there. The two are not the same claim: a
# layer added on top of this image, or a volume mounted over /opt/claude-code, can remove a
# binary the build saw. FINDING-M8 - carried over from the shell entrypoint this replaced,
# which refused to start without claude whatever command it was handed. That file's name is
# deliberately not written here: tests/Image.Tests.ps1 scans this file's RAW text for it, and
# that guard is worth more than the convenience of naming it in a comment.
ENV LEASH_REQUIRE_CLAUDE=1
ENTRYPOINT ["pwsh", "-NoProfile", "-File", "/opt/leash/entrypoint.ps1"]
CMD ["claude"]
