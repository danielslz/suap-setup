#!/usr/bin/env bash
# tests/test_helper/release-fixture.bash
# Fixture de releases locais: copia o worktree para um repo git temporário, roda
# scripts/build-release.sh para v0.0.1 e v0.0.2 e monta o layout
# <REL>/download/<tag>/<asset> (usável via SUAP_SETUP_RELEASES_URL=file://<REL>).

# build_fixture_releases(dir): cria <dir>/repo e <dir>/releases
build_fixture_releases() {
    local dir="$1" tag
    mkdir -p "${dir}/repo" "${dir}/releases"
    tar -c --exclude=./.git --exclude=./tests/.cache --exclude=./.worktrees -C "${PROJECT_ROOT}" . |
        tar -x -C "${dir}/repo"
    git -C "${dir}/repo" init -q
    git -C "${dir}/repo" add -A
    git -C "${dir}/repo" -c user.name=teste -c user.email=teste@example.com commit -q -m fixture
    for tag in v0.0.1 v0.0.2; do
        bash "${dir}/repo/scripts/build-release.sh" "${tag}" --out "${dir}/releases/download/${tag}" >/dev/null
    done
}

# extract_fixture_release(dir, tag): extrai o tarball em <dir>/tree-<tag> e ecoa o caminho
extract_fixture_release() {
    local dir="$1" tag="$2"
    mkdir -p "${dir}/tree-${tag}"
    tar -xzf "${dir}/releases/download/${tag}/suap-setup-${tag}.tar.gz" -C "${dir}/tree-${tag}" --strip-components=1
    echo "${dir}/tree-${tag}"
}
