#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="${APP_NAME:-SleepLock}"
SCHEME="${SCHEME:-SleepLock}"
PROJECT_PATH="${PROJECT_PATH:-SleepLock.xcodeproj}"
BUNDLE_ID="${BUNDLE_ID:-com.grigorym.SleepLock}"
TEAM_ID="${TEAM_ID:-9FP39GTDT5}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_VERSION="${APP_VERSION:-1.3.1}"
BUILD_VERSION="${BUILD_VERSION:-4}"
ENTITLEMENTS="${ENTITLEMENTS:-$PROJECT_DIR/SleepLock.entitlements}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
NOTARIZE="${NOTARIZE:-auto}"

RELEASE_DIR="${RELEASE_DIR:-$PROJECT_DIR/dist/release}"
BUILD_DIR="$RELEASE_DIR/build"
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
DMG_STAGING="$BUILD_DIR/dmg-staging"
DMG_UNSIGNED="$BUILD_DIR/$APP_NAME-unsigned.dmg"
DMG_PATH="$RELEASE_DIR/${APP_NAME}-${APP_VERSION}-${BUILD_VERSION}.dmg"
VOLUME_NAME="${VOLUME_NAME:-$APP_NAME}"

log() {
  printf '[release] %s\n' "$*"
}

fail() {
  printf '[release] ERROR: %s\n' "$*" >&2
  exit 1
}

resolve_sign_identity() {
  if [[ -n "$SIGN_IDENTITY" ]]; then
    return 0
  fi

  local identities_output
  identities_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  SIGN_IDENTITY="$(
    printf '%s\n' "$identities_output" |
      awk -F '"' -v team="($TEAM_ID)" '/Developer ID Application: / && index($2, team) { print $2; exit }'
  )"

  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(
      printf '%s\n' "$identities_output" |
        awk -F '"' '/Developer ID Application: / { print $2; exit }'
    )"
  fi

  [[ -n "$SIGN_IDENTITY" ]] || fail "Developer ID Application signing identity not found in Keychain"
}

notary_credentials_available() {
  [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]] && return 0
  [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-$TEAM_ID}" ]] && return 0
  [[ -n "${APP_STORE_CONNECT_API_KEY:-}" && -n "${APP_STORE_CONNECT_KEY_ID:-}" ]] && return 0
  return 1
}

notary_args() {
  if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
    printf '%s\0%s\0' "--keychain-profile" "$NOTARY_KEYCHAIN_PROFILE"
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    printf '%s\0%s\0%s\0%s\0%s\0%s\0' \
      "--apple-id" "$APPLE_ID" \
      "--password" "$APPLE_APP_SPECIFIC_PASSWORD" \
      "--team-id" "${APPLE_TEAM_ID:-$TEAM_ID}"
  elif [[ -n "${APP_STORE_CONNECT_API_KEY:-}" && -n "${APP_STORE_CONNECT_KEY_ID:-}" ]]; then
    printf '%s\0%s\0%s\0%s\0' \
      "--key" "$APP_STORE_CONNECT_API_KEY" \
      "--key-id" "$APP_STORE_CONNECT_KEY_ID"
    if [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
      printf '%s\0%s\0' "--issuer" "$APP_STORE_CONNECT_ISSUER_ID"
    fi
  fi
}

notarize_and_staple() {
  local should_notarize="$NOTARIZE"
  if [[ "$should_notarize" == "auto" ]]; then
    if notary_credentials_available; then
      should_notarize="1"
    else
      should_notarize="0"
    fi
  fi

  if [[ "$should_notarize" != "1" ]]; then
    log "Skipping notarization. Set NOTARIZE=1 with notary credentials to submit to Apple."
    return 0
  fi

  notary_credentials_available || fail "NOTARIZE=1 but no notary credentials were provided"

  local args=()
  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < <(notary_args)

  log "Submitting DMG to Apple notarization service"
  xcrun notarytool submit "$DMG_PATH" "${args[@]}" --wait

  log "Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
}

resolve_sign_identity
log "Using signing identity: $SIGN_IDENTITY"

rm -rf "$RELEASE_DIR"
mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

log "Cleaning extended attributes from bundled resources"
xattr -cr "$PROJECT_DIR/AppIcon.icns" "$PROJECT_DIR/Sources/SleepLock/Resources" 2>/dev/null || true

log "Building $APP_NAME.app with xcodebuild"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  MARKETING_VERSION="$APP_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_VERSION" \
  OTHER_CODE_SIGN_FLAGS="--options runtime" \
  clean build

BUILT_APP="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
[[ -d "$BUILT_APP" ]] || fail "Built app was not found: $BUILT_APP"

log "Preparing app bundle"
/usr/bin/ditto --norsrc "$BUILT_APP" "$APP_PATH"
xattr -cr "$APP_PATH" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_PATH/Contents/Info.plist"

log "Signing app bundle"
if [[ -f "$ENTITLEMENTS" ]]; then
  codesign --force --deep --strict --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_PATH"
else
  codesign --force --deep --strict --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

log "Creating DMG"
rm -rf "$DMG_STAGING" "$DMG_UNSIGNED" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
/usr/bin/ditto --norsrc "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_UNSIGNED"

log "Signing DMG"
mv "$DMG_UNSIGNED" "$DMG_PATH"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

notarize_and_staple

log "Assessing DMG with Gatekeeper"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

log "Release DMG: $DMG_PATH"
