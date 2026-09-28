@echo off
chcp 65001 > nul
rem Поставить зависимости на Windows: numpy и scipy, больше ничего.
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
  echo   Не нашёл "py". Поставьте Python 3.10 или новее с python.org.
  echo.
  if defined HOLD pause
  exit /b 1
)

py -3 -m pip install -r requirements.txt
set CODE=%errorlevel%
if defined HOLD pause
exit /b %CODE%
