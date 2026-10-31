# shellcheck shell=bash
# Lightweight and annotated tags, as the refs API answers them.

# tag TAG COMMIT: a lightweight tag.
tag() {
  local tag=$1 commit=$2
  fixture "repos/$REPO/git/ref/tags/$tag" "{\"object\":{\"type\":\"commit\",\"sha\":\"$commit\"}}"
}

# annotated_tag TAG OBJECT [COMMIT]: an annotated tag; its tag object OBJECT
# exists only when COMMIT is given.
annotated_tag() {
  local tag=$1 object=$2 commit=${3:-}
  fixture "repos/$REPO/git/ref/tags/$tag" "{\"object\":{\"type\":\"tag\",\"sha\":\"$object\"}}"
  [[ -z $commit ]] || fixture "repos/$REPO/git/tags/$object" "{\"object\":{\"sha\":\"$commit\"}}"
}
