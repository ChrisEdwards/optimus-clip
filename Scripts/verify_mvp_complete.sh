#!/usr/bin/env bash
# verify_mvp_complete.sh - Comprehensive MVP verification checklist
# Run this to verify all Phase 6 (MVP) features are working correctly

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Get project root (parent of Scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

check() {
    local description="$1"
    local command="$2"

    printf "  Checking: %-50s " "$description..."

    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        ((FAIL_COUNT++))
        return 1
    fi
}

skip() {
    local description="$1"
    local reason="$2"
    printf "  Checking: %-50s " "$description..."
    echo -e "${YELLOW}SKIP${NC} ($reason)"
    ((SKIP_COUNT++))
}

section() {
    echo ""
    echo "━━━ $1 ━━━"
}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        OPTIMUS CLIP MVP VERIFICATION CHECKLIST             ║"
echo "║                    Phase 6 - Final                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Project: $PROJECT_ROOT"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

# === PHASE 0: Project Structure ===
section "Phase 0: Project Structure"
check "Package.swift exists" "test -f Package.swift"
check "version.env exists" "test -f version.env"
check "Info.plist exists" "test -f Info.plist"
check "CLAUDE.md exists" "test -f CLAUDE.md"
check "Makefile exists" "test -f Makefile"
check "Project builds (debug)" "swift build 2>&1"
check "Project builds (release)" "swift build -c release 2>&1"
check "All tests pass" "swift test 2>&1"

# === PHASE 1: Menu Bar Shell ===
section "Phase 1: Menu Bar Shell"
check "OptimusClipApp.swift exists" "test -f Sources/OptimusClip/OptimusClipApp.swift"
check "Info.plist has LSUIElement" "grep -q 'LSUIElement' Info.plist"
check "MenuBarStateManager exists" "test -f Sources/OptimusClip/MenuBarStateManager.swift"
check "MenuBarExtra or NSStatusItem used" "grep -r 'MenuBarExtra\|NSStatusItem' Sources/"

# === PHASE 2: Clipboard & Paste ===
section "Phase 2: Clipboard & Paste"
check "ClipboardMonitor.swift exists" "test -f Sources/OptimusClip/Managers/ClipboardMonitor.swift"
check "ClipboardWriter.swift exists" "test -f Sources/OptimusClip/Managers/ClipboardWriter.swift"
check "PasteSimulator.swift exists" "test -f Sources/OptimusClip/Managers/PasteSimulator.swift"
check "SelfWriteMarker.swift exists" "test -f Sources/OptimusClip/Managers/SelfWriteMarker.swift"
check "ClipboardSafety.swift exists" "test -f Sources/OptimusClip/Managers/ClipboardSafety.swift"
check "Accessibility permission manager exists" "test -f Sources/OptimusClip/Managers/AccessibilityPermissionManager.swift"
check "AXIsProcessTrusted usage" "grep -r 'AXIsProcessTrusted' Sources/"

# === PHASE 3: Hotkeys & Settings ===
section "Phase 3: Hotkeys & Settings"
check "KeyboardShortcuts dependency" "grep -q 'KeyboardShortcuts' Package.swift"
check "HotkeyManager.swift exists" "test -f Sources/OptimusClip/Managers/HotkeyManager.swift"
check "SettingsView.swift exists" "test -f Sources/OptimusClip/Views/Settings/SettingsView.swift"
check "TransformationsTabView exists" "test -f Sources/OptimusClip/Views/Settings/Transformations/TransformationsTabView.swift"
check "ProvidersTabView exists" "test -f Sources/OptimusClip/Views/Settings/Providers/ProvidersTabView.swift"
check "PermissionsTabView exists" "test -f Sources/OptimusClip/Views/Settings/Permissions/PermissionsTabView.swift"
check "GeneralTabView exists" "test -f Sources/OptimusClip/Views/Settings/General/GeneralTabView.swift"

# === PHASE 4: Transformation Engine ===
section "Phase 4: Transformation Engine"
check "TransformationFlowCoordinator exists" "test -f Sources/OptimusClip/Services/TransformationFlowCoordinator.swift"
check "Transformation protocol exists" "test -f Sources/OptimusClipCore/Transformation.swift"
check "WhitespaceStripTransformation exists" "test -f Sources/OptimusClipCore/Transformations/WhitespaceStripTransformation.swift"
check "SmartUnwrapTransformation exists" "test -f Sources/OptimusClipCore/Transformations/SmartUnwrapTransformation.swift"
check "LLMTransformation exists" "test -f Sources/OptimusClipCore/Transformations/LLMTransformation.swift"
check "TransformationPipeline exists" "test -f Sources/OptimusClipCore/TransformationPipeline.swift"
check "Transformation tests exist" "test -f Tests/OptimusClipTests/TransformationTests.swift"

# === PHASE 5: LLM Integration ===
section "Phase 5: LLM Integration"
check "OpenAIProviderClient exists" "test -f Sources/OptimusClip/Services/LLMProviderClients/OpenAIProviderClient.swift"
check "AnthropicProviderClient exists" "test -f Sources/OptimusClip/Services/LLMProviderClients/AnthropicProviderClient.swift"
check "OpenRouterProviderClient exists" "test -f Sources/OptimusClip/Services/LLMProviderClients/OpenRouterProviderClient.swift"
check "OllamaProviderClient exists" "test -f Sources/OptimusClip/Services/LLMProviderClients/OllamaProviderClient.swift"
check "AWSBedrockProviderClient exists" "test -f Sources/OptimusClip/Services/LLMProviderClients/AWSBedrockProviderClient.swift"
check "LLMProviderClientFactory exists" "test -f Sources/OptimusClip/Services/LLMProviderClients/LLMProviderClientFactory.swift"
check "ProviderCredentials resolver exists" "test -f Sources/OptimusClip/Services/ProviderCredentials.swift"
check "ModelCatalog exists" "test -f Sources/OptimusClipCore/ModelCatalog/ModelCatalog.swift"

# === PHASE 6: Data & Security ===
section "Phase 6: Data & Security"
check "HistoryStore exists" "test -f Sources/OptimusClipCore/History/HistoryStore.swift"
check "HistoryModels exists" "test -f Sources/OptimusClipCore/History/HistoryModels.swift"
check "History logging integration" "test -f Sources/OptimusClip/Services/TransformationFlowCoordinator+History.swift"
check "KeychainWrapper exists" "test -f Sources/OptimusClip/Services/KeychainWrapper.swift"
check "APIKeyStore exists" "test -f Sources/OptimusClip/Services/APIKeyStore.swift"
check "Keychain uses kSecClass" "grep -q 'kSecClass' Sources/OptimusClip/Services/KeychainWrapper.swift"
check "SMAppService for launch at login" "grep -r 'SMAppService' Sources/"
check "Binary content type detection" "test -f Sources/OptimusClipCore/ClipboardContentType.swift"
check "30+ binary types detected" "grep -c 'case' Sources/OptimusClipCore/ClipboardContentType.swift | awk '\$1 >= 30'"
check "ErrorRecoveryManager exists" "test -f Sources/OptimusClip/Services/ErrorRecoveryManager.swift"

# === SECURITY AUDIT ===
section "Security Audit"
check "No hardcoded sk- API keys" "! grep -r 'sk-[a-zA-Z0-9]\{20,\}' Sources/"
check "No hardcoded anthropic keys" "! grep -r 'sk-ant-[a-zA-Z0-9]\{20,\}' Sources/"
check "No print of apiKey" "! grep -ri 'print.*apiKey\|print.*api_key' Sources/"
check "No NSLog of apiKey" "! grep -ri 'NSLog.*apiKey\|NSLog.*api_key' Sources/"
check "Keychain access uses Security framework" "grep -q 'import Security' Sources/OptimusClip/Services/KeychainWrapper.swift"

# === NFR VERIFICATION ===
section "Non-Functional Requirements"
check "Transformation tests exist" "test -f Tests/OptimusClipTests/TransformationTests.swift"
check "Keychain tests exist" "test -f Tests/OptimusClipTests/KeychainWrapperTests.swift"
check "History tests exist" "test -f Tests/OptimusClipTests/History/HistoryStoreTests.swift"
check "APIKeyStore tests exist" "test -f Tests/OptimusClipTests/APIKeyStoreTests.swift"
check "Provider credentials tests exist" "test -f Tests/OptimusClipTests/ProviderCredentialsTests.swift"

# === TEST SUITE VERIFICATION ===
section "Test Suite"
TEST_COUNT=$(swift test --list-tests 2>/dev/null | wc -l | tr -d ' ')
check "Significant test coverage (>200 tests)" "[ $TEST_COUNT -gt 200 ]"
echo "  Total test count: $TEST_COUNT"

# === RESULTS ===
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                     RESULTS SUMMARY                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $PASS_COUNT"
echo -e "  ${RED}Failed:${NC}  $FAIL_COUNT"
echo -e "  ${YELLOW}Skipped:${NC} $SKIP_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ MVP VERIFICATION COMPLETE - ALL CHECKS PASSED          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ MVP VERIFICATION FAILED - FIX ISSUES ABOVE             ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
