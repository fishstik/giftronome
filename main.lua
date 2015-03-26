function love.load()
	--love2d shortcuts
		gfx = love.graphics
		filesys = love.filesystem
		keybd = love.keyboard

	socket = require "socket"
	http = require "socket.http"
	utf8_validator = require "utf8_validator"
	require "vars"
	require "apis"
	require "coroutines"
	require "touch"

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

function interpolate(zeroval, oneval, frac) --returns interpolation based on range of values from zeroval to oneval multipled by frac (must be 0 - 1)
	if (frac >= 0 and frac <= 1) then
		return ((zeroval)*(1-frac) + (oneval)*(frac))
	else print(string.format("Interpolation function received invalid frac: %f", frac))
	end
end