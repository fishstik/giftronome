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