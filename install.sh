#!/bin/bash
set -e

echo "Downloading Klok..."
curl -L "https://github.com/adityavverma/klok/releases/latest/download/Klok.dmg" -o /tmp/Klok.dmg

echo "Installing..."
MOUNT_POINT=$(hdiutil attach /tmp/Klok.dmg -nobrowse -quiet | tail -n1 | awk '{print $NF}')
cp -r "$MOUNT_POINT/Klok.app" /Applications/
xattr -cr /Applications/Klok.app
hdiutil detach "$MOUNT_POINT" -quiet
rm /tmp/Klok.dmg

echo "Done! Launching Klok..."
open /Applications/Klok.app
