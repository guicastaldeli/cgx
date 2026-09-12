@echo off
echo ========================================
echo Building CGX Library
echo ========================================

set ROOT=%~dp0..
set BUILD=%ROOT%\.out
set SRC=%ROOT%\src
set INC=%ROOT%\include

if not exist "%BUILD%" mkdir "%BUILD%"
if not exist "%BUILD%\core" mkdir "%BUILD%\core"
if not exist "%BUILD%\api" mkdir "%BUILD%\api"
if not exist "%BUILD%\platform" mkdir "%BUILD%\platform"

echo.
echo [Compiling] top-level...
nasm -f win64 -i "%INC%/" "%SRC%\main.asm" -o "%BUILD%\main.obj"
if errorlevel 1 (
    echo [ERROR] Failed to compile main.asm
    exit /b 1
)

echo.
echo [Compiling] core...
for %%f in (%SRC%\core\*.asm) do (
    echo   Compiling %%~nf.asm...
    nasm -f win64 -i "%INC%/" "%%f" -o "%BUILD%\core\%%~nf.obj"
    if errorlevel 1 (
        echo [ERROR] Failed to compile %%f
        exit /b 1
    )
)

echo.
echo [Compiling] api...
for %%f in (%SRC%\api\*.asm) do (
    echo   Compiling %%~nf.asm...
    nasm -f win64 -i "%INC%/" "%%f" -o "%BUILD%\api\%%~nf.obj"
    if errorlevel 1 (
        echo [ERROR] Failed to compile %%f
        exit /b 1
    )
)

echo.
echo [Compiling] platform...
for %%f in (%SRC%\platform\win32\*.asm) do (
    echo   Compiling %%~nf.asm...
    nasm -f win64 -i "%INC%/" -i "%INC%\platform/" "%%f" -o "%BUILD%\platform\%%~nf.obj"
    if errorlevel 1 (
        echo [ERROR] Failed to compile %%f
        exit /b 1
    )
)

echo.
echo ========================================
echo CGX library built successfully!
echo ========================================