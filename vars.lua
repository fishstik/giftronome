--configurable vars
	--image viewing
		zoom = 1.5 --default multiplication of image size

	--timing
		tapRstDelay = 2 				--seconds to wait before resetting tapped bpm
		bpm = 60 						--startup bpm
		fetchTrackDelay = 2				--number of seconds to wait after seeking track before querying last.fm for now playing
		lfmCountDown_fallback = 240		--number of seconds to assign "lfmCountDown" if both echonest and last.fm couldn't find a duration
		lfmCountDown_wait = 5 			--number of seconds to assign "lfmcoutndown" if nothing is playing (via last.fm)
		duration_minimum = 3 			--minimum number of seconds queried duration must be to not fall back to "lfmCountDown_fallback"
	--http
		echonestApi = "OR8WWX6WCTOAXRIT0"
		lfmApi = "e38cc7822bd7476fe4083e36ee69748e"
		lfmUser = "fishstik5"

	--display
	--window setMode params
		borderless = true
		resizable = true
		showHelp = false

--nonconfigurable vars
		os_string = love.system.getOS()

	--file loading
		images = {}
		imagenames = {}

	--image viewing
		select = 1 		--which folder of pictures to loop through
		n = 1 			--which picture in the current folder is being displayed
		div = {} 		--number of beats per image loop (retrieved from config.txt, default=1)
		light = {}	 	--boolean: is the folder of pictures mostly light or dark? (retrieved from config.txt, default=false)
		gifcount = 0

	--timing
		paused = false
		time_paused = 0 				--timestamp paused, difference from current time is added to lfmCountDown on unpause
		timer = 0 						--main image looping timer
		tap1 = 0
		tap2 = 0
		taps = {}
		sumTaps = 0
		timer_fetchTrack = 0 			--timer to count up to "fetchTrackDelay"
		delayedFetchEnabled = false 	--is automatic retrieval of last.fm track enabled?
		lfmCountDown = -1				--countdown until next automatic retrieval of last.fm track

	--http
		inputMode_artist = false 	--is the user typing an artist?
		inputMode_song = false 		--is the user typing a song?
		inputMode_lfm = false 		--is the user typing a last.fm username?
		isUrlTempo = false 			--is the tempo from echonest?
		artist = ""
		song = ""
			
	--display
	--colors
		red = {255, 0, 0}
		green = {0, 255, 0}
		blue = {0, 0, 255}
		yellow = {255, 255, 0}
		cyan = {0, 255, 255}
		black = {0, 0, 0}
		white = {255, 255, 255}