#!/bin/sh
# platforms/android/hooks/quality-gate-android.sh
# Android-specific quality gate. Invoked by hooks/quality-gate.sh when project layout is Android.

set -eu
SCOPE="${1:-all}"

GRADLE="./gradlew"
[ -x "$GRADLE" ] || { echo "no ./gradlew found in $(pwd)" >&2; exit 2; }

case "$SCOPE" in
  lint)      "$GRADLE" lintDebug ;;
  typecheck) "$GRADLE" assembleDebug ;;  # kotlinc runs during build
  test)      "$GRADLE" testDebugUnitTest ;;
  all)       "$GRADLE" lintDebug assembleDebug testDebugUnitTest ;;
  *) echo "usage: $0 <lint|typecheck|test|all>" >&2; exit 64 ;;
esac
