#!/bin/bash
# Commit and push any new mirror cache pages to glossarist/iev-data-latest.
# Safe to run repeatedly — exits cleanly when there's nothing to commit.
set -euo pipefail
DEST=/Users/mulgogi/src/glossarist/iev-data-latest
cd "$DEST"
git add -A
if git diff --cached --quiet; then
  echo "no changes to commit"
  exit 0
fi
COUNT=$(git diff --cached --name-only | wc -l | tr -d ' ')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
git commit -m "Mirror progress: +${COUNT} pages (${TIMESTAMP})" > /dev/null
git push origin main > /dev/null 2>&1
echo "Pushed ${COUNT} new files at ${TIMESTAMP}"
