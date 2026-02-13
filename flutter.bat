@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%"

set "SDK_PATH_FILE=%PROJECT_DIR%.flutter-sdk"
if not exist "%SDK_PATH_FILE%" (
  echo [flutter.bat] 找不到 .flutter-sdk 檔案，請在專案根目錄建立並填入 Flutter SDK 路徑。 1>&2
  exit /b 1
)

for /f "usebackq delims=" %%A in ("%SDK_PATH_FILE%") do set "FLUTTER_SDK_REL=%%A"

rem 解析成絕對路徑
pushd "%PROJECT_DIR%"
pushd "%FLUTTER_SDK_REL%" 2>nul
if errorlevel 1 (
  echo [flutter.bat] 無效的 Flutter SDK：%FLUTTER_SDK_REL% 1>&2
  exit /b 1
)
set "FLUTTER_SDK=%cd%"
popd
popd

set "FLUTTER_BIN=%FLUTTER_SDK%\bin\flutter.bat"
if not exist "%FLUTTER_BIN%" (
  echo [flutter.bat] 無效的 Flutter SDK：%FLUTTER_SDK% 1>&2
  exit /b 1
)

rem 將對應版本的 dart/flutter 放到 PATH 最前
set "PATH=%FLUTTER_SDK%\bin;%FLUTTER_SDK%\bin\cache\dart-sdk\bin;%PATH%"

rem （選用）每個專案獨立 pub 快取
rem set "PUB_CACHE=%PROJECT_DIR%\.pub-cache"

call "%FLUTTER_BIN%" %*
endlocal