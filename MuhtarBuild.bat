@echo off
setlocal EnableExtensions

rem MuhtarBuild Windows launcher.
rem FLUTTER_BIN may be a full path to flutter.bat; otherwise flutter must be in PATH.
set "ROOT=%~dp0"
if defined FLUTTER_BIN (
  set "FLUTTER=%FLUTTER_BIN%"
) else (
  set "FLUTTER=flutter"
)

if not exist "%ROOT%muhtar_minigame\pubspec.yaml" (
  echo [MuhtarBuild] Project folder was not found:
  echo %ROOT%muhtar_minigame
  exit /b 1
)

where "%FLUTTER%" >nul 2>&1
if errorlevel 1 (
  echo [MuhtarBuild] Flutter was not found.
  echo Add Flutter to PATH or run:
  echo   set FLUTTER_BIN=C:\path\to\flutter\bin\flutter.bat
  echo   MuhtarBuild.bat
  exit /b 1
)

pushd "%ROOT%muhtar_minigame"
if not defined MUHTAR_BUILD_DEVICE set "MUHTAR_BUILD_DEVICE=windows"
set "MUHTAR_BUILD=1"

if defined FLUTTER_BIN (
  call "%FLUTTER_BIN%" run -d "%MUHTAR_BUILD_DEVICE%" -t lib\muhtar_build.dart %*
) else (
  call flutter run -d "%MUHTAR_BUILD_DEVICE%" -t lib\muhtar_build.dart %*
)
set "EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %EXIT_CODE%
