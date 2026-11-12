# Prints one line per unsupported setting of a release-please configuration.
# A package setting overrides the top-level one, and false is a value.
. as $top
| (.packages // {}) as $packages
| ($packages["."] // {}) as $root
| def setting($key): if $root | has($key) then $root[$key] else $top[$key] end;
def unsupported($keys): $keys[] | select(setting(.) != null) | "\(.) is not supported";
[
  (if ($packages | keys) != ["."] then "packages must contain only \".\"" else empty end),
  (if setting("include-v-in-tag") == false then "include-v-in-tag must not be false" else empty end),
  (if setting("include-component-in-tag") != false then "include-component-in-tag must be false" else empty end),
  (if setting("draft") == true then "draft releases are not supported" else empty end),
  (if setting("skip-github-release") == true then "skip-github-release is not supported" else empty end),
  (if setting("separate-pull-requests") == true then "separate-pull-requests is not supported" else empty end),
  unsupported([
    "tag-separator", "label", "release-label", "component",
    "pull-request-title-pattern", "group-pull-request-title-pattern",
    "versioning", "prerelease-type"
  ])
]
| .[]
