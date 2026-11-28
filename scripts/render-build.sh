#!/usr/bin/env bash
set -euo pipefail

# Keep this version aligned with .github/workflows/flutter.yml.
readonly FLUTTER_VERSION="3.44.4"
readonly sdk_directory="${RENDER_CACHE_DIR:-${TMPDIR:-/tmp}}/concilio-flutter-${FLUTTER_VERSION}"

: "${SUPABASE_URL:?Configure SUPABASE_URL in Render.}"
: "${SUPABASE_PUBLISHABLE_KEY:?Configure the public Supabase key in Render.}"

if [[ "$SUPABASE_URL" != https://* ]]; then
  echo "SUPABASE_URL must use HTTPS." >&2
  exit 1
fi
if [[ "$SUPABASE_PUBLISHABLE_KEY" != sb_publishable_?* ]]; then
  # Render's native build environment includes Python. Validate legacy JWT
  # claims locally without printing the key or passing it as a command argument.
  if ! python3 - <<'PY'
import base64
import json
import os
import sys

try:
    parts = os.environ["SUPABASE_PUBLISHABLE_KEY"].split(".")
    if len(parts) != 3 or any(not part for part in parts):
        raise ValueError("Invalid JWT")
    encoded_payload = parts[1] + "=" * (-len(parts[1]) % 4)
    payload = json.loads(base64.urlsafe_b64decode(encoded_payload))
    valid = isinstance(payload, dict) and payload.get("role") == "anon"
except (KeyError, ValueError, TypeError, UnicodeError):
    valid = False
sys.exit(0 if valid else 1)
PY
  then
    echo "Use a Supabase publishable key or a legacy anon key; privileged keys are rejected." >&2
    exit 1
  fi
fi

if [[ ! -x "$sdk_directory/bin/flutter" ]]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$sdk_directory"
fi

export PATH="$sdk_directory/bin:$PATH"
export CI=true
flutter --suppress-analytics --version
flutter --suppress-analytics precache --web
flutter --suppress-analytics pub get --enforce-lockfile
flutter --suppress-analytics build web --release --no-pub \
  --no-web-resources-cdn \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY"

# The signed APK is built separately; signing material never goes to Render.
: "${APK_DOWNLOAD_URL:?Configure APK_DOWNLOAD_URL with the published signed APK.}"
: "${APK_SHA256:?Configure APK_SHA256 with its verified checksum.}"
if [[ "$APK_DOWNLOAD_URL" != https://* ]] || [[ ! "$APK_SHA256" =~ ^[a-fA-F0-9]{64}$ ]]; then
  echo "APK_DOWNLOAD_URL must use HTTPS and APK_SHA256 must be a SHA-256 digest." >&2
  exit 1
fi
mkdir -p build/web/downloads
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
  "$APK_DOWNLOAD_URL" -o build/web/downloads/concilio-jni-dreamrs.apk
printf '%s  %s\n' "$APK_SHA256" 'build/web/downloads/concilio-jni-dreamrs.apk' | sha256sum --check --status
