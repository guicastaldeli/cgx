@echo off
echo ========================================
echo Building CGX Tests
echo ========================================

set ROOT=%~dp0..
set BUILD=%ROOT%\.out
set SRC=%ROOT%\src
set INC=%ROOT%\include
set TESTS=%ROOT%\tests

call "%ROOT%\build\build.bat"
if errorlevel 1 (
    echo [ERROR] CGX library build failed!
    pause
    exit /b 1
)

if not exist "%BUILD%\tests" mkdir "%BUILD%\tests"

echo.
echo ========================================
echo Compiling and Linking Tests
echo ========================================
echo.

for %%f in ("%TESTS%\*.asm") do (
    echo [Building] %%~nf.exe...
    nasm -f win64 -i "%INC%/" "%%f" -o "%BUILD%\tests\%%~nf.obj"
    if errorlevel 1 (
        echo [ERROR] Failed to compile %%f
        goto :next
    )

    gcc -mwindows -o "%BUILD%\tests\%%~nf.exe" ^
        "%BUILD%\tests\%%~nf.obj" ^
        "%BUILD%\cgx.obj" ^
        "%BUILD%\core\*.obj" ^
        "%BUILD%\api\*.obj" ^
        "%BUILD%\platform\*.obj"

    if errorlevel 1 (
        echo [ERROR] Failed to link %%f
    ) else (
        echo [Success] %%~nf.exe created!
    )
    echo.
    :next
)

echo ========================================
echo All tests built!
echo ========================================
pause