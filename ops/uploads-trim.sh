#!/bin/sh
# Trim stale data on the shared uploads volume. Unset/0 days = skip that target.
# env: FILE_CACHE_DIR FILE_CACHE_DAYS | IMPORTS_DIR IMPORTS_DAYS | EXPORTS_DIR EXPORTS_DAYS | DRY_RUN (default true) | P (default 8)
set -eu
dry=${DRY_RUN:-true}
par=${P:-8}

# Expired Rails FileStore entries: old files, then empty dirs.
trim_cache() {
  [ -d "$1" ] || { echo "skip: $1 missing"; return 0; }
  (
    cd "$1"
    if [ "$dry" = true ]; then
      find . -type f -mtime +"$2" | wc -l | xargs echo "file_cache files older than $2 days:"
    else
      ls -A | xargs -P "$par" -I{} find {} -depth \( -type f -mtime +"$2" -o -type d -empty \) -delete
    fi
  )
}

# Bulkrax layout: <dir>/<account>/<run>. Delete a run only if nothing inside it changed within the window.
trim_runs() {
  [ -d "$1" ] || { echo "skip: $1 missing"; return 0; }
  find "$1" -mindepth 2 -maxdepth 2 -exec sh -c '
    days=$1; dry=$2; shift 2
    for u; do
      [ -z "$(find "$u" -mtime -"$days" -print -quit)" ] || continue
      if [ "$dry" = true ]; then echo "would delete $u"; else rm -rf -- "$u" && echo "deleted $u"; fi
    done' _ "$2" "$dry" {} +
}

days_ok() { [ -n "${1:-}" ] && [ "$1" -gt 0 ] 2>/dev/null; }

days_ok "${FILE_CACHE_DAYS:-}" && trim_cache "${FILE_CACHE_DIR:?}" "$FILE_CACHE_DAYS"
days_ok "${EXPORTS_DAYS:-}" && trim_runs "${EXPORTS_DIR:?}" "$EXPORTS_DAYS"
days_ok "${IMPORTS_DAYS:-}" && trim_runs "${IMPORTS_DIR:?}" "$IMPORTS_DAYS"
echo "done dry_run=$dry $(date -u +%FT%TZ)"
