# shellcheck shell=bash
# action-shell-lib at the commit that release.yaml pins, whose modules the
# scripts source and whose internal/testing the tests use. CI gives it in
# SHELL_LIB; otherwise it is fetched once into the cache. Source this file; it
# expects root, the repository's directory, and sets library.

: "${root:?}"
readonly LIBRARY_URL=https://github.com/flakeyard/action-shell-lib
# The pin in release.yaml; the commit is the first group.
readonly LIBRARY_PIN_RE='uses: flakeyard/action-shell-lib@([0-9a-f]{40})'

# pinned_library_commit: print the commit of the library that release.yaml
# pins; exits if it pins none.
pinned_library_commit() {
  local line
  while IFS= read -r line; do
    if [[ $line =~ $LIBRARY_PIN_RE ]]; then
      echo "${BASH_REMATCH[1]}"
      return 0
    fi
  done <"$root/.github/workflows/release.yaml"
  echo "tests/run.sh: release.yaml pins no action-shell-lib" >&2
  exit 2
}

# clone_commit COMMIT DIR: only COMMIT of the library, checked out in DIR.
clone_commit() {
  local commit=$1 dir=$2
  git -C "$dir" init --quiet \
    && git -C "$dir" fetch --quiet --depth 1 "$LIBRARY_URL" "$commit" \
    && git -C "$dir" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
}

# fetch_library COMMIT DIR: the library at COMMIT in DIR, unless DIR exists.
fetch_library() {
  local commit=$1 dir=$2 temp
  [[ ! -d $dir ]] || return 0
  mkdir -p -- "${dir%/*}"
  temp=$(mktemp -d "$dir.XXXXXX")
  if ! clone_commit "$commit" "$temp" || ! mv -T -- "$temp" "$dir"; then
    rm -rf -- "$temp"
    echo "tests/run.sh: cannot fetch $LIBRARY_URL at $commit" >&2
    exit 2
  fi
}

# resolve_library: set library, the directory of the library: SHELL_LIB, or
# the pinned commit in the cache.
resolve_library() {
  local commit
  if [[ -n ${SHELL_LIB-} ]]; then
    library=$SHELL_LIB
    return 0
  fi
  commit=$(pinned_library_commit) || exit 2
  library=${XDG_CACHE_HOME:-$HOME/.cache}/flakeyard/action-shell-lib/$commit
  fetch_library "$commit" "$library"
}

resolve_library
