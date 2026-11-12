#!/bin/sh
# Kota.app'i derler. LSUIElement: Dock'ta ve Cmd+Tab'da görünmez.
set -e
cd "$(dirname "$0")"
mkdir -p Kota.app/Contents/MacOS Kota.app/Contents/Resources
cp logos/*.svg Kota.app/Contents/Resources/
swiftc -O -swift-version 5 main.swift -o Kota.app/Contents/MacOS/Kota
cat > Kota.app/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.batuhanhaymana.kota</string>
<key>CFBundleName</key><string>Kota</string>
<key>CFBundleExecutable</key><string>Kota</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
