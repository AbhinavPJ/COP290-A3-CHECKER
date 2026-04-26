set -eu
f_actual="${1:?usage: $0 <compaction_stats.txt> <golden_portable.txt>}"
f_golden="${2:?}"
if [ ! -f "$f_actual" ] || [ ! -f "$f_golden" ]; then
  echo "FAIL: missing file (actual or golden)" >&2
  exit 1
fi
t1=${TMPDIR:-/tmp}/cstat.$$.a
t2=${TMPDIR:-/tmp}/cstat.$$.b
trap 'rm -f "$t1" "$t2"' EXIT
awk -F'; ' 'NF >= 3 { gsub(/^[ \t]+|[ \t]+$/,"",$1); gsub(/^[ \t]+|[ \t]+$/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$3); print $1 "; " $2 "; " $3 }' "$f_actual" > "$t1"
awk -F'; ' 'NF >= 3 { gsub(/^[ \t]+|[ \t]+$/,"",$1); gsub(/^[ \t]+|[ \t]+$/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$3); print $1 "; " $2 "; " $3 }' "$f_golden" > "$t2"
if diff -u "$t2" "$t1"; then
  echo "OK: structural compaction fields match (bytes columns ignored for portability)"
else
  echo "FAIL: structural fields differ (see unified diff; bytes not compared)." >&2
  exit 1
fi
