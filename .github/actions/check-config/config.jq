# Prints one line per unsupported setting of a release-please configuration.
# A package setting overrides the top-level one, and false is a value.
. as $top
| (.packages // {}) as $packages
| ($packages["."] // {}) as $root
| def setting($key): if $root | has($key) then $root[$key] else $top[$key] end;
[
  (if ($packages | keys) != ["."] then "packages must contain only \".\"" else empty end),
  (if setting("include-v-in-tag") == false then "include-v-in-tag must not be false" else empty end),
  (if setting("include-component-in-tag") != false then "include-component-in-tag must be false" else empty end),
  (if setting("draft") == true then "draft releases are not supported" else empty end),
  (if setting("tag-separator") != null then "tag-separator is not supported" else empty end),
  (if (setting("label") // setting("release-label")) != null then "custom labels are not supported" else empty end)
]
| .[]
