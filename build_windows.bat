@echo off
setlocal

rem Resolve paths relative to this script, including when launched from elsewhere.
pushd "%~dp0"
if errorlevel 1 exit /b 1

set "BUILD_CONFIG=Release"
if not "%~1"=="" set "BUILD_CONFIG=%~1"
if /i "%BUILD_CONFIG%"=="Release" goto config_valid
if /i "%BUILD_CONFIG%"=="Debug" goto config_valid
echo [ERROR] Usage: build_windows.bat [Release^|Debug]
set "BUILD_EXIT_CODE=1"
goto finish

:config_valid
if /i "%BUILD_CONFIG%"=="Release" set "BUILD_CONFIG=Release"
if /i "%BUILD_CONFIG%"=="Debug" set "BUILD_CONFIG=Debug"
rem An explicit toolchain takes precedence over any older MinGW on PATH.
if defined PICCOLO_MINGW_ROOT (
    if not exist "%PICCOLO_MINGW_ROOT%\bin\g++.exe" (
        echo [ERROR] PICCOLO_MINGW_ROOT must contain bin\g++.exe.
        set "BUILD_EXIT_CODE=1"
        goto finish
    )
    set "PATH=%PICCOLO_MINGW_ROOT%\bin;%PATH%"
)
where cmake >nul 2>&1
if errorlevel 1 (
    echo [ERROR] CMake was not found. Install CMake 3.19 or newer and add it to PATH.
    set "BUILD_EXIT_CODE=1"
    goto finish
)
set "PICCOLO_CXX="
for /f "delims=" %%C in ('where g++.exe 2^>nul') do if not defined PICCOLO_CXX set "PICCOLO_CXX=%%C"
if not defined PICCOLO_CXX (
    echo [ERROR] g++ was not found. Add the MinGW-w64 bin directory to PATH.
    set "BUILD_EXIT_CODE=1"
    goto finish
)
for %%C in ("%PICCOLO_CXX%") do set "PICCOLO_MINGW_BIN=%%~dpC"
for %%T in (gcc mingw32-make) do (
    if not exist "%PICCOLO_MINGW_BIN%%%T.exe" (
        echo [ERROR] %%T.exe must be in the same bin directory as g++.exe.
        set "BUILD_EXIT_CODE=1"
        goto finish
    )
)

rem MinGW Makefiles selects the configuration at configure time.
echo Configuring %BUILD_CONFIG% with MinGW g++...
cmake -S . -B build-mingw -G "MinGW Makefiles" "-DCMAKE_C_COMPILER=%PICCOLO_MINGW_BIN%gcc.exe" "-DCMAKE_CXX_COMPILER=%PICCOLO_CXX%" "-DCMAKE_MAKE_PROGRAM=%PICCOLO_MINGW_BIN%mingw32-make.exe" -DCMAKE_BUILD_TYPE=%BUILD_CONFIG%
set "BUILD_EXIT_CODE=%ERRORLEVEL%"
if not "%BUILD_EXIT_CODE%"=="0" (
    echo [ERROR] Configuration failed. The build has been stopped.
    echo See the CMake message above.
    goto finish
)

if not defined CMAKE_BUILD_PARALLEL_LEVEL set "CMAKE_BUILD_PARALLEL_LEVEL=4"
cmake --build build-mingw
set "BUILD_EXIT_CODE=%ERRORLEVEL%"
if not "%BUILD_EXIT_CODE%"=="0" (
    echo [ERROR] Compilation failed. See the compiler message above.
    goto finish
)
echo Build succeeded: "%~dp0bin\PiccoloEditor.exe"

:finish
popd
rem Keep the result visible on double-click; an explicit config skips the pause.
if "%~1"=="" pause
exit /b %BUILD_EXIT_CODE%
