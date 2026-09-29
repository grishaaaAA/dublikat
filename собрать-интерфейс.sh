#!/bin/zsh
# Собрать интерфейс диспетчера в web/ — отсюда его отдаёт сам движок:
# `python3 -m vrptw.server 8000 …` → http://localhost:8000.
#
# Исходники интерфейса — ветка «движок» репозитория Антона
# (github.com/koryaginstudio/PROJECT_POLET), по умолчанию в ~/polet_движок.
# Другой путь — первым аргументом: zsh собрать-интерфейс.sh ~/где/app
#
# Что делает:
#   · отказывается собирать незакоммиченное: в web/ должно лежать то, что
#     можно найти в истории ветки по коммиту из web/сборка.json;
#   · проверяет типы (tsc) — код выхода берётся прямо, не через конвейер:
#     в цепочке с echo он терялся, и так закоммитили сломанный пакет 2;
#   · собирает vite в web/, стирая прежнюю сборку;
#   · выкидывает data/*/roads.json — дороги для счёта в браузере без
#     движка. Из web/ интерфейс открывает сам движок, и дороги ему дают
#     его ответы; эти 9 МБ в клоне у проверяющего не читались бы никогда.
#     Без них режим «без движка» рисует перегоны прямыми, а не ломается;
#   · пишет web/сборка.json: ветка, коммит, когда собрано.
#
# Имена переменных — латиницей: zsh не берёт кириллицу (правило 11).

set -u
APP=${1:-$HOME/polet_движок/app}
ROOT=${0:A:h}
WEB=$ROOT/web
export PATH="$HOME/.local/node/bin:$PATH"

if [ ! -f "$APP/package.json" ]; then
  echo "✗ интерфейса нет в $APP — укажите путь к app/ первым аргументом"
  exit 1
fi
DIRTY=$(git -C "$APP" status --porcelain -- . 2>/dev/null)
if [ -n "$DIRTY" ]; then
  echo "✗ в $APP есть незакоммиченное — сначала закоммитьте:"
  echo "$DIRTY" | head -10
  exit 1
fi
BRANCH=$(git -C "$APP" rev-parse --abbrev-ref HEAD)
COMMIT=$(git -C "$APP" rev-parse --short HEAD)
if [ "$BRANCH" = "HEAD" ]; then
  # Отсоединённая голова: имя ветки взять у удалённой ссылки на этот же
  # коммит. Иначе в сборка.json уедет слово «HEAD», а README обещает, что
  # это единственное место, где написано, из какой ветки собран web/.
  # grep '/' отсекает origin/HEAD: он сокращается до «origin», и в файл
  # уехало бы имя удалённого вместо имени ветки. Дальше снимается только
  # первый кусок пути — имя удалённого, а «claude/что-то» остаётся целым.
  #
  # На одном коммите ссылок бывает несколько: 29 сентября на нём стояли и
  # origin/main, и origin/claude/…, и в сборка.json уехало служебное имя
  # вместо main. Поэтому main и master выбираются первыми — это та ветка,
  # с которой на самом деле снимают.
  REFS=$(git -C "$APP" for-each-ref --points-at HEAD \
         --format='%(refname:short)' refs/remotes | grep '/')
  REF=$(echo "$REFS" | grep -E '/(main|master)$' | head -1)
  [ -z "$REF" ] && REF=$(echo "$REFS" | head -1)
  if [ -n "$REF" ]; then BRANCH=${REF#*/}; else BRANCH="отсоединённая@$COMMIT"; fi
fi

cd "$APP" || exit 1
TSC_OUT=$(./node_modules/.bin/tsc -b --force --noEmit 2>&1)
TSC_CODE=$?
if [ $TSC_CODE -ne 0 ]; then
  echo "$TSC_OUT" | head -30
  echo "✗ tsc: ошибки типов — сборка не положена"
  exit 1
fi

BUILD_OUT=$(./node_modules/.bin/vite build --outDir "$WEB" --emptyOutDir 2>&1)
BUILD_CODE=$?
if [ $BUILD_CODE -ne 0 ]; then
  echo "$BUILD_OUT" | tail -30
  echo "✗ vite build упал — web/ мог остаться пустым, пересоберите"
  exit 1
fi

rm -f "$WEB"/data/*/roads.json
# Отпечаток дерева, из которого собрано. По нему selfcheck сверяет, что
# копия исходников в `интерфейс/` — та же, что пошла в сборку: снимают её
# отдельной командой, и забыть переснять легко (29 сентября, ночь).
SRC=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from vrptw.selfcheck import отпечаток_исходников
print(отпечаток_исходников('$APP'))")
if [ -z "$SRC" ]; then
  echo "✗ не смог посчитать отпечаток исходников — сборка не помечена"
  exit 1
fi

cat > "$WEB/сборка.json" <<JSON
{"ветка": "$BRANCH", "коммит": "$COMMIT", "исходники": "$SRC", "собрано": "$(date '+%Y-%m-%dT%H:%M:%S')"}
JSON

SIZE=$(du -sh "$WEB" | cut -f1)
echo "✓ интерфейс собран в web/: ветка $BRANCH, коммит $COMMIT, $SIZE"
echo "  дальше: git add web && git commit — и zsh проверка-с-нуля.sh"
