#!/bin/bash
set -euo pipefail

# verify.sh — ARWarp public release verification
# Usage: ./scripts/verify.sh [build|test|all]

MODE="${1:-all}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

failures=0

run_check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        log_pass "$label"
    else
        log_fail "$label"
        ((failures++)) || true
    fi
}

# ---- Project structure checks ----

check_project_files() {
    echo ""
    echo "=== Project structure checks ==="
    run_check "project.yml exists" test -f project.yml
    run_check "LICENSE exists" test -f LICENSE
    run_check "README.md exists" test -f README.md
    run_check "CONTRIBUTING.md exists" test -f CONTRIBUTING.md
    run_check "SECURITY.md exists" test -f SECURITY.md
    run_check "CHANGELOG.md exists" test -f CHANGELOG.md
    run_check "ROADMAP.md exists" test -f ROADMAP.md
    run_check "Sources/ exists" test -d Sources
    run_check "Tests/ exists" test -d Tests
    run_check "Resources/ exists" test -d Resources
    run_check ".github/ exists" test -d .github
    run_check "CI workflow exists" test -f .github/workflows/ci.yml
    run_check "Issue template exists" test -f .github/ISSUE_TEMPLATE/bug_report.md
    run_check "PR template exists" test -f .github/PULL_REQUEST_TEMPLATE.md
    echo ""
}

# ---- Private file absence checks ----

check_no_private_files() {
    echo "=== Private file absence checks ==="
    run_check ".serena/ absent" test ! -d .serena
    run_check "PROJECT_AUDIT.md absent" test ! -f PROJECT_AUDIT.md
    run_check "PROJECT_STATUS.md absent" test ! -f PROJECT_STATUS.md
    run_check "PROJECT_CLEANUP_SUMMARY.md absent" test ! -f PROJECT_CLEANUP_SUMMARY.md
    run_check "NEXT_STEPS.md absent" test ! -f NEXT_STEPS.md
    run_check ".commandcode/ absent" test ! -d .commandcode
    run_check "AI_CONTEXT.md absent" test ! -f AI_CONTEXT.md
    run_check ".git/absent (clean export)" test ! -d .git
    run_check ".env absent" test ! -f .env
    echo ""
}

# ---- Secret scan ----

scan_secrets() {
    echo "=== Secret pattern scan ==="
    local patterns=(
        "api_key"
        "api[-_]?secret"
        "access[-_]?key"
        "OPENAI_API_KEY"
        "DEVELOPMENT_TEAM"
        "private[-_]?key"
        "secret[-_]?token"
        "client[-_]?secret"
        "authorization.*Bearer"
    )
    local found=0
    for pattern in "${patterns[@]}"; do
        if grep -rIn --exclude-dir=.git --exclude-dir=DerivedData --exclude-dir=build --exclude-dir=.github --exclude="verify.sh" --exclude="SECURITY.md" "$pattern" . 2>/dev/null; then
            found=1
        fi
    done
    if [ "$found" -eq 0 ]; then
        log_pass "No secret patterns found in source files"
    else
        log_fail "Secret patterns found (see above)"
        ((failures++)) || true
    fi
    echo ""
}

# ---- Build ----

do_build() {
    echo "=== xcodegen generate ==="
    if xcodegen generate --spec project.yml; then
        log_pass "xcodegen generate"
    else
        log_fail "xcodegen generate"
        ((failures++)) || true
        return
    fi
    echo ""
    echo "=== xcodebuild build (simulator) ==="
    if xcodebuild -project ARWarp.xcodeproj \
        -scheme ARWarp \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        build 2>&1; then
        log_pass "xcodebuild build"
    else
        log_fail "xcodebuild build"
        ((failures++)) || true
    fi
    echo ""
}

# ---- Test ----

do_test() {
    echo "=== xcodebuild test (simulator) ==="
    if xcodebuild -project ARWarp.xcodeproj \
        -scheme ARWarp \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        test 2>&1; then
        log_pass "xcodebuild test"
    else
        log_fail "xcodebuild test (simulator may not be bootable)"
        ((failures++)) || true
    fi
    echo ""
}

# ---- Main ----

case "$MODE" in
    build)
        check_project_files
        check_no_private_files
        scan_secrets
        do_build
        ;;
    test)
        do_test
        ;;
    all)
        check_project_files
        check_no_private_files
        scan_secrets
        do_build
        do_test
        ;;
    *)
        echo "Usage: $0 [build|test|all]"
        exit 1
        ;;
esac

echo "=== Summary ==="
if [ "$failures" -eq 0 ]; then
    log_pass "All checks passed"
else
    log_fail "$failures check(s) failed"
    exit 1
fi
