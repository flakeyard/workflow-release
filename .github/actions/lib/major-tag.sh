# shellcheck shell=bash source-path=SCRIPTDIR
# The moving tag vX of a major version. Source this file; it expects REPO.

# shellcheck source=github/releases.sh
source "${BASH_SOURCE[0]%/*}/github/releases.sh"
# shellcheck source=github/tags.sh
source "${BASH_SOURCE[0]%/*}/github/tags.sh"

# major_tag_change MAJOR: print "CHANGE LATEST TARGET": what keeping vMAJOR at
# its newest release LATEST, tagged at TARGET, takes. CHANGE is create, move or
# current; none when there is no release yet, untagged when LATEST has no tag,
# or behind or diverged when vMAJOR must stay, since it only moves forward.
major_tag_change() {
  local major=$1 latest target current change
  latest=$(newest_release "$major")
  if [[ -z $latest ]]; then
    echo none
    return 0
  fi
  target=$(find_tag_commit "$latest")
  if [[ -z $target ]]; then
    echo "untagged $latest"
    return 0
  fi
  current=$(find_tag_commit "v$major")
  change=$(tag_change "$current" "$target")
  echo "$change $latest $target"
}

# tag_change CURRENT TARGET: print what moving a tag at CURRENT, or a missing
# tag when it is empty, to TARGET takes.
tag_change() {
  local current=$1 target=$2 relation
  if [[ -z $current ]]; then
    echo create
  elif [[ $current == "$target" ]]; then
    echo current
  else
    relation=$(gh api "repos/$REPO/compare/$current...$target" --jq .status)
    if [[ $relation == ahead ]]; then echo move; else echo "$relation"; fi
  fi
}
