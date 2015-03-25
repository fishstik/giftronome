socket = require "socket"
http = require "socket.http"
utf8_validator = require "utf8_validator"
require "coroutines"
require "touch"

--love2d shortcuts
	gfx = love.graphics
	filesys = love.filesystem
	keybd = love.keyboard

--configuration vars
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

--nonconfiguration vars
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


function love.load()
	--retrieve files
		folders = filesys.getDirectoryItems("/frames")
		for i = 1, #folders, 1 do
			div[i] = 1
			--light[i] = false
			files[i] = filesys.getDirectoryItems(string.format("frames/%s", folders[i]))
			images[i] = {}
			local k = 0
			for j = 1, #files[i], 1 do --loop thru files in each folder
				fileext = tostring((files[i][j]):match("[^.]+.(.+)")) --extract file extension
				if fileext == "gif" or fileext == "png" or fileext == "jpg" or fileext == "bmp" then
					k = k + 1
					images[i][k] = gfx.newImage(string.format("frames/%s/%02s", folders[i], files[i][k])) --collect image files
				elseif fileext == "txt" then
					--open config txt file
					config = filesys.read(string.format("frames/%s/%s", folders[i], files[i][j]))
					div[i] = config:match("div=+(%d+)[\r\n]?") --look for 'div' parameter in config txt
					--light[i] = config:match("light=+(%l+)[\r\n]?") == "true" --look for 'light' parameter in config txt
				end
			end
		end

	--load initial image, get dimensions
		image = images[select][n]
		love.window.setMode(swidth, sheight, {borderless=borderless, resizable=resizable, display=2})

	keybd.setKeyRepeat(true)
end

function love.draw()
	width, height, windowflags = love.window.getMode()

	--Android stuff
		gfx.setFont(font_arial)

		--draw bottom image during drag
			if image_bottom and (touchmoved or thread_changeImgAnim or thread_keepImgAnim) then
				gfx.setColor({image_bottom_brightness, image_bottom_brightness, image_bottom_brightness})
				gfx.draw(image_bottom, image_bottom_x+(swidth-image_bottom:getWidth()*image_bottom_scaleY)/2, image_bottom_y, 0, image_bottom_scaleY, image_bottom_scaleY)
			end

	--draw main image
		if image then
			gfx.setColor(white)
			if not touchmoved then image_scaleY = sheight/image:getHeight() end
			gfx.draw(image, image_x+(swidth-image:getWidth()*image_scaleY)/2, image_y, 0, image_scaleY, image_scaleY)
		end

	--draw text
		local maincolor = {200,200,200}
		--if light[select] == true then maincolor = black end
		gfx.setColor(maincolor)

		if isUrlTempo then gfx.setColor(cyan) end
		gfx.print(string.format("%.1f bpm", bpm), 0, 0)

		if inputMode_artist then gfx.setColor(red) end
		if isUrlTempo then gfx.setColor(cyan) end
		if not utf8_validator.validate(artist) then artist = "ERROR: NOT VALID UTF-8" end
		gfx.print(string.format("artist: [%s]", artist), 0, 2*font_size)

		gfx.setColor(maincolor)
		if inputMode_song then gfx.setColor(red) end
		if isUrlTempo then gfx.setColor(cyan) end
		if not utf8_validator.validate(song) then song = "ERROR: NOT VALID UTF-8" end
		gfx.print(string.format("song: [%s]", song), 0, 3*font_size)

		gfx.setColor(maincolor)

		gfx.print("H: show/hide controls", 0, 5*font_size)
		if (showHelp) then
			gfx.print("esc: exit", 					0, 6*font_size)
			gfx.print("[/]: adjust BPM", 			0, 7*font_size)
			gfx.print("</>: halve/double BPM", 		0, 8*font_size)
			gfx.print("space: tap BPM", 			0, 9*font_size)
			gfx.print("{/}: adjust countdown", 		0, 10*font_size)
			gfx.print("R: jump to frame 1", 		0, 11*font_size)
			gfx.print("up/down: zoom",				0, 12*font_size)
			gfx.print("left/right: switch GIFs",	0, 13*font_size)
			gfx.print("enter: input artist & song",	0, 14*font_size)
			gfx.print("L: input last.fm user", 		0, 15*font_size)
			gfx.print("W: fetch last.fm playing",	0, 16*font_size)
			gfx.print("A/D: seek WPM", 				0, 17*font_size)
			gfx.print("S: play/pause WMP", 			0, 18*font_size)
		end

		if inputMode_lfm then gfx.setColor(red) end
		gfx.print(string.format("last.fm user: [%s]", lfmUser), 0, sheight-10-3*font_size)

		gfx.setColor(maincolor)
		local lfmcountdownprint = lfmCountDown - love.timer.getTime()
		if paused then lfmcountdownprint = lfmcountdownprint + (love.timer.getTime() - time_paused) end
		gfx.print(string.format("next fetch in %d:%02d", math.floor(lfmcountdownprint/60), math.floor(lfmcountdownprint % 60)), 0, sheight-10-2*font_size)
		gfx.print(string.format("%d/%d: %s", select, #folders, files[select][n]), 0, sheight-10-1*font_size)
end
	
function love.update(dt)
	if paused then return end

	--Android stuff
		--Loop through images in bottom folder according to BPM and div
			if timer_bottom == 0 then timer_bottom = love.timer.getTime() end
			if love.timer.getTime() - timer_bottom >= 60/bpm/#images[select_bottom] then
				mult = math.floor((love.timer.getTime()-timer_bottom)/(60/bpm/#images[select_bottom]))
				timer_bottom = timer_bottom + mult*60/bpm/#images[select_bottom]*div[select_bottom]
				n_bottom = n_bottom + 1
				if n_bottom > #images[select_bottom] then n_bottom = 1 end
			end
			image_bottom = images[select_bottom][n_bottom]

		--Handle change image coroutine - iterate through while loop once per love.update(). if dead, throw out.
			if (thread_changeImgAnim) then
				local thread_changeImgAnim_status = coroutine.status(thread_changeImgAnim)
				if (thread_changeImgAnim_status == 'suspended') then
					coroutine.resume(thread_changeImgAnim)
				elseif (thread_changeImgAnim_status == 'dead') then
					thread_changeImgAnim = nil
				end
			end

		--Handle keep image coroutine
			if (thread_keepImgAnim) then
				local thread_keepImgAnim_status = coroutine.status(thread_keepImgAnim)
				if (thread_keepImgAnim_status == 'suspended') then
					coroutine.resume(thread_keepImgAnim)
				elseif (thread_keepImgAnim_status == 'dead') then
					thread_keepImgAnim = nil
				end
			end

		--make mouse trigger touch callbacks
		mx, my = love.mouse.getPosition()
		mx = mx / swidth
		my = my / sheight

		if love.mouse.isDown("l") then
			if not (mx_start and my_start) then
				love.touchpressed(0, mx, my, 1)
				mx_start = mx
				my_start = my
			elseif math.abs(mx - mx_start) > 0 or math.abs(my - my_start) > 0 then
				love.touchmoved(0, mx, my, 1)
			end
		else
			if mx_start and my_start then
				mx_start = nil
				my_start = nil
				love.touchreleased(0, mx, my, 1)
			end
		end

	--Loop through images in selected folder according to BPM and div
		if timer == 0 then timer = love.timer.getTime() end
		if love.timer.getTime() - timer >= 60/bpm/#images[select] then
			mult = math.floor((love.timer.getTime()-timer)/(60/bpm/#images[select]))
			timer = timer + mult*60/bpm/#images[select]*div[select]
			n = n + 1
			if n > #images[select] then n = 1 end
		end
		image = images[select][n]

	--Automatically request last.fm track after seeking track + fetchTrackDelay seconds
		if delayedFetchEnabled then
			if timer_fetchTrack == 0 then timer_fetchTrack = love.timer.getTime() end
			if love.timer.getTime() - timer_fetchTrack >= fetchTrackDelay then
				timer_fetchTrack = love.timer.getTime()
				req_lastfm()
				delayedFetchEnabled = false
				timer_fetchTrack = 0
			end
		end

	--Automatically request last.fm track on startup and when lfmCountDown reaches zero
		local lfmcountdowncheck = lfmCountDown - love.timer.getTime()
		if lfmcountdowncheck < 0 then
			req_lastfm()
		end
end

function love.keypressed(key)
	--capture keys of length 1 if an input mode is active
		if inputMode_artist then
			if #key == 1 then artist = artist .. key
			elseif key == "escape" then	love.event.push("quit")
			elseif key == "backspace" then
				if keybd.isDown("lctrl") or keybd.isDown("rctrl") then
					local i = string.find(artist, " [^ ]*$")
					if i then artist = string.sub(artist, 1, i-1)
					else artist = ""
					end
				else artist = string.sub(artist, 1, -2)
				end
			elseif key == "return" then
				inputMode_artist = false
			end
		elseif inputMode_song then
			if #key == 1 then song = song .. key
			elseif key == "escape" then	love.event.push("quit") 
			elseif key == "backspace" then
				if keybd.isDown("lctrl") or keybd.isDown("rctrl") then
					local i = string.find(song, " [^ ]*$")
					if i then song = string.sub(song, 1, i-1)
					else song = ""
					end
				else song = string.sub(song, 1, -2)
				end
			elseif key == "return" then
				inputMode_song = false
				print("")
				req_echonest(artist, song)
			end
		elseif inputMode_lfm then
			if #key == 1 then lfmUser = lfmUser .. key
			elseif key == "escape" then	love.event.push("quit") 
			elseif key == "backspace" then
				if keybd.isDown("lctrl") or keybd.isDown("rctrl") then
					local i = string.find(lfmUser, " [^ ]*$")
					if i then lfmUser = string.sub(lfmUser, 1, i-1)
					else lfmUser = ""
					end
				else lfmUser = string.sub(lfmUser, 1, -2)
				end
			elseif key == "return" then
				inputMode_lfm = false
				req_lastfm()
			end
	--otherwise, enable controls
		else
			if key == "return" then
				isUrlTempo = false
				if not inputMode_artist and not inputMode_song then
					artist = ""
					song = ""
					inputMode_artist = true
				end
				if song == "" then
					inputMode_song = true
				end
			end
			if key == "l" then
				lfmUser = ""
				inputMode_lfm = true
			end
			if key == "escape" then love.event.push("quit") end
			if key == "up" then
				zoom = 3/2*zoom
				swidth = zoom*image:getWidth()
				sheight = zoom*image:getHeight()
				love.window.setMode(swidth, sheight, {borderless=borderless, resizable=resizable, display=windowflags["display"]})
			end
			if key == "down" then
				zoom = 2/3*zoom
				swidth = zoom*image:getWidth()
				sheight = zoom*image:getHeight()
				love.window.setMode(swidth, sheight, {borderless=borderless, resizable=resizable, display=windowflags["display"]})
			end
			if key == "left" then
				if select == 1 then
					select = #folders
				else
					select = select - 1
				end
				n = 1
				swidth = zoom*images[select][n]:getWidth()
				sheight = zoom*images[select][n]:getHeight()
				love.window.setMode(swidth, sheight, {borderless=borderless, resizable=resizable, display=windowflags["display"]})
			end
			if key == "right" then
				if select == #folders then
					select = 1
				else
					select = select + 1
				end
				n = 1
				swidth = zoom*images[select][n]:getWidth()
				sheight = zoom*images[select][n]:getHeight()
				love.window.setMode(swidth, sheight, {borderless=borderless, resizable=resizable, display=windowflags["display"]})
			end
			if key == "[" then
				if keybd.isDown("lshift") or keybd.isDown("rshift") and lfmCountDown > 10 then --"{"
					lfmCountDown = lfmCountDown - 1
				elseif bpm > 0.1 then --"["
					isUrlTempo = false
					bpm = bpm - 0.1
				end
			end
			if key == "]" then
				if keybd.isDown("lshift") or keybd.isDown("rshift") then --"}"
					lfmCountDown = lfmCountDown + 1
				else  --"]"
					isUrlTempo = false
					bpm = bpm + 0.1
				end
			end
			if key == "," then
				if keybd.isDown("lshift") or keybd.isDown("rshift") then --"<"
					n = 1
					bpm = bpm / 2
				end
			end
			if key == "." then
				if keybd.isDown("lshift") or keybd.isDown("rshift") then --">"
					n = 1
					bpm = bpm * 2
				end
			end
			if key == "r" then
				n = 1
				taps = {}
			end
			if key == "w" then
				req_lastfm()
			end
			-- if key == "a" then 
			-- 	local wmpwindow = winapi.find_window("WMPlayerApp")
			-- 	wmpwindow:send_message(273, 18810, 0) -- WMP Previous
			-- 	delayedFetchEnabled = true
			-- end
			if key == "s" then
				-- local wmpwindow = winapi.find_window("WMPlayerApp")
				-- wmpwindow:send_message(273, 18808, 0) -- WMP Pause

				if not paused then
					time_paused = love.timer.getTime()
					paused = true
				else
					lfmCountDown = lfmCountDown + love.timer.getTime() - time_paused --adjust countdown for paused time
					time_paused = 0
					paused = false
				end
			end
			-- if key == "d" then
			-- 	local wmpwindow = winapi.find_window("WMPlayerApp")
			-- 	wmpwindow:send_message(273, 18811, 0) -- WMP Next
			-- 	delayedFetchEnabled = true
			-- end
			if key == "h" then
				showHelp = not showHelp
			end
			if key == " " then
				if tap1 == 0 then
					tap1 = love.timer.getTime()
					if tap1 - tap2 > tapRstDelay then
						taps = {}
					end
					n = 1
					print("tap1")
				else
					tap2 = love.timer.getTime()
					if tap2 - tap1 < tapRstDelay then
						bpmi = -60/(tap1-tap2)
						table.insert(taps, bpmi)
						sumTaps = 0
						for i = 1, #taps, 1 do
							sumTaps = sumTaps + taps[i]
						end
						bpm = sumTaps/(#taps)
						print(string.format("tap2: %d/%d=%.1f", sumTaps, #taps, bpm))
						n = 1
						tap1 = 0
						isUrlTempo = false
					else
						taps = {}
						tap1 = love.timer.getTime()
						print("tap1")
					end
				end
			end
		end
end

function req_lastfm() --requests last.fm profile in "lfmUser" for now playing, calls req_echonest if found
	local reqtimestart = love.timer.getTime() --start timer for countdown adjustment
	print("\nlast.fm: Fetching now playing...")

	if lfmUser ~= "" then
		local lfm = http.request(string.format("http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=%s&api_key=%s", lfmUser, lfmApi))
		if lfm then
			local x, a = string.find(lfm, '<track nowplaying="true">')
			if a then
				--find artist location
				local x, art_a = string.find(lfm, '">.', a)
				local art_b, x = string.find(lfm, '.</artist>', art_a)

				--find song location
				local x, tit_a = string.find(lfm, '<name>.', art_b)
				local tit_b, x = string.find(lfm, '.</name>', tit_a)

				--extract artist, song
				artist = lfm:sub(art_a, art_b)
				song = lfm:sub(tit_a, tit_b)
				print(string.format("last.fm: Found now playing:\n   artist=%s\n   song=%s", artist, song))

				req_echonest(artist, song) --echonest call

				--stop timer, adjust countdown for delay
				local reqtime = love.timer.getTime() - reqtimestart
				lfmCountDown = lfmCountDown - reqtime

				print(string.format("Took %d s", reqtime))
			else
				print(string.format("last.fm: Nothing playing for user %s", lfmUser))
				lfmCountDown = lfmCountDown_fallback + love.timer.getTime()
			end
		else 
			print("last.fm: Now playing request failed")
			lfmCountDown = 3 + love.timer.getTime()
		end
	else
		print("last.fm: Username is empty")
		lfmCountDown = 1 + love.timer.getTime()
	end
end

function req_echonest(art, son) --requests echonest for bpm and duration of "son" by "art", sets bpm and countdown if found, calls req_lastfm_duration if song or duration not found
	if art ~= "" and son ~= "" then
		isUrlTempo = false
		--art = format_clsscl(art) --breaks "Earth, Wind & Fire" and "Blood, Sweat & Tears"
		--search for song and get id
		echosearch = http.request(string.format("http://developer.echonest.com/api/v4/song/search?api_key=%s&format=json&results=1&artist=%s&title=%s", echonestApi, format_url(art), format_url(son)))
		if echosearch then
			local x, a = string.find(echosearch, '"id": "%w')
			if a then
				local b = string.find(echosearch, '%w",', a)
				trackidstr = echosearch:sub(a,b)
				if #trackidstr == 18 then
					echoprof = http.request(string.format("http://developer.echonest.com/api/v4/song/profile?api_key=%s&format=json&id=%s&bucket=audio_summary", echonestApi, trackidstr)) --get song info from id
					
					--get tempo
					x, a = string.find(echoprof, '"tempo": %d')
					if a then
						b = string.find(echoprof, '%d, "', a)
						bpm = tonumber(echoprof:sub(a,b)) --set global BPM
						
						isUrlTempo = true
						taps = {}
						n = 1
						--get artist name
						x, a = string.find(echoprof, '"artist_name": "%w')
						b = string.find(echoprof, '.", "', a)
						artist = echoprof:sub(a,b)
						--get track name
						x, a = string.find(echoprof, '"title": ".')
						b, x = string.find(echoprof, '."', a)
						song = echoprof:sub(a,b)
						print(string.format("Echonest: Found %.1f BPM", bpm))
					else
						print(echoprof)
						print("Echonest: Couldn't get tempo from song profile")
					end
					--get duration
					x, a = string.find(echoprof, '"duration": %d')
					if a then
						b = string.find(echoprof, '%d, "', a)
						local duration = tonumber(echoprof:sub(a,b))
						if duration > duration_minimum then
							print(string.format("Echonest: Found duration %d s", duration))
							lfmCountDown = duration + love.timer.getTime() --set countdown from duration, add timestamp for difference between realtime
						else
							if not req_lastfm_duration(artist, song) then lfmCountDown = lfmCountDown_fallback + love.timer.getTime() end
						end
					else
						print(string.format("Echonest: Duration not found"))
						if not req_lastfm_duration(artist, song) then lfmCountDown = lfmCountDown_fallback + love.timer.getTime() end
					end
				else
					print(echoprof)
					print(string.format("Echonest: Bad Track ID: %s", trackidstr))
				end
			else
				print(string.format("Echonest: No results for:\n   artist=%s\n   song=%s", format_url(art), format_url(son)))
				if not req_lastfm_duration(artist, song) then lfmCountDown = lfmCountDown_fallback + love.timer.getTime() end
			end
		else print(string.format("Echonest: Couldn't get request"))
		end
	else print("Echonest: Artist or song is empty")
	end
end

function req_lastfm_duration(art, son) --requests last.fm for duration of "son" by "art", returns true if found, returns false if not (or maybe make it set countdown directly instead)
	print(string.format("last.fm: Fetching duration..."))
	local lfmtrack = http.request(string.format("http://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=%s&artist=%s&track=%s", lfmApi, format_url(art), format_url(son)))
	if lfmtrack then
		local x, dura_a = string.find(lfmtrack, '<duration>%d')
		if dura_a then
			local dura_b, x = string.find(lfmtrack, '%d</duration>')
			local duration = lfmtrack:sub(dura_a, dura_b)/1000

			if duration > duration_minimum then
				print(string.format("last.fm: Found duration %d s", duration))
				lfmCountDown = duration + love.timer.getTime() --set countdown from duration, add timestamp for difference between realtime
				return true
			else
				print(string.format("last.fm: Found duration %d s is too short, falling back to %d s", duration, lfmCountDown_fallback))
				return false
				--lfmCountDown = lfmCountDown_fallback + love.timer.getTime()
			end
		else
			print(string.format("last.fm: Duration not found, falling back to %d s", lfmCountDown_fallback))
			return false
			--lfmCountDown = lfmCountDown_fallback + love.timer.getTime()
		end
	else
		print(string.format("last.fm: Track request failed, falling back to %d s", lfmCountDown_fallback))
		return false
		--lfmCountDown = lfmCountDown_fallback + love.timer.getTime()
	end
end

function format_url(str)
	local strtab = {}
	for code in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		table.insert(strtab, code)
	end
	str = table.concat(strtab)
	
	str = str:gsub("([^A-Za-z0-9_])", function(c)
		return string.format("%%%02x", string.byte(c))
		end)
	str = str:gsub("amp%%3b", "") --"&"
	str = str:gsub("%%26quot%%3b", "%%22") --"""
	return str
end

function format_clsscl(str) --"first, last"->"last, first" (breaks "Earth, Wind & Fire" and "Blood, Sweat & Tears")
	local a, b = str:find("%w, %w")
	if a and b then
		str = str .. " " .. str:sub(1, a)
		str = str:sub(a+3, #str)
	end
	return str
end

function interpolate(zeroval, oneval, frac) --returns interpolation based on range of values from zeroval to oneval multipled by frac (must be 0 - 1)
	if (frac >= 0 and frac <= 1) then
		return ((zeroval)*(1-frac) + (oneval)*(frac))
	else print(string.format("Interpolation function received invalid frac: %f", frac))
	end
end