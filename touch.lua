function love.touchpressed(id, mx, my, pressure)
	--print(string.format("touchpressed\n mx: %f\n my: %f\n", mx, my))
	touchpressed = true
	touchreleased = false


	--if touchpressed while flying out
		if thread_changeImgAnim and coroutine.status(thread_changeImgAnim) == 'suspended' then
			while(coroutine.status(thread_changeImgAnim) == 'suspended') do 
				coroutine.resume(thread_changeImgAnim)
			end
			love.update(0.3)
		end

	--if touchpressed while flying back
		if thread_keepImgAnim and coroutine.status(thread_keepImgAnim) == 'suspended' then
			while(coroutine.status(thread_keepImgAnim) == 'suspended') do 
				coroutine.resume(thread_keepImgAnim)
			end
			love.update(0.3)
		end
end

function love.touchmoved(id, mx, my, pressure)
	--print(string.format("touchmoved\n mx: %f\n my: %f\n", mx, my))
	touchmoved = true

	--get initial mx and calculate horizontal distance to current mx. touchreleased resets initial mx
	if not x_init then
		x_init = mx
	else
		xdiff = (mx - x_init) * swidth --xdiff = pixels dragged. positive = right, negative = left
		dragScale = math.abs(xdiff)/swidth --dragScale = normalized magnitude of xdiff

		if (xdiff < 0) then --dragging left

			image_x = xdiff --image follows cursor
			--zoom and fade in preview image
				if (image_bottom) then
					image_bottom_brightness = greyLevel_fadeMax * dragScale
					image_bottom_scaleY = interpolate(image_bottom_fadeScaleMin, image_bottom_fadeScaleMax, dragScale) * sheight/image_bottom:getHeight()
					image_bottom_y = (sheight - image_bottom:getHeight()*image_bottom_scaleY)/2
				end

			--set right image to bottom
				if select == #folders then select_bottom = 1
				else select_bottom = select+1 end

			--if dragged right before, undo the swap
				if (not swapImages_enabled and unswapImages_enabled) then --do only once
					swapImages_enabled = true
					unswapImages_enabled = false

					--restore state pre-drag-right
						select = select_bottom
						if select_bottom == #folders then select_bottom = 1
						else select_bottom = select_bottom+1 end

					if (image_bottom) then
						image_scaleY = sheight/image_bottom:getHeight()
					end					
					love.update(0.3)					
				end
		else --dragging right
			-- swap the images
				if (not unswapImages_enabled and swapImages_enabled) then --do only once
					swapImages_enabled = false
					unswapImages_enabled = true

					--move top to bottom, set left image to top
						select_bottom = select
						if select == 1 then select = #folders
						else select = select-1 end
						n = 1
					love.update(0.3)
				end

			-- zoom & fade out bottom, slide top from left
				if (image_bottom) then
					image_bottom_brightness = 255 * (1-dragScale)
					image_bottom_scaleY = interpolate(1, image_bottom_fadeScaleMin-image_bottom_fadeOutAdjust, dragScale) * sheight/image_bottom:getHeight()
					if image then
						image_scaleY = sheight/image:getHeight()
						image_x = -swidth-math.max(0,(image:getWidth()*image_scaleY-swidth)/2)+xdiff
					end
					image_bottom_y = (sheight - image_bottom:getHeight()*image_bottom_scaleY)/2
				end
			end
	end
end

function love.touchreleased(id, mx, my, pressure)
	--print(string.format("touchreleased\n mx: %f\n my: %f\n", mx, my))
	touchreleased = true
	touchpressed = false
	touchmoved = false
	swapImages_enabled = true
	unswapImages_enabled = false

	if (xdiff) then
		if (math.abs(xdiff) > swipeDist) then --change image
			if xdiff > 0 then
				--go left one image
				thread_changeImgAnim = coroutine.create(flyin)
			else
				--go right one image
				thread_changeImgAnim = coroutine.create(flyout)
			end
		else --don't change image
			if xdiff > 0 then
				--zoom back in
				thread_keepImgAnim = coroutine.create(zoomback)
			else 
				--return image to center
				thread_keepImgAnim = coroutine.create(flyback)
			end
		end
		love.update(.03)
		x_init = nil
	end
end