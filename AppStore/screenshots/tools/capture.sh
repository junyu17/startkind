#!/bin/bash
# Captures raw StartKind screenshots per locale from a Debug build.
# Usage: capture.sh <simUDID> <outDir> <path/to/StartKind.app>
set -u
SIM="$1"; OUT="$2"; APP="$3"
# "timer" captured last on purpose: it is the one screen that starts a real
# ActivityKit Live Activity so TimerView renders correctly, and that Live
# Activity outlives the process (simctl terminate does not end it) - if it
# were captured earlier, its Dynamic Island pill would still be showing over
# every screenshot taken after it in the same locale.
SCREENS="start stuck patterns admin settingsPrivacy timer"
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")

file_number() {
  case "$1" in
    start) echo 01;;
    timer) echo 02;;
    stuck) echo 03;;
    patterns) echo 04;;
    admin) echo 05;;
    settingsPrivacy) echo 06;;
  esac
}

boot_wait() {
  xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || { xcrun simctl boot "$SIM" >/dev/null 2>&1; xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1; }
}

for loc in ${LOCALES:-en-US zh-Hans}; do
  case "$loc" in
    en-US) L=en; R=US;;
    zh-Hans) L=zh-Hans; R=CN;;
  esac
  mkdir -p "$OUT/$loc"
  # The simulator's own language has to follow the screenshot language too,
  # or the status bar (date, carrier) stays English regardless of what the
  # app itself is showing.
  boot_wait
  xcrun simctl spawn "$SIM" defaults write -g AppleLanguages -array "$L" >/dev/null 2>&1
  xcrun simctl spawn "$SIM" defaults write -g AppleLocale -string "${L}_${R}" >/dev/null 2>&1
  xcrun simctl shutdown "$SIM" >/dev/null 2>&1
  boot_wait
  xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1
  # Fresh install per locale: -SCREENSHOT_MODE seeds real on-disk data once,
  # on the first launch after install, and the profile locale it picks up
  # that first time has to be this locale, not whatever a previous locale
  # left behind.
  xcrun simctl uninstall "$SIM" "$BUNDLE" >/dev/null 2>&1
  xcrun simctl install "$SIM" "$APP" || exit 1
  for screen in $SCREENS; do
    f="$OUT/$loc/$(file_number "$screen")_$screen.png"
    [ -f "$f" ] && continue
    xcrun simctl terminate "$SIM" "$BUNDLE" >/dev/null 2>&1
    xcrun simctl launch "$SIM" "$BUNDLE" -SCREENSHOT_MODE -SCREENSHOT_SCREEN "$screen" -SCREENSHOT_PLUS \
      -AppleLanguages "($L)" -AppleLocale "${L}_${R}" >/dev/null || exit 1
    sleep 6
    xcrun simctl io "$SIM" screenshot --type=png "$f" >/dev/null 2>&1
    echo "$loc/$screen $(python3 -c "from PIL import Image;print(Image.open('$f').size)" 2>/dev/null)"
  done
done
