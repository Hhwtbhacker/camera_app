#!/usr/bin/env bash
# 一键发布新版本到 GitHub Releases（App 内 OTA 更新的数据源）
#
# 用法:
#   ./scripts/release.sh <版本名> <构建号> ["更新说明"]
# 示例:
#   ./scripts/release.sh 1.0.1 2 "1. 新增应用内 OTA 更新；2. 修复 xxx"
#
# 做的事:
#   1. 改 pubspec.yaml 版本号
#   2. flutter analyze + flutter test
#   3. 构建 release APK，算 SHA-256
#   4. 提交 + 打标签 v<版本名>+<构建号> 并推送
#   5. 创建 GitHub Release 并上传 APK 资产（body 里带 sha256，App 端会校验）
#
# 需要凭据（二选一）:
#   export GITHUB_TOKEN=<你的 PAT>            # 需要 Contents: Read and write
#   git config --local github.token <你的 PAT>
set -euo pipefail

VERSION="${1:-}"
BUILD="${2:-}"
NOTES="${3:-}"

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
  echo "用法: $0 <版本名> <构建号> [\"更新说明\"]" >&2
  echo "示例: $0 1.0.1 2 \"新增应用内更新\"" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TAG="v${VERSION}+${BUILD}"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
APK_NAME="camera_mobile-${VERSION}.apk"

TOKEN="${GITHUB_TOKEN:-$(git config --local --get github.token || true)}"
if [[ -z "$TOKEN" ]]; then
  echo "缺少 GITHUB_TOKEN（或执行 git config --local github.token <PAT>）" >&2
  exit 1
fi

REPO_SLUG="$(git remote get-url origin |
  sed -E 's#\.git$##' |
  sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#')"
if [[ ! "$REPO_SLUG" =~ ^[^/]+/[^/]+$ ]]; then
  echo "无法从 origin 解析出 owner/repo，得到: $REPO_SLUG" >&2
  exit 1
fi
echo "==> 仓库: $REPO_SLUG   目标版本: $TAG"

echo "==> 更新 pubspec.yaml 版本号"
sed -i -E "s/^version: .*/version: ${VERSION}+${BUILD}/" pubspec.yaml
grep -q "^version: ${VERSION}+${BUILD}$" pubspec.yaml || {
  echo "pubspec.yaml 版本号写入失败" >&2
  exit 1
}

if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  echo "==> 跳过静态检查/测试/构建（SKIP_BUILD=1），复用已有 APK"
else
  echo "==> 静态检查与单元测试"
  flutter analyze
  flutter test

  echo "==> 构建 release APK"
  flutter build apk --release
fi
[[ -f "$APK_PATH" ]] || { echo "未找到 APK: $APK_PATH" >&2; exit 1; }

SHA256="$(sha256sum "$APK_PATH" | cut -d' ' -f1)"
SIZE="$(du -h "$APK_PATH" | cut -f1)"
echo "==> APK: $SIZE  sha256=$SHA256"

echo "==> 提交并打标签"
git add pubspec.yaml
if git diff --cached --quiet; then
  echo "    （版本号无变化，跳过提交）"
else
  git commit -m "release: ${TAG}"
fi
git tag -f -a "$TAG" -m "release ${TAG}"
git push origin HEAD
git push -f origin "$TAG"

echo "==> 创建 GitHub Release 并上传 APK"
BODY_FILE="$(mktemp)"
{
  echo "${NOTES:-更新到 ${TAG}}"
  echo
  echo "sha256: ${SHA256}"
} > "$BODY_FILE"

# 统一带上鉴权头
gh_api() {
  curl -sS \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$@"
}

PAYLOAD="$(python3 - "$TAG" "$BODY_FILE" <<'PY'
import json, sys
tag, body_path = sys.argv[1], sys.argv[2]
with open(body_path, encoding='utf-8') as fh:
    body = fh.read()
print(json.dumps({"tag_name": tag, "name": tag, "body": body,
                  "draft": False, "prerelease": False}))
PY
)"

RELEASE_API="https://api.github.com/repos/${REPO_SLUG}/releases/tags/${TAG}"
UPLOAD_URL="$(gh_api "$RELEASE_API" |
  python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("upload_url") or "")
except Exception:
    print("")')"

if [[ -n "$UPLOAD_URL" ]]; then
  echo "    （Release 已存在，更新说明后复用）"
  gh_api -X PATCH "$RELEASE_API" -d "$PAYLOAD" >/dev/null
else
  RELEASE_JSON="$(gh_api -X POST "https://api.github.com/repos/${REPO_SLUG}/releases" -d "$PAYLOAD")"
  UPLOAD_URL="$(printf '%s' "$RELEASE_JSON" |
    python3 -c 'import json,sys; print(json.load(sys.stdin).get("upload_url") or "")')"
  if [[ -z "$UPLOAD_URL" ]]; then
    echo "创建 Release 失败: $RELEASE_JSON" >&2
    rm -f "$BODY_FILE"
    exit 1
  fi
fi
UPLOAD_URL="${UPLOAD_URL%%\{*}"

# 同名资产先删掉，避免重复上传时 422（already exists）
OLD_ASSET="$(gh_api "$RELEASE_API" |
  python3 -c 'import json,sys
name = sys.argv[1]
try:
    assets = json.load(sys.stdin).get("assets", [])
except Exception:
    assets = []
print(next((str(a["id"]) for a in assets if a.get("name") == name), ""))' "$APK_NAME")"
if [[ -n "$OLD_ASSET" ]]; then
  echo "    （删除同名旧资产 #${OLD_ASSET}）"
  gh_api -X DELETE "https://api.github.com/repos/${REPO_SLUG}/releases/assets/${OLD_ASSET}" >/dev/null
fi

gh_api -X POST \
  -H "Content-Type: application/vnd.android.package-archive" \
  --data-binary "@${APK_PATH}" \
  "${UPLOAD_URL}?name=${APK_NAME}" |
  python3 -c 'import json,sys; d=json.load(sys.stdin); print("资产:", d.get("browser_download_url") or d.get("message"))'

rm -f "$BODY_FILE"
echo "==> 发布完成: https://github.com/${REPO_SLUG}/releases/tag/${TAG}"
