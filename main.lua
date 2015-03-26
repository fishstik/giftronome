function love.load() --TODO: Automatically determine if the gif is dark or light (using ImageData:getPixel)
	--love2d shortcuts
		gfx = love.graphics
		filesys = love.filesystem
		keybd = love.keyboard


	socket = require "socket"
	http = require "socket.http"
	--winapi = require "winapi"
	require "apis"
	require "vars"

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