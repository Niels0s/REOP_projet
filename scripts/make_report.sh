#!/usr/bin/env bash
# Build the Markdown report into PDF using pandoc + LaTeX
# Requires: pandoc and a TeX engine (pdflatex/xelatex)

set -euo pipefail

MD="$(dirname "$0")/../docs/report.md"
OUT="$(dirname "$0")/../docs/report.pdf"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc is not installed. Install it (brew install pandoc) or use your package manager." >&2
  exit 1
fi

if ! command -v xelatex >/dev/null 2>&1 && ! command -v pdflatex >/dev/null 2>&1; then
  echo "No LaTeX engine found (pdflatex/xelatex). Install BasicTeX/MacTeX or texlive." >&2
  exit 1
fi

echo "Building PDF from $MD -> $OUT"
pandoc "$MD" -o "$OUT" --pdf-engine=xelatex
echo "Wrote $OUT"
