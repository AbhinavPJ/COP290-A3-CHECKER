set -eu
file="${1:-compaction_stats.txt}"
if [ ! -f "$file" ]; then
  echo "FAIL: $file is missing. Run the checker from this directory (logging uses cwd)." >&2
  exit 1
fi

line_no=0
while IFS= read -r line || [ -n "$line" ]; do
  line_no=$((line_no + 1))
  if [ -z "$line" ]; then
    echo "FAIL: $file line $line_no: empty line" >&2
    exit 1
  fi
  if ! echo "$line" | grep -qE '^[0-9]+; [0-9]+; [0-9]+; [0-9]+; [0-9]+$'; then
    echo "FAIL: $file line $line_no: does not match expected pattern: $line" >&2
    exit 1
  fi
done < "$file"

n=$(wc -l < "$file" | tr -d ' ')
echo "OK: $file — $n line(s), each with 5 numeric fields (strong check compares only the first 3 for portability)."
