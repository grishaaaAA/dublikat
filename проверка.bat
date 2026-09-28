@echo off
chcp 65001 > nul
rem Проверки стенда на Windows. Замена `python3 -m ...` из README:
rem команды `python3` в Windows нет, а системный псевдоним python3.exe
rem открывает Microsoft Store. Здесь используется `py -3` — он ставится
rem вместе с Python с python.org.
rem
rem   проверка.bat                    обе проверки подряд
rem   проверка.bat стенд   (stand)    только selfcheck, ~40 секунд
rem   проверка.bat сервер  (server)   только server check, около семи минут
rem
rem Слова можно писать и латиницей: кириллица в аргументе идёт через
rem кодовую страницу консоли, а проверить это нам негде.
rem
rem Живьём на Windows не проверялось: машины не было. Если что-то пойдёт
rem не так — напишите нам, это важнее, чем кажется.
setlocal
cd /d "%~dp0"

rem Двойной щелчок: не дать окну закрыться с результатом.
set HOLD=
rem Ищем ".bat", а не "%~nx0": имя файла кириллическое, а через
rem трубу оно уходит в find.exe двумя разными дорогами — аргументом
rem и байтами stdin. Совпадут они не на всякой сборке, и промах тут
rem молчаливый: HOLD не выставится, окно захлопнется вместе с
rem сообщением об ошибке. В интерактивном cmd в %cmdcmdline% лежит
rem только путь к cmd.exe, ".bat" там нет — различение сохраняется.
echo %cmdcmdline% | find /i ".bat" > nul && set HOLD=1

where py > nul 2>&1
if errorlevel 1 (
  echo.
  echo   Не нашёл "py". Поставьте Python 3.10 или новее с python.org
  echo   и отметьте "Add python.exe to PATH" при установке.
  echo   Команда "python3" в Windows не работает: она открывает Microsoft Store.
  echo.
  if defined HOLD pause
  exit /b 1
)

if /i "%~1"=="сервер" goto server
if /i "%~1"=="server" goto server

echo === Проверка стенда (около 40 секунд) ===
py -3 -m vrptw.selfcheck
set CODE=%errorlevel%
if not "%CODE%"=="0" (
  if defined HOLD pause
  exit /b %CODE%
)
if /i "%~1"=="стенд" goto done
if /i "%~1"=="stand" goto done

:server
echo.
echo === Проверка сервера (около семи минут) ===
py -3 -m vrptw.server check
set CODE=%errorlevel%
if defined HOLD pause
exit /b %CODE%

:done
if defined HOLD pause
exit /b 0
