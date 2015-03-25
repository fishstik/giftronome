socket = require "socket"
http = require "socket.http"
--winapi = require "winapi"

--love2d shortcuts
	gfx = love.graphics
	filesys = love.filesystem
	keybd = love.keyboard

--configuration vars
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

--nonconfiguration vars
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

function love.load() --TODO: Automatically determine if the gif is dark or light (using ImageData:getPixel)
	--retrieve gifs and config files
		local files = {}
		local frames = {}
		local grabframes = true

		files = filesys.getDirectoryItems("gifs/")
		for i = 1, #files, 1 do
			local fileext = tostring(files[i]:match("[^.]+.(.+)")) --extract file extension
			
			if fileext == "gif" then
				print(string.format("Found gif %s", files[i]))
				local filename = string.sub(files[i], 1, -5) --without extension

				frames = filesys.getDirectoryItems("frames/"..filename) --check if frames already exist
				if #frames == 0 then --if they don't, explode
					print("Frames not found. Exploding...")
					os.execute("gifexpl "..files[i]) --explode gif to tmp

					frames = filesys.getDirectoryItems("frames/"..filename)
					if #frames == 0 then
						print("ERROR: No frames exploded. Skipping "..files[i])
						grabframes = false
					end
				else --if frames found, skip explosion and grab them
					print("Frames found. Skipping explosion.")
				end

				--Grab frames and add to database
				if grabframes then
					gifcount = gifcount + 1
					imagenames[gifcount] = filename
					images[gifcount] = {}
					div[gifcount] = 1
					light[gifcount] = false

					for k = 1, #frames, 1 do
						images[gifcount][k] = gfx.newImage(string.format("frames/%s/%s", filename, frames[k])) --collect image file
					end
				end
			elseif fileext == "txt" then
				print("Found txt "..files[i])
				--open config txt file
				local config = filesys.read("gifs/"..files[i])
				div[gifcount] = config:match("div=+(%d+)[\r\n]?") --look for 'div' parameter in config txt
				light[gifcount] = config:match("light=+(%l+)[\r\n]?") == "true" --look for 'light' parameter in config txt
			else
				print("Ignoring file "..files[i])
			end
		end

	--load initial image, get dimensions, set window
		image = images[select][n]
		swidth = zoom*image:getWidth() 
		sheight = zoom*image:getHeight()
		love.window.setMode(swidth, sheight, {borderless=borderless, resizable=resizable})
	
	keybd.setKeyRepeat(true)
end

function love.draw()
	width, height, windowflags = love.window.getMode()

	--draw image
		if image then
			gfx.setColor(white)
			gfx.draw(image, 0, 0, 0, width/image:getWidth(), height/image:getHeight())
		end

	--draw text
		maincolor = white
		if light[select] == true then maincolor = black end
		gfx.setColor(maincolor)

		if isUrlTempo then gfx.setColor(cyan) end
		gfx.print(string.format("%.1f bpm", bpm), 0, 0)

		if inputMode_artist then gfx.setColor(red) end
		if isUrlTempo then gfx.setColor(cyan) end
		gfx.print(string.format("artist: [%s]", artist), 0, 30)

		gfx.setColor(maincolor)
		if inputMode_song then gfx.setColor(red) end
		if isUrlTempo then gfx.setColor(cyan) end
		gfx.print(string.format("song: [%s]", song), 0, 45)

		gfx.setColor(maincolor)

		gfx.print("H: show/hide controls", 0, 75)
		if (showHelp) then
			gfx.print("esc: exit", 0, 90)
			gfx.print("[/]: adjust BPM", 0, 105)
			gfx.print("</>: halve/double BPM", 0, 120)
			gfx.print("space: tap BPM", 0, 135)
			gfx.print("{/}: adjust countdown", 0, 150)
			gfx.print("R: jump to frame 1", 0, 165)
			gfx.print("up/down: zoom", 0, 180)
			gfx.print("left/right: switch GIFs", 0, 195)
			gfx.print("enter: input artist & song", 0, 210)
			gfx.print("L: input last.fm user", 0, 225)
			gfx.print("W: fetch last.fm playing", 0, 240)
			--gfx.print("A/D: seek WPM", 0, 255)
			--gfx.print("S: play/pause WMP", 0, 270)
			
		end
		
		if inputMode_lfm then gfx.setColor(red)	end
		gfx.print(string.format("last.fm user: [%s]", lfmUser), 0, sheight-45)

		gfx.setColor(maincolor)
		local lfmcountdownprint = lfmCountDown - love.timer.getTime()
		if paused then lfmcountdownprint = lfmcountdownprint + (love.timer.getTime() - time_paused) end
		gfx.print(string.format("next fetch in %d:%02d", math.floor(lfmcountdownprint/60), math.floor(lfmcountdownprint % 60)), 0, sheight-30)
		gfx.print(string.format("%d/%d: %s.%d", select, gifcount, imagenames[select], n), 0, sheight-15)
end
	
function love.update(dt)
	if paused then return end

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
	--capture keys of length 1 if input mode is active
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
					select = gifcount
				else
					select = select - 1
				end
				n = 1
				swidth = zoom*images[select][n]:getWidth()
				sheight = zoom*images[select][n]:getHeight()
				love.window.setMode(swidth, sheight, {borderless=borderless, resizable=resizable, display=windowflags["display"]})
			end
			if key == "right" then
				if select == gifcount then
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
			-- if key == "s" then
			-- 	local wmpwindow = winapi.find_window("WMPlayerApp")
			-- 	wmpwindow:send_message(273, 18808, 0) -- WMP Pause

			-- 	if not paused then
			-- 		time_paused = love.timer.getTime()
			-- 		paused = true
			-- 	else
			-- 		lfmCountDown = lfmCountDown + love.timer.getTime() - time_paused --adjust countdown for paused time
			-- 		time_paused = 0
			-- 		paused = false
			-- 	end
			-- end
			-- if key == "d" then
			-- 	local wmpwindow = winapi.find_window("WMPlayerApp")
			-- 	wmpwindow:send_message(273, 18811, 0) -- WMP Next
			-- 	delayedFetchEnabled = true
			-- end
			if key == "audioplay" then
				if not paused then
					time_paused = love.timer.getTime()
					paused = true
				else
					lfmCountDown = lfmCountDown + love.timer.getTime() - time_paused --adjust countdown for paused time
					time_paused = 0
					paused = false
				end
			end
			if key == "audioprev" or key == "audionext" then
				delayedFetchEnabled = true
			end
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
						local bpmi = -60/(tap1-tap2)
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
		local lfm = http.request(string.format("http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&limit=1&user=%s&api_key=%s", lfmUser, lfmApi))
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
		lfmCountDown = lfmCountDown_fallback + love.timer.getTime()
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

-- function req_wmp() --requests open WMP window for artist and song, calls req_echonest if found (only works if "Title - Artist" is in window title) (can continuously poll)
-- 	local disable = false
-- 	local wmpwindow = winapi.find_window("WMPlayerApp")
-- 	local wmptitle = tostring(wmpwindow)
-- 	wmptitle = winapi.encode(winapi.CP_ACP, winapi.CP_UTF8, wmptitle)

-- 	if wmptitle ~= wmptitle_old then
-- 		wmptitle_old = wmptitle
-- 	else disable = true
-- 	end
-- 	local x, b = wmptitle:find(".* %- ")
-- 	if b and not disable then
-- 		song = wmptitle:sub(1, b-3)
-- 		local a = song:find("feat.")
-- 		if a then song = song:sub(1, a-3) end

-- 		artist = wmptitle:sub(b+1, #wmptitle)
-- 		artist = format_clsscl(artist)

-- 		print("WMP: Found now playing:\n   artist=%s\n   song=%s", artist, song)

-- 		req_echonest(artist, song) --echonest call
-- 	end
-- end

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