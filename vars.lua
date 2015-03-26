--configurable vars
	--image viewing
		zoom = 1 --default multiplication of image size

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
		swidth = 1280*zoom
		sheight = 720*zoom
		borderless = true
		resizable = true
		showHelp = false

--nonconfigurable vars
	--file loading
		files = {}
		folders = {}
		images = {}

	--image viewing
		select 	= 1 	--which folder of pictures to loop through
		n 		= 1 	--which picture in the current folder is being displayed
		div 	= {} 	--number of beats per image loop (retrieved from config.txt, default=1)
		--light 	= {} 	--boolean: is the folder of pictures mostly light or dark? (retrieved from config.txt, default=false)
		image_x = 0

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

	--font
		font_size = swidth/51.2
		font_arial = gfx.newFont(font_size)
	
--android-specific vars
	--configurable
		--touchscreen
			swipeDist = swidth/6				--number of horizontal pixels to drag for swiping image
			flyoutSpeed = swidth/20				--speed of image fly out (in pixels per dt)
			flybackSpeed = flyoutSpeed/6 		--speed of image fly back (in pixels per dt)

			image_bottom_fadeScaleMin = 0.8 	--min size image fade while swiping
			image_bottom_fadeScaleMax = 0.975	--max size image fade while swiping
			image_bottom_fadeScaleSpeed = 0.01	--amount to increment every dt when zooming back from right-swipe
			image_bottom_fadeOutAdjust = 0.2
			greyLevel_fadeMax = 200				--max brightness of image fade-in while swiping

	--nonconfigurable
		--image viewing
			image_bottom_brightness = 255

			image_y = 0
			image_scaleY = 0

			select_bottom = 1
			n_bottom = 1
			image_bottom_x = 0
			image_bottom_y = 0
			image_bottom_scaleY = 0

			swapImages_enabled = true
			unswapImages_enabled = false

		--timing
			timer_bottom = 0

		--touchscreen
			x_init = nil			--initial x coord on touchmoved
			touchmoved = false
			touchreleased = true
			touchpressed = false

		--mouse
			mx_start = nil
			my_start = nil
			mx = 0
			my = 0