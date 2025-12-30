#!/usr/bin/env bash
set -uo pipefail
: "${TMPDIR:=$(mktemp -d)}"
trap 'rm -rf "$TMPDIR"' EXIT


script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
config_file="$script_dir/deploy-theme.cfg"

if [[ ! -f "$config_file" ]]; then
  echo "[ERROR] Config file not found: $config_file"
  exit 1
fi

unset THEME_NAME THEME_TAGS THEME_SLUG HEADER_SCRIPT CHANGELOG_FILE STATIC_FILE DEST_DIR DEPLOY_TARGET
unset GITHUB_REPO TOKEN_FILE ZIP_NAME GENERATOR_SCRIPT GITHUB_TOKEN

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line//$'\r'/}"
  [[ -z "$line" || "${line:0:1}" == "#" || "${line:0:1}" == ";" ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  key="$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  val="$(echo "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  eval "$key=\"\$val\""
done < "$config_file"

# =====================================================
# CENTRAL DEPLOY SCRIPTS LOCATION
# =====================================================
DEPLOY_SCRIPTS_DIR="${DEPLOY_SCRIPTS_DIR:-/c/Ignore By Avast/0. PATHED Items/Themes/deployscripts}"
HEADER_SCRIPT="${HEADER_SCRIPT:-$DEPLOY_SCRIPTS_DIR/mytheme_headers.php}"
GENERATOR_SCRIPT="${GENERATOR_SCRIPT:-$DEPLOY_SCRIPTS_DIR/generate_theme_index.php}"
TOKEN_FILE="${TOKEN_FILE:-$DEPLOY_SCRIPTS_DIR/github_token.txt}"


if [[ -z "${THEME_SLUG:-}" ]]; then
  echo "[ERROR] THEME_SLUG is not defined in deploy-theme.cfg"
  exit 1
fi
if [[ -z "${GITHUB_REPO:-}" ]]; then
  echo "[ERROR] GITHUB_REPO is not defined in deploy-theme.cfg"
  exit 1
fi

ZIP_NAME="${ZIP_NAME:-$THEME_SLUG.zip}"
CHANGELOG_FILE="${CHANGELOG_FILE:-changelog.txt}"
STATIC_FILE="${STATIC_FILE:-static.txt}"
DEPLOY_TARGET="${DEPLOY_TARGET:-github}"
THEME_NAME="${THEME_NAME:-$THEME_SLUG}"
THEME_TAGS="${THEME_TAGS:-}"

theme_dir="$script_dir/$THEME_SLUG"
style_file="$theme_dir/style.css"
readme_file="$theme_dir/readme.txt"
temp_readme="$theme_dir/readme_temp.txt"
repo_root="$script_dir"
static_subfolder="$repo_root/uupd"

[[ -f "$style_file" ]] || { echo "[ERROR] style.css not found: $style_file"; exit 1; }
[[ -f "$CHANGELOG_FILE" ]] || { echo "[ERROR] Changelog file not found: $CHANGELOG_FILE"; exit 1; }
[[ -f "$STATIC_FILE"   ]] || { echo "[ERROR] Static readme file not found: $STATIC_FILE"; exit 1; }

# Update theme headers in style.css
php "$HEADER_SCRIPT" "$style_file"

# Extract theme metadata from style.css
requires_at_least="$(
  grep -m1 -E '^(Requires at least:|[[:space:]]*\*[[:space:]]*Requires at least:)' "$style_file" \
    | sed -E 's/.*Requires at least:[[:space:]]*//' || true
)"
tested_up_to="$(
  grep -m1 -E '^(Tested up to:|[[:space:]]*\*[[:space:]]*Tested up to:)' "$style_file" \
    | sed -E 's/.*Tested up to:[[:space:]]*//' || true
)"
requires_php="$(
  grep -m1 -E '^(Requires PHP:|[[:space:]]*\*[[:space:]]*Requires PHP:)' "$style_file" \
    | sed -E 's/.*Requires PHP:[[:space:]]*//' || true
)"
version="$(
  grep -m1 -E '^(Version:|[[:space:]]*\*[[:space:]]*Version:)' "$style_file" \
    | sed -E 's/.*Version:[[:space:]]*//; s/\r//; s/[[:space:]]+$//' || true
)"

if [[ -z "$version" ]]; then
  echo "[ERROR] Could not extract Version from $style_file"
  exit 1
fi

# Generate static index.json
echo "[INFO] Generating index.json for GitHub delivery..."
github_user="${GITHUB_REPO%%/*}"
repo_name="${GITHUB_REPO#*/}"
cdn_path="https://raw.githubusercontent.com/$github_user/$repo_name/main/uupd"
mkdir -p "$static_subfolder"

php "$GENERATOR_SCRIPT" \
  "$style_file" \
  "$CHANGELOG_FILE" \
  "$static_subfolder" \
  "$github_user" \
  "$cdn_path" \
  "$repo_name" \
  "$repo_name" \
  "$STATIC_FILE" \
  "$ZIP_NAME"

if [[ -f "$static_subfolder/index.json" ]]; then
  echo "[OK] index.json generated: $static_subfolder/index.json"
else
  echo "[ERROR] Failed to generate index.json"
fi

# Build readme.txt (optional, but mirrors your plugin flow)
{
  echo "=== $THEME_NAME ==="
  echo "Contributors: reallyusefulplugins"
  echo "Donate link: https://reallyusefulplugins.com/donate"
  echo "Tags: $THEME_TAGS"
  echo "Requires at least: $requires_at_least"
  echo "Tested up to: $tested_up_to"
  echo "Stable tag: $version"
  echo "Requires PHP: $requires_php"
  echo "License: GPL-2.0-or-later"
  echo "License URI: https://www.gnu.org/licenses/gpl-2.0.html"
  echo
} > "$temp_readme"

cat "$STATIC_FILE" >> "$temp_readme"
echo >> "$temp_readme"
echo "== Changelog ==" >> "$temp_readme"
cat "$CHANGELOG_FILE" >> "$temp_readme"

[[ -f "$readme_file" ]] && cp -f "$readme_file" "$readme_file.bak"
mv -f "$temp_readme" "$readme_file"

# Git commit/push (REPO ROOT) so uupd/ is included
pushd "$repo_root" >/dev/null

git add -A "$THEME_SLUG" "uupd" "$CHANGELOG_FILE" "$STATIC_FILE"

if ! git diff --cached --quiet; then
  git commit -m "Version $version Release"
  git push origin main
  echo "[OK] Git commit and push complete."
else
  echo "[INFO] No changes to commit."
fi

# Ensure tag points to this commit (important for release tag)
git tag -f "v$version"
git push origin "v$version" --force

popd >/dev/null


# Zip theme folder
zip_file="$script_dir/$ZIP_NAME"
sevenzip_win="/c/Program Files/7-Zip/7z.exe"

if [[ -x "$sevenzip_win" ]]; then
  pushd "$script_dir" >/dev/null
  "$sevenzip_win" a -tzip "$zip_file" "$THEME_SLUG" >/dev/null
  popd >/dev/null
else
  pushd "$script_dir" >/dev/null
  tar -a -c -f "$zip_file" "$THEME_SLUG"
  popd >/dev/null
fi

[[ -f "$zip_file" ]] || { echo "[ERROR] Failed to create archive."; exit 1; }
echo "[OK] Zipped to: $zip_file"

# Deploy
if [[ "${DEPLOY_TARGET,,}" == "private" ]]; then
  [[ -n "${DEST_DIR:-}" ]] || { echo "[ERROR] DEST_DIR is not set for private deploy."; exit 1; }
  mkdir -p "$DEST_DIR"
  cp -f "$zip_file" "$DEST_DIR/"
  echo "[OK] Copied to $DEST_DIR"
else
  echo "[INFO] Deploying to GitHub..."
  if [[ -z "${GITHUB_TOKEN:-}" && -f "$TOKEN_FILE" ]]; then
    GITHUB_TOKEN="$(tr -d '\r\n' < "$TOKEN_FILE")"
  fi
  [[ -n "${GITHUB_TOKEN:-}" ]] || { echo "[ERROR] GITHUB_TOKEN not available (set env var or provide TOKEN_FILE)"; exit 1; }

  release_tag="v$version"
  body_file="$(mktemp)"
  changelog_body="$(sed ':a;N;$!ba;s/\r//g' "$CHANGELOG_FILE" \
    | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' \
    | tr -d '\n')"

  cat >"$body_file" <<JSON
{
  "tag_name": "$release_tag",
  "name": "$version",
  "body": "$changelog_body",
  "draft": false,
  "prerelease": false
}
JSON

  status=$(curl -sS -o "$TMPDIR/github_release_response.json" -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$GITHUB_REPO/releases/tags/$release_tag" || true)

  release_id=""
  if [[ "$status" == "200" ]]; then
    release_id="$(grep -m1 -E '"id":[[:space:]]*[0-9]+' "$TMPDIR/github_release_response.json" | head -1 | sed -E 's/.*"id":[[:space:]]*([0-9]+).*/\1/')"
    echo "[INFO] Release exists. Updating body (id=$release_id)..."
    curl -sS -X PATCH "https://api.github.com/repos/$GITHUB_REPO/releases/$release_id" \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      --data-binary "@$body_file" >/dev/null
  else
    echo "[INFO] Creating new release..."
    curl -sS -X POST "https://api.github.com/repos/$GITHUB_REPO/releases" \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      --data-binary "@$body_file" > "$TMPDIR/github_release_response.json"
    release_id="$(grep -m1 -E '"id":[[:space:]]*[0-9]+' "$TMPDIR/github_release_response.json" | head -1 | sed -E 's/.*"id":[[:space:]]*([0-9]+).*/\1/')"
  fi

  [[ -n "$release_id" ]] || { echo "[ERROR] Could not determine release ID."; cat "$TMPDIR/github_release_response.json" || true; exit 1; }
  echo "[OK] Using Release ID: $release_id"

  asset_name="$(basename "$zip_file")"

  # Delete existing asset with same name (prevents 422 already_exists)
  assets_json="$TMPDIR/assets.json"
  curl -sS \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$GITHUB_REPO/releases/$release_id/assets" > "$assets_json"

  existing_asset_id="$(python - <<'PY' "$assets_json" "$asset_name"
import json,sys
p=sys.argv[1]; name=sys.argv[2]
data=json.load(open(p,'r',encoding='utf-8'))
for a in data:
    if a.get('name')==name:
        print(a.get('id',''))
        break
PY
)"

  if [[ -n "$existing_asset_id" ]]; then
    echo "[INFO] Deleting existing asset id=$existing_asset_id"
    curl -sS -X DELETE \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$GITHUB_REPO/releases/assets/$existing_asset_id" >/dev/null
  fi

  echo "[INFO] Uploading asset: $asset_name"
  curl -sS -X POST "https://uploads.github.com/repos/$GITHUB_REPO/releases/$release_id/assets?name=$asset_name" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/zip" \
    --data-binary @"$zip_file" >/dev/null


  rm -f "$body_file"
fi

echo
echo "[OK] Deployment complete: $DEPLOY_TARGET"
sleep 4
