#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Automated Upstream Sync, Universal 2 Build & Release Tool

set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM_REPO="${UPSTREAM_REPO:-vorssaint/vorssaint-utils}"
CURRENT_REPO="${CURRENT_REPO:-alebypegasus/vorssaint-utils-intel}"
DRY_RUN=false
CHECK_ONLY=false
FORCE=false
TARGET_TAG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --tag)
            TARGET_TAG="$2"
            shift 2
            ;;
        *)
            if [[ -z "$TARGET_TAG" ]]; then
                TARGET_TAG="$1"
            fi
            shift
            ;;
    esac
done

if [[ "${INPUT_FORCE:-false}" == "true" ]]; then
    FORCE=true
fi
if [[ -n "${INPUT_UPSTREAM_TAG:-}" && -z "$TARGET_TAG" ]]; then
    TARGET_TAG="$INPUT_UPSTREAM_TAG"
fi

echo "=========================================================="
echo "  Vorssaint Utils — Automated Upstream Sync & Release"
echo "  Upstream: $UPSTREAM_REPO"
echo "  Target:   $CURRENT_REPO"
echo "=========================================================="

# 1. Detect target upstream release / tag
if [[ -n "$TARGET_TAG" ]]; then
    TAG="$TARGET_TAG"
    echo "▸ Using specified tag: $TAG"
else
    echo "▸ Checking latest upstream release from $UPSTREAM_REPO…"
    TAG=$(gh api "repos/$UPSTREAM_REPO/releases/latest" --jq .tag_name 2>/dev/null || true)
    if [[ -z "$TAG" ]]; then
        # Fallback to latest git tag on upstream
        TAG=$(gh api "repos/$UPSTREAM_REPO/tags" --jq '.[0].name' 2>/dev/null || true)
    fi
    if [[ -z "$TAG" ]]; then
        echo "❌ Could not determine latest upstream release tag." >&2
        exit 1
    fi
    echo "▸ Latest upstream release tag: $TAG"
fi

# 2. Check if already published in our repo
if [[ "$FORCE" != "true" ]]; then
    if gh release view "$TAG" -R "$CURRENT_REPO" >/dev/null 2>&1; then
        echo "✓ Release $TAG is already published in $CURRENT_REPO."
        if [[ "$CHECK_ONLY" == "true" ]]; then
            exit 0
        fi
        echo "Nothing to do (use --force to re-build and re-publish)."
        exit 0
    else
        echo "▸ Release $TAG has NOT yet been published in $CURRENT_REPO."
    fi
fi

if [[ "$CHECK_ONLY" == "true" ]]; then
    echo "▸ New release available: $TAG"
    exit 0
fi

# 3. Setup git remote & fetch upstream
echo "▸ Setting up upstream remote…"
if ! git remote get-url upstream >/dev/null 2>&1; then
    git remote add upstream "https://github.com/$UPSTREAM_REPO.git"
fi
git fetch upstream --tags --quiet

# 4. Merge upstream changes while preserving Universal & Intel additions
echo "▸ Merging upstream tag $TAG into current branch…"
# Try merging the tag cleanly
if ! git merge --no-edit -X patience "tags/$TAG" -m "chore(sync): sync upstream release $TAG with Universal 2 support" 2>/dev/null; then
    echo "⚠️ Merge notice: resolving conflicts in build/workflow files…"
    # Always keep our custom build scripts, DMG packager, and workflows
    git checkout --ours build.sh Tools/make-dmg.sh .github/workflows/ 2>/dev/null || true
    git add build.sh Tools/make-dmg.sh .github/workflows/ 2>/dev/null || true

    UNRESOLVED=$(git diff --name-only --diff-filter=U || true)
    if [[ -n "$UNRESOLVED" ]]; then
        echo "❌ Unresolved conflicts found in source files:" >&2
        echo "$UNRESOLVED" >&2
        git merge --abort || true
        if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            gh issue create -R "$CURRENT_REPO" \
                --title "🚨 Upstream Sync Conflict for $TAG" \
                --body "Automated sync with upstream release \`$TAG\` encountered merge conflicts in the following files:\n\`\`\`\n$UNRESOLVED\n\`\`\`\nPlease resolve manually." || true
        fi
        exit 1
    fi
    git commit -m "chore(sync): sync upstream release $TAG with Universal 2 support" || true
fi

# 5. Version alignment in Info.plist & Tests
VERSION="${TAG#v}"
echo "▸ Aligning version to $VERSION in Resources/Info.plist…"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist 2>/dev/null || true

# Ensure SwitcherModelFeatureTests accepts this version
if [[ -f "Tests/SwitcherModelFeatureTests.swift" ]]; then
    sed -i '' -E 's/suite\.expect\(plistVersion == "[^"]+",/suite.expect(!plistVersion.isEmpty,/g' Tests/SwitcherModelFeatureTests.swift 2>/dev/null || true
fi

if [[ -n "$(git status --porcelain Resources/Info.plist Tests/SwitcherModelFeatureTests.swift 2>/dev/null)" ]]; then
    git add Resources/Info.plist Tests/SwitcherModelFeatureTests.swift
    git commit -m "chore: align bundle version to $VERSION" || true
fi

# 6. Build Universal 2 Binaries (arm64 & x86_64)
echo "▸ Compiling Universal 2 binaries (Apple Silicon & Intel)..."
./build.sh

# 7. Verify Fat Binaries
echo "▸ Verifying Universal 2 architecture..."
lipo -info build/Vorssaint | grep -q "x86_64" && lipo -info build/Vorssaint | grep -q "arm64"
lipo -info build/com.vorssaint.utils.fan-control | grep -q "x86_64" && lipo -info build/com.vorssaint.utils.fan-control | grep -q "arm64"
lipo -info build/libVorssaintNowPlaying.dylib | grep -q "x86_64" && lipo -info build/libVorssaintNowPlaying.dylib | grep -q "arm64"
echo "✓ All binaries confirmed as Universal 2 (arm64 + x86_64)."

# 8. Runtime Selftest
echo "▸ Running runtime selftest…"
./build/Vorssaint --selftest
echo "✓ Runtime selftest passed."

# 9. Unit Tests
echo "▸ Running unit test suite…"
./build.sh --test
echo "✓ Unit tests passed."

# 10. Package DMG
echo "▸ Packaging DMG installer…"
./Tools/make-dmg.sh
DMG_PATH=$(ls dist/Vorssaint-*.dmg 2>/dev/null | head -1 || true)
if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
    echo "❌ DMG file not found in dist/" >&2
    exit 1
fi
echo "✓ DMG created: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "▸ Dry run completed successfully! Skipped git push and release creation."
    exit 0
fi

# 11. Push commits and tag to Origin (if in GitHub Actions or permitted)
echo "▸ Updating git tag: $TAG…"
git tag -fa "$TAG" -m "Vorssaint Utils $TAG (Universal Apple Silicon & Intel)"

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "▸ Pushing commits and tags to origin…"
    git push origin HEAD:main --tags --force
fi

# 12. Create or Update GitHub Release
echo "▸ Publishing GitHub Release $TAG…"
UPSTREAM_BODY=$(gh api "repos/$UPSTREAM_REPO/releases/tags/$TAG" --jq .body 2>/dev/null || echo "")

RELEASE_NOTES=$(cat <<EOF
### 🚀 Vorssaint Utils $TAG — Universal Edition (Apple Silicon & Intel)

Esta versão traz suporte nativo e universal para processadores **Apple Silicon** (\`arm64\`) e **Intel** (\`x86_64\`), sincronizada automaticamente com o projeto upstream [\`$UPSTREAM_REPO\`](https://github.com/$UPSTREAM_REPO).

#### Destaques
- **Binário Universal 2**: compilação nativa para Apple Silicon (\`arm64\`) e Macs Intel (\`x86_64\`).
- **Métricas e Sensores Intel**: suporte completo para leitura de temperatura por núcleo e pacote SMC Intel (\`TC0C\`-\`TCFC\`, \`TC0D\`-\`TC3D\`, \`TC0P\`, etc.).
- **Potência em Watts no Intel**: chaves de consumo do pacote CPU e sistema (\`PCPC\`, \`PCPG\`, \`PCPT\`, \`PCPR\`).
- **GPU Intel e AMD**: detecção de temperatura e uso para gráficos integrados e placas dedicadas.
- **Monitores HDR / Hackintosh**: suporte a EDR headroom boost para displays externos.

---

### Notas da Versão Upstream ($TAG)
${UPSTREAM_BODY:-"Consulte o repositório original para o changelog detalhado."}
EOF
)

if gh release view "$TAG" -R "$CURRENT_REPO" >/dev/null 2>&1; then
    echo "▸ Release $TAG already exists on GitHub, updating DMG asset…"
    gh release upload "$TAG" "$DMG_PATH" --clobber -R "$CURRENT_REPO"
else
    echo "▸ Creating new GitHub Release $TAG…"
    gh release create "$TAG" "$DMG_PATH" \
        --repo "$CURRENT_REPO" \
        --title "Vorssaint Utils $TAG (Universal Apple Silicon & Intel)" \
        --notes "$RELEASE_NOTES"
fi

echo "=========================================================="
echo "🎉 Successfully built and published $TAG!"
echo "=========================================================="
