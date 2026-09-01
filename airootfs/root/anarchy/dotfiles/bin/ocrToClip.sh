#!/bin/bash

# 1. Select a region and save it to a temp file
SCR_TEMP="/tmp/ocr_snapshot.png"
maim -s "$SCR_TEMP"

# 2. Check if the user cancelled the selection
if [ ! -f "$SCR_TEMP" ]; then
    exit 1
fi

# 3. Use Tesseract to extract text and pipe it to xclip
# Greenclip monitors xclip, so it will pick this up automatically
tesseract "$SCR_TEMP" stdout -l eng | xclip -selection clipboard

# 4. Clean up
rm "$SCR_TEMP"

# Optional: Send a notification to let you know it's done
notify-send "OCR Complete" "Text copied to greenclip"
