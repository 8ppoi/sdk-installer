#!/bin/sh
set -eu

OS="$(uname -s)"
URL="http://localhost:8000"

# ブラウザ起動関数
open_browser() {
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL"
  elif command -v open >/dev/null 2>&1; then
    open "$URL"
  elif [ "$OS" = "MINGW"* ] || [ "$OS" = "MSYS"* ] || [ "$OS" = "CYGWIN"* ]; then
    start "" "$URL"
  else
    echo "⚠️ ブラウザ自動起動不可: $URL を手動で開いてね"
  fi
}

# 必須コマンドチェック
for cmd in deno git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ $cmd がインストールされていません"
    echo "先に $cmd をインストールしてから再実行してください"
    exit 1
  fi
done

echo "GitHub の Personal access token を入力してください:"
echo "(ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX のような文字列)"
read GH_PAT

# GitHub API 叩いて検証
RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GH_PAT" https://api.github.com/user)
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -n 1)

if [ "$STATUS" != "200" ]; then
  echo "❌ Personal access token が無効です"
  echo "GitHub にアクセスできませんでした (status=$STATUS)"
  exit 1
fi

LOGIN=$(curl -s -H "Authorization: token $GH_PAT" https://api.github.com/user | grep '"login"' | head -1 | cut -d '"' -f4)

git clone https://github.com/8ppoi/sdk.git
cd sdk

echo "https://$LOGIN:$GH_PAT@github.com" > ./.credentials
chmod 600 ./.credentials

(
  set -eu

  while ! nc -z localhost 8000; do
    sleep 0.1
  done
  curl http://localhost:8000/api/console/clone

  curl http://localhost:8000/api/vendor/clone/8ppoi
  curl http://localhost:8000/api/cartridge/clone/8ppoi/invader-x

  curl http://localhost:8000/api/vendor/init/$LOGIN
  curl http://localhost:8000/api/scaffold/vendor/$LOGIN
  curl http://localhost:8000/api/vendor/put/$LOGIN
  curl http://localhost:8000/api/vendor/push/$LOGIN

  curl http://localhost:8000/api/cartridge/init/$LOGIN/first-cartridge
  curl http://localhost:8000/api/scaffold/cartridge/$LOGIN/first-cartridge
  curl http://localhost:8000/api/cartridge/put/$LOGIN/first-cartridge
  curl http://localhost:8000/api/cartridge/push/$LOGIN/first-cartridge

  echo
  echo "8ppoi SDKのインストールが完了しました。"
  echo "Enterを押すとデフォルトのブラウザを起動します。"
  read _ </dev/tty

  open_browser
) &
deno run --watch -A ./main.js
