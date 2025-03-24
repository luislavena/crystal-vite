FROM ghcr.io/luislavena/hydrofoil-crystal:1.15 AS base

# install bun
RUN --mount=type=cache,target=/var/cache/apk \
    --mount=type=tmpfs,target=/tmp \
    set -eux; \
    cd /tmp; \
    # bun
    { \
        export BUN_VERSION=1.2.5; \
        case "$(arch)" in \
        x86_64) \
            export \
                BUN_ARCH=x64 \
                BUN_SHA256=5a512ac9c5720bbfd7f154b8d6e4176733405705dcd68e600a7c111974c92a28 \
            ; \
            ;; \
        aarch64) \
            export \
                BUN_ARCH=aarch64 \
                BUN_SHA256=974aa07e67e614343fd4233d7912ca0f30bc3aa2d6217624a8fa83c40f633883 \
            ; \
            ;; \
        esac; \
        curl --fail -Lo bun.zip https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ARCH}-musl.zip; \
        echo "${BUN_SHA256} *bun.zip" | sha256sum -c - >/dev/null 2>&1; \
        unzip -j bun.zip; \
        mv bun /usr/local/bin/; \
        rm bun.zip; \
    }; \
    # smoke tests
    [ "$(command -v bun)" = '/usr/local/bin/bun' ]; \
    bun --version
