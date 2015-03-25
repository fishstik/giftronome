@echo off
setlocal EnableDelayedExpansion

set ORIG_GIF=%1
set ORIG_NAME=!ORIG_GIF:~0,-4!
md frames >nul 2>nul
md frames\!ORIG_NAME! >nul 2>nul

 rem explode gif to frames
gif2frames gifs/%ORIG_GIF% 

 rem move created frames to tmp
	for /r %cd% %%i in (gifs\%ORIG_NAME%000*) do (
		set NAME=%%~nxi
		move gifs\!NAME! frames\!ORIG_NAME!\!NAME! >nul
	)

endlocal[]