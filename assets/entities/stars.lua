stars = {}

function star_create()
	table.insert( stars, 
	{ 
		name = 'hotspot',
		x = x, 
		y = y, 
		w = 16, 
		h = 16, 
		pic = love.graphics.newImage( 'fruit.png' ) 
	} )
end

function star_draw()
	for i, v in ipairs( stars ) do
		if stars[i] then
			love.graphics.draw( v.pic, v.x, v.y )
		end
	end
end
