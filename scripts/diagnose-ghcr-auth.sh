#!/bin/bash

# ============================================================================
# GHCR Authentication Diagnostic - Universal Version
# ============================================================================
# Tests GitHub Container Registry authentication for any user's namespace
# Part of Universal Container Management tooling
# ============================================================================

# Configuration - Edit these for your GitHub username/org
GHCR_USERNAME="${GHCR_USERNAME:-JayDeeAU}"
GHCR_NAMESPACE="${GHCR_NAMESPACE:-jaydeeau}"

echo "=========================================="
echo "🔍 GHCR Authentication Diagnostic"
echo "=========================================="
echo ""
echo "Testing namespace: ghcr.io/${GHCR_NAMESPACE}"
echo ""

# Check if docker is available
echo "🐳 Docker Status:"
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker is installed"
    docker --version
else
    echo "❌ Docker is not installed"
    exit 1
fi
echo ""

# Check Docker context
echo "📍 Docker Context:"
docker context show
echo ""

# Check current user
echo "👤 Current User:"
whoami
id
echo ""

# Check Docker config file
echo "🔐 Docker Config Location:"
if [ -f ~/.docker/config.json ]; then
    echo "✅ ~/.docker/config.json exists"
    echo ""
    echo "Registry authentications:"
    if command -v jq >/dev/null 2>&1; then
        cat ~/.docker/config.json | jq -r '.auths | keys[]' 2>/dev/null || echo "No registries configured"
    else
        echo "Checking for ghcr.io..."
        grep -o '"ghcr.io"' ~/.docker/config.json 2>/dev/null && echo "✅ ghcr.io found in config" || echo "❌ ghcr.io NOT found"
    fi
else
    echo "❌ ~/.docker/config.json does not exist"
fi
echo ""

# Test GHCR connectivity
echo "🌐 GHCR Connectivity Test:"
echo "Testing connection to ghcr.io..."
if curl -s -o /dev/null -w "%{http_code}" https://ghcr.io | grep -q "200\|301\|302"; then
    echo "✅ Can reach ghcr.io"
else
    echo "⚠️  Cannot reach ghcr.io (network issue?)"
fi
echo ""

# Test 1: Public GHCR image (no auth required)
echo "🔓 Test 1: Public GHCR Access"
echo "Testing with public image (ghcr.io/github/super-linter:latest)..."
if docker manifest inspect ghcr.io/github/super-linter:latest >/dev/null 2>&1; then
    echo "✅ Can access public GHCR images (connectivity OK)"
else
    echo "❌ Cannot access public GHCR images (network/Docker issue)"
fi
echo ""

# Test 2: User's namespace (requires auth if private)
echo "🔑 Test 2: Your GHCR Namespace Authentication"
echo "Testing access to: ghcr.io/${GHCR_NAMESPACE}/*"
echo "(This will test if you can access your private repositories)"
echo ""

# Try to list packages via GitHub API
echo "Attempting API package list..."
API_TEST=$(curl -s -H "Authorization: token ${GHCR_TOKEN:-}" \
    "https://api.github.com/users/${GHCR_NAMESPACE}/packages?package_type=container" 2>&1)

if echo "$API_TEST" | jq -e '.[]' >/dev/null 2>&1; then
    echo "✅ Can access namespace via API"
    echo ""
    echo "Your container packages:"
    echo "$API_TEST" | jq -r '.[].name' | head -5
    
    # Try to test one of the actual packages
    FIRST_PACKAGE=$(echo "$API_TEST" | jq -r '.[0].name' 2>/dev/null)
    if [[ -n "$FIRST_PACKAGE" && "$FIRST_PACKAGE" != "null" ]]; then
        echo ""
        echo "Testing Docker access to: ghcr.io/${GHCR_NAMESPACE}/${FIRST_PACKAGE}:latest"
        PULL_TEST=$(docker manifest inspect "ghcr.io/${GHCR_NAMESPACE}/${FIRST_PACKAGE}:latest" 2>&1)
        PULL_EXIT_CODE=$?
    else
        # Fallback: try a generic test
        echo ""
        echo "No packages found in API response, testing generic access..."
        PULL_TEST=$(docker manifest inspect "ghcr.io/${GHCR_NAMESPACE}/test:latest" 2>&1)
        PULL_EXIT_CODE=$?
    fi
else
    # Fallback: try Docker directly
    echo "⚠️  Cannot access namespace via API (may be normal)"
    echo "Testing Docker access directly..."
    PULL_TEST=$(docker manifest inspect "ghcr.io/${GHCR_NAMESPACE}/test:latest" 2>&1)
    PULL_EXIT_CODE=$?
fi
echo ""

# Evaluate Docker authentication result
if [ $PULL_EXIT_CODE -eq 0 ]; then
    echo "✅ SUCCESS - Docker authenticated to GHCR"
    echo "You can pull and push to ghcr.io/${GHCR_NAMESPACE}/*"
    echo ""
    echo "Manifest details:"
    echo "$PULL_TEST" | head -20
elif echo "$PULL_TEST" | grep -q "denied\|unauthorized\|authentication"; then
    echo "❌ AUTHENTICATION FAILED"
    echo "Docker cannot access private repositories in ghcr.io/${GHCR_NAMESPACE}"
    echo ""
    echo "Full error:"
    echo "$PULL_TEST"
    echo ""
    echo "Possible causes:"
    echo "  1. Not logged in to ghcr.io"
    echo "  2. Token expired or invalid"
    echo "  3. Token lacks read:packages permission"
elif echo "$PULL_TEST" | grep -q "not found\|no such manifest"; then
    echo "⚠️  MANIFEST NOT FOUND (but may be authenticated)"
    echo "The test image doesn't exist, but this doesn't mean auth failed"
    echo ""
    echo "To verify authentication works:"
    echo "  1. Push an actual image to your namespace"
    echo "  2. Re-run this test"
else
    echo "❓ UNKNOWN RESULT"
    echo "$PULL_TEST"
fi
echo ""

# Check local images
echo "💾 Local GHCR Images:"
docker images | grep "ghcr.io/${GHCR_NAMESPACE}" || echo "No images from ghcr.io/${GHCR_NAMESPACE} found locally"
echo ""

# Check if GitHub CLI is available and authenticated
echo "🐙 GitHub CLI Status:"
if command -v gh >/dev/null 2>&1; then
    echo "✅ GitHub CLI is installed"
    if gh auth status 2>&1 | grep -q "Logged in"; then
        echo "✅ GitHub CLI is authenticated"
        gh auth status 2>&1 | head -5
    else
        echo "❌ GitHub CLI is NOT authenticated"
    fi
else
    echo "⚠️  GitHub CLI not installed (optional)"
fi
echo ""

echo "=========================================="
echo "📋 Summary & Next Steps:"
echo "=========================================="
echo ""

if [ $PULL_EXIT_CODE -eq 0 ]; then
    echo "✅ GHCR authentication is working"
    echo ""
    echo "Your Docker daemon can access GitHub Container Registry."
    echo "You can pull and push images to ghcr.io/${GHCR_NAMESPACE}/*"
else
    echo "❌ GHCR authentication needs setup"
    echo ""
    echo "To fix:"
    echo "1. Create GitHub Personal Access Token:"
    echo "   https://github.com/settings/tokens"
    echo "   Required scopes: read:packages, write:packages"
    echo ""
    echo "2. Login to GHCR:"
    echo "   export GHCR_TOKEN='ghp_your_token_here'"
    echo "   echo \"\$GHCR_TOKEN\" | docker login ghcr.io -u ${GHCR_USERNAME} --password-stdin"
    echo ""
    echo "3. Add to your shell startup (~/.zshrc or ~/.bashrc):"
    echo "   export GHCR_TOKEN='ghp_your_token_here'"
    echo ""
    echo "4. Test again:"
    echo "   .devcontainer/scripts/diagnose-ghcr-auth.sh"
fi
echo ""

# Check if running in devcontainer
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    echo "ℹ️  Note: Running inside a container"
    echo "   Docker commands communicate with the host Docker daemon"
    echo "   Authentication must be set up on the Docker HOST, not inside this container"
fi
echo ""

echo "Configuration:"
echo "  GHCR_USERNAME: ${GHCR_USERNAME}"
echo "  GHCR_NAMESPACE: ${GHCR_NAMESPACE}"
echo "  (Override with: GHCR_USERNAME=yourname GHCR_NAMESPACE=yourname $0)"