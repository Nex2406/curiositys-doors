#!/bin/sh
# Print the deck to the PDF that gets attached to email.
#   sh docs/presentation/pdf.sh  ->  docs/presentation/build/Curiositys-Doors-Deck.pdf
#
# Gmail previews a PDF inline; it will not preview an HTML attachment, so the
# paged version is the one that actually reaches people through mail. The
# screen version is at /deck/ for anyone who gets a link instead.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
# Git Bash hands out /c/... paths; Chrome and the Windows Python both need C:/...
WIN=$HERE
if command -v cygpath >/dev/null 2>&1; then
  WIN=$(cygpath -m "$HERE")
fi
CHROME=${CHROME:-"/c/Program Files/Google/Chrome/Application/chrome.exe"}
python "$WIN/bake.py"
mkdir -p "$HERE/build"
"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --virtual-time-budget=30000 \
  --print-to-pdf="$WIN/build/Curiositys-Doors-Deck.pdf" \
  "file:///$WIN/build/curiositys-doors.html"
echo "wrote $HERE/build/Curiositys-Doors-Deck.pdf"
