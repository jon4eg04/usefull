#!/usr/bin/env bash
set -Eeuo pipefail

SUPERPOWERS_REPO="https://github.com/obra/superpowers.git"
SUPERPOWERS_REF="v6.3.0"
SUPERPOWERS_DIR="/opt/superpowers"

BOOTSTRAP_BASE_URL="https://raw.githubusercontent.com/jon4eg04/usefull/main/codex-bootstrap"
AGENTS_URL="$BOOTSTRAP_BASE_URL/AGENTS.md"
AGENTS_DIR="/etc/codex"
AGENTS_FILE="$AGENTS_DIR/AGENTS.md"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    die "run this installer as root"
fi

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v getent >/dev/null 2>&1 || die "getent is required"
command -v runuser >/dev/null 2>&1 || die "runuser is required"

if ! id dev >/dev/null 2>&1; then
    die "user 'dev' does not exist yet; create dev first, then rerun this installer"
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Git not found; installing git..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y git ca-certificates
fi

echo "=== Superpowers ==="

if [ -e "$SUPERPOWERS_DIR" ] && [ ! -d "$SUPERPOWERS_DIR/.git" ]; then
    die "$SUPERPOWERS_DIR exists but is not the expected Git repository; nothing was removed"
fi

if [ ! -e "$SUPERPOWERS_DIR" ]; then
    git clone --branch "$SUPERPOWERS_REF" --depth 1 "$SUPERPOWERS_REPO" "$SUPERPOWERS_DIR"
else
    origin_url="$(git -C "$SUPERPOWERS_DIR" remote get-url origin 2>/dev/null || true)"
    case "$origin_url" in
        "$SUPERPOWERS_REPO"|"https://github.com/obra/superpowers"|"git@github.com:obra/superpowers.git")
            ;;
        *)
            die "$SUPERPOWERS_DIR has unexpected origin: ${origin_url:-<none>}; nothing was changed"
            ;;
    esac

    if [ -n "$(git -C "$SUPERPOWERS_DIR" status --porcelain --untracked-files=all)" ]; then
        die "$SUPERPOWERS_DIR has local changes; refusing to overwrite them"
    fi

    if ! git -C "$SUPERPOWERS_DIR" rev-parse -q --verify "refs/tags/$SUPERPOWERS_REF" >/dev/null 2>&1; then
        git -C "$SUPERPOWERS_DIR" fetch --depth 1 origin "refs/tags/$SUPERPOWERS_REF:refs/tags/$SUPERPOWERS_REF"
    fi

    current_commit="$(git -C "$SUPERPOWERS_DIR" rev-parse HEAD)"
    target_commit="$(git -C "$SUPERPOWERS_DIR" rev-list -n 1 "$SUPERPOWERS_REF")"

    if [ "$current_commit" != "$target_commit" ]; then
        git -C "$SUPERPOWERS_DIR" checkout --detach "$SUPERPOWERS_REF"
    fi
fi

test -f "$SUPERPOWERS_DIR/skills/using-superpowers/SKILL.md" \
    || die "Superpowers installation is incomplete: using-superpowers/SKILL.md not found"

chown -R root:root "$SUPERPOWERS_DIR"
chmod -R go-w "$SUPERPOWERS_DIR"

echo "Superpowers ready at $SUPERPOWERS_DIR ($SUPERPOWERS_REF)"

echo
echo "=== Global AGENTS.md ==="

install -d -m 755 -o root -g root "$AGENTS_DIR"
tmp_agents="$(mktemp "$AGENTS_DIR/.AGENTS.md.XXXXXX")"
trap 'rm -f "$tmp_agents"' EXIT

curl -fsSL "$AGENTS_URL" -o "$tmp_agents"

agents_size="$(wc -c < "$tmp_agents")"
if [ "$agents_size" -lt 1000 ]; then
    die "downloaded AGENTS.md is unexpectedly small: ${agents_size} bytes"
fi

grep -Fqx '# Global Codex Working Rules' "$tmp_agents" \
    || die "downloaded AGENTS.md failed identity check"

chown root:root "$tmp_agents"
chmod 0644 "$tmp_agents"

if [ -e "$AGENTS_FILE" ] && [ ! -f "$AGENTS_FILE" ]; then
    die "$AGENTS_FILE exists but is not a regular file"
fi

mv -f "$tmp_agents" "$AGENTS_FILE"
trap - EXIT

echo "AGENTS.md ready at $AGENTS_FILE"

ensure_user_dir() {
    local user="$1"
    local path="$2"
    local mode="$3"
    local group

    group="$(id -gn "$user")"

    if [ -L "$path" ]; then
        die "$path is a symlink; expected a real directory"
    fi

    if [ -e "$path" ] && [ ! -d "$path" ]; then
        die "$path exists but is not a directory"
    fi

    if [ ! -d "$path" ]; then
        install -d -m "$mode" -o "$user" -g "$group" "$path"
    else
        chown "$user:$group" "$path"
    fi
}

ensure_managed_link() {
    local user="$1"
    local target="$2"
    local link="$3"
    local group current

    group="$(id -gn "$user")"

    if [ -L "$link" ]; then
        current="$(readlink "$link")"
        if [ "$current" != "$target" ]; then
            ln -sfnT "$target" "$link"
        fi
    elif [ -e "$link" ]; then
        die "$link already exists and is not a symlink; refusing to remove it"
    else
        ln -s "$target" "$link"
    fi

    chown -h "$user:$group" "$link"
}

setup_user() {
    local user="$1"
    local home

    home="$(getent passwd "$user" | cut -d: -f6)"
    [ -n "$home" ] || die "cannot determine home for user $user"
    [ -d "$home" ] || die "home directory does not exist for user $user: $home"

    ensure_user_dir "$user" "$home/.agents" 700
    ensure_user_dir "$user" "$home/.agents/skills" 700
    ensure_user_dir "$user" "$home/.codex" 700

    ensure_managed_link "$user" "$SUPERPOWERS_DIR/skills" "$home/.agents/skills/superpowers"
    ensure_managed_link "$user" "$AGENTS_FILE" "$home/.codex/AGENTS.md"

    echo "$user links ready"
}

echo
echo "=== User links ==="
setup_user root
setup_user dev

echo
echo "=== Verification ==="

verify_user() {
    local user="$1"
    local home skills_link agents_link

    home="$(getent passwd "$user" | cut -d: -f6)"
    skills_link="$home/.agents/skills/superpowers"
    agents_link="$home/.codex/AGENTS.md"

    [ "$(readlink -f "$skills_link")" = "$SUPERPOWERS_DIR/skills" ] \
        || die "$user Superpowers symlink resolves incorrectly"

    [ "$(readlink -f "$agents_link")" = "$AGENTS_FILE" ] \
        || die "$user AGENTS.md symlink resolves incorrectly"

    runuser -u "$user" -- test -r "$skills_link/using-superpowers/SKILL.md" \
        || die "$user cannot read Superpowers"

    runuser -u "$user" -- test -r "$agents_link" \
        || die "$user cannot read AGENTS.md"

    echo "$user: OK"
}

verify_user root
verify_user dev

superpowers_commit="$(git -C "$SUPERPOWERS_DIR" rev-parse --short=12 HEAD)"
agents_sha256="$(sha256sum "$AGENTS_FILE" | awk '{print $1}')"

echo
echo "=== CODEX ENVIRONMENT READY ==="
echo "Superpowers ref:    $SUPERPOWERS_REF"
echo "Superpowers commit: $superpowers_commit"
echo "AGENTS.md SHA256:   $agents_sha256"
echo
echo "root: OK"
echo "dev:  OK"
echo
echo "Reload VS Code / start a new Codex chat."
