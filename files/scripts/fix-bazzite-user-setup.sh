#!/usr/bin/env bash
# Bazzite's per-user setup script has an `if` branch whose body is only a
# comment, which bash rejects at parse time, so the whole script fails on
# every login ("Failed unit: bazzite-user-setup.service") and never
# marks itself done. Upstream main still carries it as of 2026-09-05.
#
# Insert a no-op into the empty branch. If upstream fixes the script,
# the pattern stops matching and this becomes a no-op itself.
set -euo pipefail

f=/usr/libexec/bazzite-user-setup
[[ -f $f ]] || { echo "$f not present, nothing to patch"; exit 0; }

if bash -n "$f" 2>/dev/null; then
  echo "$f already parses, no patch needed"
  exit 0
fi

# The broken shape: `then`, a blank line, `else`, a comment line, `fi`.
# Both branches are empty, and bash needs a command in each.
python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
pattern = r'(if \[\[ \$BASE_IMAGE_NAME =~ "kinoite" \]\]; then)\n\n(\s*)(else\n)(\s*# gnome-extensions enable [^\n]*\n)(\s*fi)'
fixed = re.sub(pattern,
               r'\1\n\2  : # empty on purpose; bash needs a command here\n\2\3\4\2  :\n\5',
               s, count=1)
if fixed == s:
    sys.exit("pattern not found; script is broken in a new way")
open(p, "w").write(fixed)
PY

bash -n "$f" && echo "patched $f"
