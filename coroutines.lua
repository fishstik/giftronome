function zoomback() --coroutine to zoom back image to full-screen. also flies out preview image
	local image_bottom_scaleY_init = image_bottom_scaleY
	local image_bottom_scaleY_target = sheight/image_bottom:getHeight()
	local image_bottom_brightness_init = image_bottom_brightness

	while (image_bottom_scaleY < image_bottom_scaleY_target) do
		
		local progress = (image_bottom_scaleY - image_bottom_scaleY_init)/(image_bottom_scaleY_target - image_bottom_scaleY_init)
		if (progress > 0.9) then progress = 1 end --make it actually go to 1

		local easeAmount = (1-progress)*3
		if progress == 1 then easeAmount = 0.3 end

		--zoom and fade in image_bottom based on thread progress
			image_bottom_scaleY = image_bottom_scaleY + image_bottom_fadeScaleSpeed*easeAmount
			image_bottom_y = (sheight - image_bottom:getHeight()*image_bottom_scaleY)/2
			--interpolation:          [v-- start value                              v-- end value  ]
			image_bottom_brightness = (image_bottom_brightness_init*(1-progress) + (255)*(progress))

		--fly out preview image (top)                                                         ]
			image_x = interpolate(-swidth+xdiff, -swidth-math.max(0,(image:getWidth()*image_scaleY-swidth)/2), progress)

		coroutine.yield()
	end
	--restore state pre-drag-right
		select = select_bottom
		if select_bottom == #folders then select_bottom = 1
		else select_bottom = select_bottom+1 end

	image_bottom_brightness = 0
	image_x = swidth/2-image:getWidth()*image_scaleY/2 - (swidth-image:getWidth()*image_scaleY)/2
	image_y = 0
	xdiff = nil
end

function flyback() --coroutine to fly image back to center. also fades out preview image
	local image_bottom_scaleY_init = interpolate(image_bottom_fadeScaleMin, image_bottom_fadeScaleMax, dragScale)

	while (image_x < 0) do
		local progress = 1-math.abs(image_x/xdiff) --progress = fraction of flyback completed (0 -> approaching 1)
		if (progress > 0.9) then progress = 1 end --make it actually go to 1

		--fly back image
			local easeAmount = (1-progress)*3
			if progress == 1 then easeAmount = 0.3 end

			image_x = image_x + flybackSpeed*easeAmount

		--fade out image_bottom based on thread progress
			image_bottom_brightness = greyLevel_fadeMax * dragScale * (1-progress)
			image_bottom_scaleY = interpolate(image_bottom_scaleY_init, image_bottom_fadeScaleMin, progress) * sheight/image_bottom:getHeight()
			image_bottom_y = (sheight - image_bottom:getHeight()*image_bottom_scaleY)/2

		coroutine.yield()
	end
	image_bottom_brightness = 0
	image_x = 0
	xdiff = nil
end

function flyin() --coroutine to fly image in from the left. also fades out old image
	local image_bottom_scaleY_init = interpolate(1, image_bottom_fadeScaleMin-image_bottom_fadeOutAdjust, dragScale)
	local image_x_center_init = math.abs(image_x+(swidth-image:getWidth()*image_scaleY)/2)
	local image_x_center_target = swidth/2-image:getWidth()*image_scaleY/2

	while (image_x+(swidth-image:getWidth()*image_scaleY)/2 < image_x_center_target) do
		--progress = fraction of flyin completed (0 -> approaching 1)
		local progress = 1 - math.abs((image_x_center_target-(image_x+(swidth-image:getWidth()*image_scaleY)/2))) / (image_x_center_init+image_x_center_target)
		if (progress > 0.9) then progress = 1 end --make it actually go to 1
		
		--fly in image
			local easeAmount = (1-progress)*3
			if progress == 1 then easeAmount = 0.3 end
			image_x = image_x + flyoutSpeed*easeAmount

		--fade out image_bottom based on thread progress
			image_bottom_brightness = 255 * (1-dragScale) * (1-progress)
			image_bottom_scaleY = interpolate(image_bottom_scaleY_init, image_bottom_fadeScaleMin, progress) * sheight/image_bottom:getHeight()
			image_bottom_y = (sheight - image_bottom:getHeight()*image_bottom_scaleY)/2

		coroutine.yield()
	end
	image_x = 0
	image_y = 0
	xdiff = nil
end

function flyout() --coroutine to fly image out to the left. also fades in next image
	local extra_width = swidth/3 --number of pixels to keep on flying even after right edge is < 0. used for smoother fade-in image_bottom
	local image_bottom_scaleY_init = interpolate(image_bottom_fadeScaleMin, image_bottom_fadeScaleMax, dragScale)
	local image_x_plus_width_scaled_init = (image_x+image:getWidth()*image_scaleY+(swidth-image:getWidth()*image_scaleY)/2)+extra_width

	while (image_x + image:getWidth()*image_scaleY + (swidth-image:getWidth()*image_scaleY)/2 + extra_width > 0) do
		--progress = fraction of flyback completed (0 -> approaching 1)
		local progress = (image_x_plus_width_scaled_init - (image_x+image:getWidth()*image_scaleY+(swidth-image:getWidth()*image_scaleY)/2+extra_width)) / image_x_plus_width_scaled_init

		--fly out image
			image_x = image_x - flyoutSpeed

		--fade in image_bottom based on thread progress
			local progress_cubedroot = progress^(1/3)

			image_bottom_brightness = 255 * math.min((dragScale+progress),1)
			image_bottom_scaleY = interpolate(image_bottom_scaleY_init, 1, progress_cubedroot) * sheight/image_bottom:getHeight()
			image_bottom_y = (sheight - image_bottom:getHeight()*image_bottom_scaleY)/2

		coroutine.yield()
	end
	if select == #folders then select = 1
	else select = select + 1 end
	n = 1
	image_x = 0
	image_y = 0
	xdiff = nil
end