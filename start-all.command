#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$ROOT_DIR/yshop-drink-boot3"
ADMIN_DIR="$ROOT_DIR/yshop-drink-vue3"
UNIAPP_DIR="$ROOT_DIR/yshop-drink-uniapp-vue3"
DATA_DIR="$ROOT_DIR/local-data"
LOG_DIR="$DATA_DIR/logs"
HBUILDER_CLI="/Applications/HBuilderX.app/Contents/MacOS/cli"

export PATH="/opt/homebrew/bin:/opt/homebrew/opt/openjdk@17/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"

mkdir -p "$DATA_DIR/files" "$LOG_DIR"

echo "[1/7] Starting MySQL and Redis..."
/opt/homebrew/bin/brew services start mysql >/dev/null
/opt/homebrew/bin/brew services start redis >/dev/null

echo "[2/7] Preparing database..."
if ! /opt/homebrew/bin/mysql -uroot -e 'USE `yixiang-drink-open`' >/dev/null 2>&1; then
  /opt/homebrew/bin/mysql -uroot -e 'CREATE DATABASE IF NOT EXISTS `yixiang-drink-open` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
  /opt/homebrew/bin/mysql -uroot 'yixiang-drink-open' < "$BACKEND_DIR/sql/yixiang-drink-open.sql"
fi

echo "[3/7] Building backend if needed..."
if [ ! -f "$BACKEND_DIR/yshop-server/target/yshop-server.jar" ]; then
  (cd "$BACKEND_DIR" && /opt/homebrew/bin/mvn -pl yshop-server -am package -DskipTests)
fi

echo "[4/7] Starting backend on 48081..."
if ! lsof -nP -iTCP:48081 -sTCP:LISTEN >/dev/null 2>&1; then
  nohup java -jar "$BACKEND_DIR/yshop-server/target/yshop-server.jar" > "$LOG_DIR/backend.log" 2>&1 &
fi

echo "[5/7] Installing admin dependencies and starting dev server on 48082..."
(cd "$ADMIN_DIR" && /opt/homebrew/bin/pnpm install --registry=https://registry.npmmirror.com >/dev/null)
if ! lsof -nP -iTCP:48082 -sTCP:LISTEN >/dev/null 2>&1; then
  nohup /opt/homebrew/bin/pnpm --dir "$ADMIN_DIR" dev-server -- --host 0.0.0.0 > "$LOG_DIR/admin.log" 2>&1 &
fi

echo "[6/7] Ensuring HBuilderX and uni-app compilers are ready..."
"$HBUILDER_CLI" open >/dev/null 2>&1 || true
"$HBUILDER_CLI" project open --path "$UNIAPP_DIR" >/dev/null 2>&1 || true
"$HBUILDER_CLI" installPlugin --name compile-dart-sass --force true >/dev/null 2>&1 || true

echo "[7/7] Launching H5 and compiling WeChat mini program..."
"$HBUILDER_CLI" launch web --project yshop-drink-uniapp-vue3 --continue-on-error false --browser Built >/dev/null 2>&1 || true
"$HBUILDER_CLI" launch mp-weixin --project yshop-drink-uniapp-vue3 --compile true --runtime-log true --continue-on-error false >/dev/null 2>&1 || true

echo
echo "Services are starting up."
echo "Backend:        http://127.0.0.1:48081"
echo "Admin console:  http://127.0.0.1:48082"
echo "H5 frontend:    http://127.0.0.1:5173/h5/"
echo "Mini program:   $UNIAPP_DIR/unpackage/dist/dev/mp-weixin"
echo "Logs:           $LOG_DIR"
