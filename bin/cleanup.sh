#!/bin/bash
# Run locally, executes inside the K8s pod, logs locally
# ./bin/cleanup.sh

# Actual deletion
# DRY_RUN=false ./bin/cleanup.sh

# Different pod
# POD=other-pod-name ./bin/cleanup.sh

# Different namespace
# NS=palni-palci-knapsack-staging ./bin/cleanup.sh

# Different age threshold (e.g., 60 days)
# AGE_DAYS=60 ./bin/cleanup.sh

# Combine multiple
# DRY_RUN=false POD=my-pod NS=my-namespace ./bin/cleanup.sh

POD="${POD:-palni-palci-knapsack-production-worker-84686dc769-4zlrt}"
NS="${NS:-palni-palci-knapsack-production}"
DRY_RUN="${DRY_RUN:-true}"
AGE_DAYS="${AGE_DAYS:-30}"
LOG="bin/cleanup_$(date +%Y%m%d_%H%M%S).log"

echo "Running cleanup on pod: $POD"
echo "Namespace: $NS"
echo "DRY_RUN: $DRY_RUN"
echo "AGE_DAYS: $AGE_DAYS"
echo "Log file: $LOG"
echo ""

kubectl exec -n "$NS" "$POD" -- bash -c "
IMPORTS_DIR=\"/app/samvera/hyrax-webapp/tmp/imports\"
AGE_DAYS=$AGE_DAYS
DRY_RUN=$DRY_RUN
TODAY=\$(date +%s)

echo \"=== Bulkrax Imports Cleanup ===\"
echo \"DRY_RUN: \$DRY_RUN\"
echo \"Started: \$(date)\"
echo \"\"

deleted_count=0
deleted_bytes=0

extract_date() {
  local name=\"\$1\"
  if [[ \"\$name\" =~ _([0-9]{4})([0-9]{2})([0-9]{2}) ]]; then
    echo \"\${BASH_REMATCH[1]}-\${BASH_REMATCH[2]}-\${BASH_REMATCH[3]}\"
  fi
}

process_dir() {
  local dir=\"\$1\"
  local name=\$(basename \"\$dir\")
  local date=\$(extract_date \"\$name\")
  [ -z \"\$date\" ] && return
  local epoch=\$(date -d \"\$date\" +%s 2>/dev/null || echo 0)
  [ \"\$epoch\" = \"0\" ] && return
  local age=\$(( (TODAY - epoch) / 86400 ))
  local size=\$(du -sh \"\$dir\" 2>/dev/null | cut -f1)
  local bytes=\$(du -sb \"\$dir\" 2>/dev/null | cut -f1)
  if [ \"\$age\" -ge \"\$AGE_DAYS\" ]; then
    echo \"DELETE: \$dir (\$size, \${age}d old)\"
    deleted_count=\$((deleted_count + 1))
    deleted_bytes=\$((deleted_bytes + bytes))
    [ \"\$DRY_RUN\" = \"false\" ] && rm -rf \"\$dir\"
  fi
}

for dir in \"\$IMPORTS_DIR\"/import_*/ \"\$IMPORTS_DIR\"/[0-9]*_[0-9]*/; do
  [ -d \"\$dir\" ] || continue
  process_dir \"\$dir\"
done

for tenant_dir in \"\$IMPORTS_DIR\"/*/; do
  [ -d \"\$tenant_dir\" ] || continue
  tenant=\$(basename \"\$tenant_dir\")
  [[ \"\$tenant\" == import_* ]] && continue
  [[ \"\$tenant\" =~ ^[0-9]+_[0-9]+ ]] && continue
  for dir in \"\$tenant_dir\"import_*/ \"\$tenant_dir\"[0-9]*_[0-9]*/; do
    [ -d \"\$dir\" ] || continue
    process_dir \"\$dir\"
  done
done

echo \"\"
echo \"=== Summary ===\"
echo \"Directories: \$deleted_count\"

if [ \"\$deleted_bytes\" -gt 1099511627776 ]; then
  echo \"Size: \$(echo \"scale=2; \$deleted_bytes / 1099511627776\" | bc) TB\"
elif [ \"\$deleted_bytes\" -gt 1073741824 ]; then
  echo \"Size: \$(echo \"scale=2; \$deleted_bytes / 1073741824\" | bc) GB\"
else
  echo \"Size: \$(echo \"scale=2; \$deleted_bytes / 1048576\" | bc) MB\"
fi

echo \"Completed: \$(date)\"
" 2>&1 | tee "$LOG"

echo ""
echo "Log saved to: $LOG"