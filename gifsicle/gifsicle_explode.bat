@echo off
setlocal EnableDelayedExpansion

set ORIGINAL_GIF=%1

 rem explode gif to frames
gifsicle -e %ORIGINAL_GIF%

 rem rename created frames to gifs
	for /r %cd% %%i in (%ORIGINAL_GIF%.0*) do (
		set OLD_NAME=%%~nxi
		set NEW_NAME=!OLD_NAME:%1=!
		set NEW_NAME=!NEW_NAME:.=!
		set NEW_NAME=!NEW_NAME!_temp.gif
		ren !OLD_NAME! !NEW_NAME!
	)

	rem overlay optimized frame with previous unoptimized frame for all frames
	for /r %cd% %%i in (0*_temp.gif) do (
		set CUR_FILENAME=%%~nxi

		set CUR_NUM_PADDED=!CUR_FILENAME:_temp.gif=!
		set /a CUR_NUM=1!CUR_NUM_PADDED! %% 1000

		set /a NEXT_NUM=!CUR_NUM!+1
		set NEXT_NUM_PADDED=00!NEXT_NUM!
		set NEXT_NUM_PADDED=!NEXT_NUM_PADDED:~-3%!
		set NEXT_FILENAME=!NEXT_NUM_PADDED:_temp.gif
		
		if !CUR_NUM_PADDED!==000 (
			gifsicle 000_temp.gif 001_temp.gif | gifsicle -U "#1" > 001.gif
			ren 000_temp.gif 000.gif
		) else (
			if exist !NEXT_NUM_PADDED!_temp.gif (
				gifsicle !CUR_NUM_PADDED!.gif !NEXT_NUM_PADDED!_temp.gif | gifsicle -U "#1" > !NEXT_NUM_PADDED!.gif
			)
			del !CUR_NUM_PADDED!_temp.gif
		)
	)

endlocal[]