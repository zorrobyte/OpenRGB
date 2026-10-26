@echo off
:: usage: build-effects.bat <plugin repo dir> <qt bin dir> <jom dir>
set "PATH=%PATH%;%~2;%~3"
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul || exit /b 1
cd /d "%~1"
qmake OpenRGBEffectsPlugin.pro CONFIG-=debug_and_release CONFIG+=release || exit /b 2
jom -j %NUMBER_OF_PROCESSORS% || exit /b 3
echo BUILD_OK
