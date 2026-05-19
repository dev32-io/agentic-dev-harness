#!/bin/sh
# platforms/ios/hooks/quality-gate-ios.sh
# iOS-specific quality gate.

set -eu
SCOPE="${1:-all}"

SCHEME="${ADH_IOS_SCHEME:-App}"
DEST="${ADH_IOS_DEST:-platform=iOS Simulator,name=iPhone 15}"

run_lint() {
  if command -v swiftlint > /dev/null 2>&1; then
    swiftlint
  else
    echo "swiftlint not installed; skipping lint" >&2
  fi
}
run_build() { xcodebuild build -scheme "$SCHEME" -destination "$DEST" -quiet; }
run_test()  { xcodebuild test  -scheme "$SCHEME" -destination "$DEST" -quiet; }

case "$SCOPE" in
  lint)      run_lint ;;
  typecheck) run_build ;;
  test)      run_test ;;
  all)       run_lint && run_build && run_test ;;
  *) echo "usage: $0 <lint|typecheck|test|all>" >&2; exit 64 ;;
esac
