-- helpers
local sti = require "assets.scripts.helpers.sti"
local bump = require "assets.scripts.helpers.bump"
local push = require "assets.scripts.helpers.push"
local anim8 = require "assets.scripts.helpers.anim8"

local inspect = require "assets.scripts.helpers.inspect"

-- push variables
local gameWidth, gameHeight = 160, 144 -- fixed game resolution
local windowWidth, windowHeight = gameWidth * 2, gameHeight * 2

-- bump variables
local cols, player, GRAVITY, map, world
local debug = ""

-- anim8 variables
local image, animation

local currentHealth
local maxHealth = 4

local stars = {}

function love.load()
	
	love.graphics.setDefaultFilter("nearest", "nearest") -- disable blurry scaling
	-- setup game resolution and window size
	push:setupScreen(gameWidth, gameHeight, windowWidth, windowHeight, {fullscreen = false, resizable = true})
	
	-- background colour (replace with image layer?)
	love.graphics.setBackgroundColor(205, 234, 127)
	
	-- Load map
	map = sti.new("assets/maps/Map.lua", { "bump" })

	-- set physics meter (in pixels)
	world = bump.newWorld(16)
	
	-- initialise physics objects (existing layers flagged as 'collidable' are recognised)
	map:bump_init(world)

	-- Add a Custom Layer to hold entities
	local spriteLayer = map:addCustomLayer("Sprite Layer")

	
	image = love.graphics.newImage("assets/entities/sprite.png")
	-- Add Custom Data to layer (e.g. player data)
	spriteLayer.player = {

		--sprite = sprite,
		x = 40,
		y = 30,
		w = 32,
		h = 32,
		xvel = 0,
		yvel = 0,
		speed = 100,
		maxVelocityX = 200,
		maxVelocityY = 64,
		direction = 1,
		grounded = false
	}

	currentHealth = maxHealth

	-- manually created object
	tree = {
	name = 'spring',
      x = 32, 
      y = 100,
      w = 32,
      h = 32,
   --   properties = { spring = 'true'}
   }

   -- manually created object
	hotspot = {
		name = 'hotspot',
      x = 120, 
      y = 90,
      width = 32,
      height = 32,
    --  properties = { hotspot = 'true'}
   }

 -- Get the spring object exported by Tiled
    local spring
    for k, object in pairs(map.objects) do
        if object.name == "spring" then
            spring = object
            break
        end
    end
   
    -- create a spring object
   spriteLayer.spring = {
   		image = love.graphics.newImage("assets/entities/sprite.png"),
   		name = spring.name,
        x   = spring.x,
        y 	= spring.y,
        w 	= 32,
       	h   = 32,
      --	properties = {spring = 'true'}
    }
		--print("object name: " .. spring.name)
								-- frame width, frame height, image width, image height
		local g = anim8.newGrid(32, 32, image:getWidth(), image:getHeight())

								--type  --frames --row --default delay
		idleright = anim8.newAnimation(g('1-1',1), 0.05)
		idleleft = anim8.newAnimation(g('1-1',1),0.05):flipH()
		walkright = anim8.newAnimation(g('2-9',1), 0.05)
		walkleft = anim8.newAnimation(g('2-9',1), 0.05):flipH()

		animation = idleright

	-- store a reference to the player object for use later
	player = map.layers["Sprite Layer"].player
	spring = map.layers["Sprite Layer"].spring

	-- set gravity and add the player to the physics world
	GRAVITY = 9.8
	world:add(player, player.x, player.y, player.w, player.h)
	world:add(tree, tree.x, tree.y, tree.w, tree.h)
	world:add(hotspot, hotspot.x, hotspot.y, hotspot.height, hotspot.width)
	world:add(spring, spring.x, spring.y, spring.h, spring.w)

	healthHeart = love.graphics.newImage("assets/gui/Heart.png")

	font = love.graphics.setNewFont("assets/gui/early gameboy.ttf", 8 )
	text = "You are loved"

	for i=1, 5 do
		star = star_create( math.random( 50, 100 ), math.random( 50, 100 ) )
		world:add(star, star.x, star.y, star.h, star.w)
	end
end

function love.update(dt)

	map:update(dt)
	animation:update(dt)

	-- detect player inputs
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
		animation = walkright
		player.xvel = player.xvel + player.speed
		player.direction = 1
		if player.direction == -1 then
			player.xvel = 0
		end
	elseif love.keyboard.isDown("a") or love.keyboard.isDown("left") then
		animation = walkleft
		player.xvel = player.xvel + player.speed
		player.direction = -1
		if player.direction == 1 then
			player.xvel = 0
		end
	end



	-- ensure the player x velocity is always negated when no input (otherwise sliding!!) and is affected by gravity
	player.xvel = player.xvel - 50
	player.yvel = player.yvel + GRAVITY


	-- stop the player gaining too much momentum
	if player.xvel > player.maxVelocityX then 
		player.xvel = player.maxVelocityX 
	end

	-- if player velocity is less than zero, then set to no velocity
	if player.xvel < 0 then
		player.xvel = 0
		if player.direction == 1 then
			animation = idleright
		else
			animation = idleleft
		end
	end

	-- update players x and y with the velocity and direction
	player.x = player.x + player.direction * player.xvel * dt
	player.y = player.y + (player.yvel) * dt

	-- override playerFilter function
	local playerFilter = function(item, other)
	
		local kind

		-- if the object of the collision has a properties table 
		-- (ie. it's been exported from Tiled with the collidable custom property)
		if other.properties ~= nil then
			kind = other.properties -- store a reference to the properties table to use 
		else
			kind = other.name -- store a reference to the object's name since it has no properties table
		end
	
		if kind.collidable then -- if object.properties table has the collidable element
			return 'slide'
		elseif kind == 'spring' then -- if object.name is spring
			return 'bounce'
		elseif kind == 'hotspot' then -- if object.name is hotspot
			return 'cross'
		end
	end -- end of playerFilter function

	-- actually move the player, obeying collisons
	player.x, player.y, cols, len = world:move(player, player.x, player.y, playerFilter)


	for i=1,len do
    	
    	local other = cols[i].other
    	if other.name  == 'hotspot' then
      		currentHealth = currentHealth + 1
      		--world:remove(other) -- remove the collidable
      		star_destroy(other)
      		print('collided with ' .. tostring(cols[i].other.name) .. currentHealth)
      	elseif other.name == 'spring' then
      		currentHealth = currentHealth - 1
      		print('collided with ' .. tostring(cols[i].other.name) .. currentHealth)
    	end
  	end

  	
--[[

FIGURE THIS OUT

If you are doing a platformer, you should also know that setting the yvel in all types 
of collision is not a good idea. Instead, you should set it only when the collision is 
"with something that is below", like a floor tile, but not when you collide with 
"something to the right or left", like a wall. The way to do this is using the collision normal, 
which bump puts in cols[i].normal.y. A collision with a floor is usually happening when that 
value is < 0.

]]
	-- check collision normals to only adjust xvel and yvel
	for i,v in ipairs(cols) do
		
		-- if normal is negative (ie. we've hit something) and the collision type
		-- isn't 'cross' (ie. a hotspot) reset the y velocity to stop falling
		if cols[i].normal.y == -1 and cols[i].type ~= "cross" then
			player.yvel = 0
			player.grounded = true
			debug = debug .. "Collided"
		
		-- otherwise if normal is positive (still falling) and we haven't encountered
		-- a collision of type 'cross' (ie. a hotspot) keep decreasing y velocity
		elseif cols[i].normal.y == 1 and cols[i].type ~= "cross" then
			player.yvel = -player.yvel/4
			player.grounded = false
		end
		
		
		if cols[i].type ~= "cross" and cols[i].normal.x ~= 0 then
			player.xvel = 0
		end
	end
end


-- detect the key press for jumping
function love.keypressed(key)
   if (key == "space" or key == "up") and player.grounded then

     	player.yvel = player.yvel - 200 -- this is your jump juice
		player.grounded = false
		debug = debug .. " Jumped "
   end

end


function love.draw()
	-- start the scaling operations
	push:apply("start")

 		-- Translate world so that player is always centred
		local player = map.layers["Sprite Layer"].player
		love.graphics.translate( -player.x + gameWidth / 2, -player.y + gameHeight / 2)
	    		
		-- Draw world and cull tiles off screen using DrawRange
		map:setDrawRange(0,0,love.graphics.getWidth(),love.graphics.getHeight())
    	map:draw()
    
    love.graphics.push()
    	love.graphics.setColor(0, 125, 255)
   		love.graphics.rectangle("fill", tree.x, tree.y, tree.w, tree.h)
   		love.graphics.rectangle("fill", hotspot.x, hotspot.y, hotspot.width, hotspot.height)
   	love.graphics.pop()

   	love.graphics.setColor(255, 255, 255)
    	-- Draw Player character
    	animation:draw(image, math.floor(player.x), math.floor(player.y))
    	--love.graphics.draw(player.sprite, math.floor(player.x), math.floor(player.y), 0, 1, 1)

    	local spring = map.layers["Sprite Layer"].spring
    	love.graphics.rectangle("fill", spring.x, spring.y, spring.w, spring.h)

    	star_draw()
    	-- show collision boxes for debugging
    	love.graphics.setColor(255,255,0,255)
    	map:bump_draw(world)
	
	 	imageX = 200
    	imageY = 100
    	imageHeight = 50
    	imageWidth = 50
		love.graphics.printf(text, imageX, imageY + imageHeight/2, imageWidth, "center")

	-- stop the scaling operations
	push:apply("end")

	for i=1, currentHealth do
		local w = healthHeart:getWidth()
		love.graphics.draw(healthHeart, w * i, 20)
	end

	-- Debug info
    love.graphics.setColor(255,255,255,255)
    love.graphics.print("yvel: " .. math.floor(player.yvel),0,0)
    love.graphics.print("grounded: " .. tostring(player.grounded),0,15)
    love.graphics.print("x: " .. math.floor(player.x),0,30)
    love.graphics.print("y: " .. math.floor(player.y),0,50)
    love.graphics.print("health: " .. currentHealth, 0, 80)


end


function star_create(x, y)
	star = { 
		name = 'hotspot',
		index = #stars + 1,
		x = x, 
		y = y, 
		w = 16, 
		h = 16, 
		pic = love.graphics.newImage( 'assets/entities/fruit.png' ) 
	} 

	table.insert( stars, star)
	print(#stars)

	return star
end

function star_draw()
	for i, v in ipairs( stars ) do
		if stars[i] then
			love.graphics.draw( v.pic, v.x, v.y )
		end
	end
end

function star_destroy(star)

	table.remove(stars, star.index)
	world:remove(star)
end


function love.resize(w, h)
	-- these are used to resize the map and the screen correctly
	map:resize(w, h)
  	push:resize(w,h)
end
