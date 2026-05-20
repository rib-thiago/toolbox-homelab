#!/usr/bin/env bash
set -euo pipefail

cd /srv/toolbox/app

echo "===== STATUS SHORT ====="
git status --short

echo
echo "===== BRANCH ====="
git branch --show-current

echo
echo "===== LOG ====="
git log --oneline --decorate -n 15

echo
echo "===== DIFF STAT ====="
git diff --stat

echo
echo "===== UNTRACKED ====="
git ls-files --others --exclude-standard

echo
echo "===== DIFF: bin/run-job ====="
git diff -- bin/run-job || true

echo
echo "===== DIFF: bin/pdf-ocr ====="
git diff -- bin/pdf-ocr || true

echo
echo "===== DIFF: bin/image-ocr-translate ====="
git diff -- bin/image-ocr-translate || true

echo
echo "===== DIFF: bin/job-inspect ====="
git diff -- bin/job-inspect || true

echo
echo "===== DIFF: scripts/helpers/job-inspect.sh ====="
git diff -- scripts/helpers/job-inspect.sh || true

echo
echo "===== DIFF: scripts/helpers/translate.sh ====="
git diff -- scripts/helpers/translate.sh || true

echo
echo "===== DIFF: scripts/pipelines/pdf-ocr.sh ====="
git diff -- scripts/pipelines/pdf-ocr.sh || true

echo
echo "===== DIFF: scripts/pipelines/image-ocr-translate.sh ====="
git diff -- scripts/pipelines/image-ocr-translate.sh || true

echo
echo "===== DIFF: docs/man1/run-job.1 ====="
git diff -- docs/man1/run-job.1 || true

echo
echo "===== DIFF: docs/man1/translate.1 ====="
git diff -- docs/man1/translate.1 || true

echo
echo "===== DIFF: docs/man1/job-inspect.1 ====="
git diff -- docs/man1/job-inspect.1 || true

echo
echo "===== DIFF: .env.example ====="
git diff -- .env.example || true
