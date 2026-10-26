@echo off
:: usage: build-openrgb.bat <repo dir> <qt bin dir> <jom dir>
set "PATH=%PATH%;%~2;%~3"
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul || exit /b 1
cd /d "%~1"
qmake OpenRGB.pro CONFIG-=debug_and_release CONFIG+=release || exit /b 2
jom -j %NUMBER_OF_PROCESSORS% || exit /b 3
windeployqt --no-patchqt --no-quick-import --no-translations --no-system-d3d-compiler --no-compiler-runtime --no-opengl-sw --no-network .\release\OpenRGB.exe || exit /b 4
echo BUILD_OK
