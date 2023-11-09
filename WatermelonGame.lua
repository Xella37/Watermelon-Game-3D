
local COMBINE_COOLDOWN = 150 -- ms
local GLOBAL_FRUIT_SCALE = 1.08

local MAX_PHYSICS_DT = 50 -- ms
local MIN_PHYSICS_STEPS = 2
local MAX_PHYSICS_STEPS = 16

local MAX_IMPULSE = 0.02
local MAX_DPOS = 0.02 -- meters
local MAX_DPOS_RESOLVE = 0.01 -- max distance to move when resolving collisions in meters
local MAX_SPEED = 1.5 -- m/s
local GAMEOVER_SPAWN_COOLDOWN = 250 -- ms

local MAX_CAMERA_ZOOM = 3
local MIN_CAMERA_ZOOM = 0.5


local cameraZoom = 1

term.setBackgroundColor(colors.blue)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Welcome to Watermelon Game 3D!")
print("Combine fruits to get larger ones, get the watermelon!")
print("\nControls:")
print("1, 2, 3, 4, 5 (default): select render quality")
print("W/A/S/D: rotate camera")
print("Arrow keys: move around cursor")
print("TAB: toggle auto-rotate")
print("Mouse dragging: move around cursor")
print("SPACEBAR: drop fruit")
print("\nPress enter to continue...")
read()

local PW = require("PineWorks")

---@class FruitKind
---@field index number
---@field color number
---@field topColor number
---@field size number
---@field model Model?
---@field colorsFractal boolean?
---@field colors number[]?
---@field mainColor number
---@field bgColor number
---@field arrowColor number?

---@type FruitKind[]
local fruitKinds = {
	{
		index = 1, -- strawberry
		name = "Strawberry",
		color = colors.red,
		topColor = colors.lime,
		size = 0.15 * GLOBAL_FRUIT_SCALE,
		score = 0,
		colors = {colors.lime, colors.red, colors.red},

		mainColor = colors.lime,
		bgColor = colors.red,
		arrowColor = colors.red,
	},
	{
		index = 2, -- grape
		name = "Grape",
		color = colors.purple,
		topColor = colors.purple,
		size = 0.2 * GLOBAL_FRUIT_SCALE,
		score = 2,
		colorsFractal = true,
		colors = {colors.purple, colors.magenta},

		mainColor = colors.pink,
		bgColor = colors.purple,
		arrowColor = colors.pink,
	},
	{
		index = 3, -- orange
		name = "Orange",
		color = colors.orange,
		topColor = colors.orange,
		size = 0.32 * GLOBAL_FRUIT_SCALE,
		score = 4,

		mainColor = colors.black,
		bgColor = colors.orange,
		arrowColor = colors.yellow,
	},
	{
		index = 4, -- apple
		name = "Apple",
		color = colors.red,
		topColor = colors.red,
		size = 0.4 * GLOBAL_FRUIT_SCALE,
		score = 6,
		model = PW.model("models/apple.stab", { skipNormalize = true }):normalizeScale():scale(GLOBAL_FRUIT_SCALE * 0.4 * 0.5):scale(1.35),

		mainColor = colors.red,
		bgColor = colors.lime,
	},
	{
		index = 5, -- peach
		name = "Peach",
		color = colors.pink,
		topColor = colors.pink,
		size = 0.45 * GLOBAL_FRUIT_SCALE,
		score = 8,
		model = PW.model("models/peach.stab", { skipNormalize = true }):normalizeScale():scale(GLOBAL_FRUIT_SCALE * 0.45 * 0.5):scale(1.35),

		mainColor = colors.purple,
		bgColor = colors.pink,
	},
	{
		index = 6, -- coconut
		name = "Coconut",
		color = colors.brown,
		topColor = colors.brown,
		size = 0.55 * GLOBAL_FRUIT_SCALE,
		score = 10,
		model = PW.model("models/coconut.stab", { skipNormalize = true }):center():normalizeScale():scale(GLOBAL_FRUIT_SCALE * 0.55 * 0.5):scale(1.05),

		mainColor = colors.white,
		bgColor = colors.brown,
	},
	{
		index = 7, -- pineapple
		name = "Pineapple",
		color = colors.yellow,
		topColor = colors.yellow,
		size = 0.6 * GLOBAL_FRUIT_SCALE,
		score = 12,
		colorsFractal = true,
		colors = {colors.orange, colors.yellow},
		model = PW.model("models/pineapple.stab", { skipNormalize = true }):scale(GLOBAL_FRUIT_SCALE * 0.6 * 0.5):scale(1.05),

		mainColor = colors.orange,
		bgColor = colors.black,
	},
	{
		index = 8, -- watermelon
		name = "Watermelon",
		color = colors.green,
		topColor = colors.green,
		size = 0.7 * GLOBAL_FRUIT_SCALE,
		score = 14,
		model = PW.model("models/watermelon.stab", { skipNormalize = true }):center():normalizeScale():scale(0.7 * 0.5):scale(1.15),

		mainColor = colors.black,
		bgColor = colors.lime,
	},
}

local scene = PW.newScene("main")
PW.frame:setBackgroundColor(colors.green)

local gameover = false
local gameoverTime = os.epoch("utc")
math.randomseed(gameoverTime)

local renderQuality = 5
local score = 0
local scoreText = scene.hud:addText("Score: 0", 2, 2, colors.white, colors.green)
local highscoreText = scene.hud:addText("", 2, 3, colors.white, colors.green)
local fruitWindow = scene.hud:addWindow(2, 4, 10, #fruitKinds).win
fruitWindow.setBackgroundColor(colors.brown)
fruitWindow.clear()
for i = 1, #fruitKinds do
	local kind = fruitKinds[i]
	fruitWindow.setCursorPos(1, i)
	fruitWindow.setTextColor(kind.mainColor)
	fruitWindow.setBackgroundColor(kind.bgColor)
	fruitWindow.clearLine()
	fruitWindow.setCursorPos(1, i)
	fruitWindow.write(kind.name)
end
local arrowLeft = scene.hud:addText(string.char(0x1A), 1, 4, colors.white, colors.green)
local arrowRight = scene.hud:addText(string.char(0x1B), 12, 4, colors.white, colors.green)

local function updateNextArrows(index)
	local kind = fruitKinds[index]
	local color = kind.arrowColor or kind.bgColor

	arrowLeft.win.setTextColor(color)
	arrowLeft:setStr(string.char(0x1A))
	arrowLeft:setPos(1, index + 3)

	arrowRight.win.setTextColor(color)
	arrowRight:setStr(string.char(0x1B))
	arrowRight:setPos(12, index + 3)
end

---@type Fruit[]
local fruits = {}

local playerData = {
	highscore = 0,
	playcount = 0,
}
if fs.exists("playerdata.json") then
	local file = fs.open("playerdata.json", "r")
	if file then
		local raw = file:readAll()
		if raw then
			local parsed = textutils.unserialiseJSON(raw)
			if parsed then
				playerData = parsed
			end
		end
		file.close()
	end
end
local function savePlayerdata()
	local file = fs.open("playerdata.json", "w")
	if file then
		file.write(textutils.serialiseJSON(playerData))
		file.close()
	end
end

local function buildEnvironment()
	scene:clearEnvironment()

	-- scene:addEnv(PW.modelGen:plane({
	-- 	size = 100,
	-- 	y = -0.1,
	-- 	color = colors.green,
	-- }))

	scene:addEnv(PW.modelGen:cube({
		top = colors.lightBlue,
		bottom = colors.blue,
		side = colors.cyan,
	}):invertTriangles():alignBottom(), 0, 0, 0)

	if renderQuality <= 2 then
		return
	end

	local clothBuilder = PW.meshBuilders.floorTiles()
	for x = -4, 4 do
		for z = -4, 4 do
			local xE = x % 2 == 0
			local zE = z % 2 == 0
			local color = colors.pink
			if xE and zE then
				color = colors.red
			elseif not xE and not zE then
				color = colors.white
			end
			clothBuilder:addTile(x, z, color)
		end
	end
	local clothModel = clothBuilder:buildModel():scale(1)
	for i = 1, #clothModel do
		---@type Polygon
		local poly = clothModel[i]

		---@diagnostic disable-next-line: inject-field
		poly.x1 = poly.x1 + math.sin(poly.z1)*0.125
		---@diagnostic disable-next-line: inject-field
		poly.x2 = poly.x2 + math.sin(poly.z2)*0.125
		---@diagnostic disable-next-line: inject-field
		poly.x3 = poly.x3 + math.sin(poly.z3)*0.125

		---@diagnostic disable-next-line: inject-field
		poly.z1 = poly.z1 + math.cos(poly.x1)*0.125
		---@diagnostic disable-next-line: inject-field
		poly.z2 = poly.z2 + math.cos(poly.x2)*0.125
		---@diagnostic disable-next-line: inject-field
		poly.z3 = poly.z3 + math.cos(poly.x3)*0.125
	end
	scene:addEnv(clothModel, 0, -2, 0)

	local mushroomPath = "models/mushroom_normal.stab"
	if renderQuality <= 3 then
		mushroomPath = "models/mushroom_low.stab"
	end
	local mushroomModel = PW.model(mushroomPath):center():alignBottom():normalizeScaleY():scale(2)
	scene:addEnv(mushroomModel, 5, -2, -2)
	scene:addEnv(mushroomModel, 2, -2, 6)
	scene:addEnv(mushroomModel, -5, -2, -5)

	local grassbladeCount = 60
	if renderQuality >= 5 then
		grassbladeCount = 120
	end
	local grassbladeModel = PW.model("models/grassblade.stab", { skipNormalize = true }):alignBottom():normalizeScaleY():scale(1)
	local grassMesh = {}
	for i = 1, grassbladeCount do
		local x = math.random(-2000, 2000) / 100
		local z = math.random(-2000, 2000) / 100
		if x < -4.5 or x > 4.5 or z < -4.5 or z > 4.5 then
			-- local model = grassbladeModel:rotate(nil, math.random()*math.pi*0.5, nil)
			-- scene:addEnv(model, x, -2, z)
			grassbladeModel = grassbladeModel:rotate(nil, math.random()*math.pi*0.5, nil)
			for i = 1, #grassbladeModel do
				---@type Polygon
				local poly = grassbladeModel[i]
				grassMesh[#grassMesh+1] = {
					x1 = poly.x1 + x,
					y1 = poly.y1,
					z1 = poly.z1 + z,
					x2 = poly.x2 + x,
					y2 = poly.y2,
					z2 = poly.z2 + z,
					x3 = poly.x3 + x,
					y3 = poly.y3,
					z3 = poly.z3 + z,
					c = poly.c,
					---@diagnostic disable-next-line: undefined-field
					forceRender = poly.forceRender,
				}
			end
		end
	end
	local grassObject = scene:addEnv(grassMesh, 0, -2, 0)

	if renderQuality >= 5 then
		-- wind animation

		local model = grassObject.pineObject[7]
		for i = 1, #model do
			local poly = model[i]
			poly.og = {
				poly[1],
				poly[2],
				poly[3],
				poly[4],
				poly[5],
				poly[6],
				poly[7],
				poly[8],
				poly[9],
			}
		end

		local speed = 7
		local intensity = 0.3
		local sin, cos = math.sin, math.cos
		local function applyWind(time, x, y, z)
			local dX = sin(speed * time / 5 + x*0.1) * 0.5 + sin(speed * time / 16 + x*0.1)
			local dZ = cos(speed * time / 7.6) * 0.2
			local heightMult = y^1.5
			return x + dX * heightMult * intensity, y, z + dZ * heightMult * intensity
		end

		grassObject:on("update", function(dt)
			local time = os.epoch("utc") / 1000
			local model = grassObject.pineObject[7]
			for i = 1, #model do
				local poly = model[i]
				poly[1], poly[2], poly[3] = applyWind(time, poly.og[1], poly.og[2], poly.og[3])
				poly[4], poly[5], poly[6] = applyWind(time, poly.og[4], poly.og[5], poly.og[6])
				poly[7], poly[8], poly[9] = applyWind(time, poly.og[7], poly.og[8], poly.og[9])
			end
		end)
	end
end

buildEnvironment()

local function getFruitModel(kind)
	local model = PW.modelGen:icosphere({
		top = kind.topColor,
		color = kind.color,
		colorsFractal = kind.colorsFractal,
		colors = kind.colors,
		res = renderQuality >= 2 and 2 or 1
	}):scale(kind.size)
	if renderQuality == 1 then
		return model:scale(1.1)
	end
	return model
end

---Make a new fruit
---@param kind FruitKind
---@return Fruit
local function makeFruit(kind, x, y, z)
	local model = renderQuality >= 2 and kind.model or getFruitModel(kind)

	local object = scene:add(model, x, y, z)

	---@class Fruit
	local fruit = {
		kindIndex = kind.index,
		size = kind.size,
		physics = {
			vx = 0,
			vy = 0,
			vz = 0,
		},
		object = object,
		model = model,
		spawnTime = os.epoch("utc"),
		fromCursor = false,
	}
	return fruit
end

local cursor = scene:add(PW.modelGen:cube({
	top = colors.red,
	bottom = colors.red,
	side = colors.orange,
}):center():scale(0.15), 0, 1, 0)

local autoRotation = false
local r = 0
local rVertical = math.rad(35)
local rotationSpeed = math.pi*0.5
local function cameraRotation(dt)
	-- local r = os.epoch("utc") / 1000 * 0.3
	if autoRotation or gameover then
		r = r + rotationSpeed*dt * 0.25
	else
		if PW.isDown[keys.a] then
			r = r - rotationSpeed*dt
		end
		if PW.isDown[keys.d] then
			r = r + rotationSpeed*dt
		end
		if PW.isDown[keys.w] then
			rVertical = math.min(math.rad(70), rVertical + rotationSpeed*0.5*dt)
		end
		if PW.isDown[keys.s] then
			rVertical = math.max(math.rad(30), rVertical - rotationSpeed*0.5*dt)
		end
	end

	local distance = 2 * cameraZoom

	local horDistance = math.cos(rVertical) * distance
	local y = math.sin(rVertical) * distance + 0.5

	local x = math.sin(r) * horDistance
	local z = math.cos(r) * horDistance

	-- sideways offset
	local w, h = term.getSize()
	if w <= 61 then
		local sidewaysDistance = 0.15
		x = x + math.sin(r - math.pi*0.5) * sidewaysDistance
		z = z + math.cos(r - math.pi*0.5) * sidewaysDistance
	end

	scene.camera:setPos(x, y, z, nil, -math.deg(r) - 90, -math.deg(rVertical))
end

local nextNextFruitKind = math.random(1, 3)
updateNextArrows(nextNextFruitKind)
local nextFruitKind = math.random(1, 3)
local function updateCursor()
	local kind = fruitKinds[nextFruitKind]
	local newModel = renderQuality >= 2 and kind.model or getFruitModel(kind)
	cursor.pineObject:setModel(newModel)

	local halfSize = kind.size*0.5
	local cursorX = math.min(0.5 - halfSize, math.max(-0.5 + halfSize, cursor.x))
	local cursorZ = math.min(0.5 - halfSize, math.max(-0.5 + halfSize, cursor.z))

	cursor:setPos(cursorX, 1 + halfSize-0.01, cursorZ)
end
updateCursor()

local function refreshFruitModels()
	for i = 1, #fruits do
		local fruit = fruits[i]
		local kind = fruitKinds[fruit.kindIndex]
		---@diagnostic disable-next-line: inject-field
		fruit.model = renderQuality >= 2 and kind.model or getFruitModel(kind)
		fruit.object.pineObject:setModel(fruit.model)
	end

	local kind = fruitKinds[nextFruitKind]
	local model = renderQuality >= 2 and kind.model or getFruitModel(kind)
	cursor.pineObject:setModel(model)
end

local function fruitCollisions(dt)
	for i = 1, #fruits do
		local fruit = fruits[i]
		local p = fruit.physics
		local o = fruit.object

		p.vx = math.min(MAX_SPEED, math.max(-MAX_SPEED, p.vx))
		p.vy = math.min(MAX_SPEED, math.max(-MAX_SPEED, p.vy))
		p.vz = math.min(MAX_SPEED, math.max(-MAX_SPEED, p.vz))

		-- apply speed
		o:setPos(
			o.x + math.min(MAX_DPOS, math.max(-MAX_DPOS, p.vx * dt)),
			o.y + math.min(MAX_DPOS, math.max(-MAX_DPOS, p.vy * dt)),
			o.z + math.min(MAX_DPOS, math.max(-MAX_DPOS, p.vz * dt))
		)

		-- gravity
		p.vy = p.vy - dt * 2

		-- drag
		local w = math.pow(0.5, dt*2)
		p.vx = p.vx * w
		p.vy = p.vy * w
		p.vz = p.vz * w
	end

	---Resolve collisions between fruit
	---@param fruit1 Fruit
	---@param fruit2 Fruit
	---@param d number
	---@param dt number
	local function resolveCollision(fruit1, fruit2, d, dt)
		local penDepth = (fruit1.size + fruit2.size)*0.5 - d

		local weight1 = fruit1.size^3
		local weight2 = fruit2.size^3
		local weightRatio = weight2 / weight1

		local o1 = fruit1.object
		local o2 = fruit2.object
		local p1 = fruit1.physics
		local p2 = fruit2.physics

		local dx = o1.x - o2.x
		local dy = o1.y - o2.y
		local dz = o1.z - o2.z

		local moveScale = penDepth / d

		local moveX = dx * moveScale*0.5
		local moveY = dy * moveScale*0.5
		local moveZ = dz * moveScale*0.5

		o1:setPos(
			o1.x + math.min(MAX_DPOS_RESOLVE, math.max(-MAX_DPOS_RESOLVE, moveX * weightRatio)),
			o1.y + math.min(MAX_DPOS_RESOLVE, math.max(-MAX_DPOS_RESOLVE, moveY * weightRatio)),
			o1.z + math.min(MAX_DPOS_RESOLVE, math.max(-MAX_DPOS_RESOLVE, moveZ * weightRatio))
		)
		o2:setPos(
			o2.x -math.min(MAX_DPOS_RESOLVE, math.max(-MAX_DPOS_RESOLVE,  moveX / weightRatio)),
			o2.y - math.min(MAX_DPOS_RESOLVE, math.max(-MAX_DPOS_RESOLVE, moveY / weightRatio)),
			o2.z - math.min(MAX_DPOS_RESOLVE, math.max(-MAX_DPOS_RESOLVE, moveZ / weightRatio))
		)

		-- p1.vx = p1.vx*0.2^dt + moveX * weightRatio
		-- p1.vy = p1.vy*0.2^dt + moveY * weightRatio
		-- p1.vz = p1.vz*0.2^dt + moveZ * weightRatio

		-- p2.vx = p2.vx*0.2^dt - moveX / weightRatio
		-- p2.vy = p2.vy*0.2^dt - moveY / weightRatio
		-- p2.vz = p2.vz*0.2^dt - moveZ / weightRatio

		local normalX = dx / d
		local normalY = dy / d
		local normalZ = dz / d

		local dVX = p1.vx - p2.vx
		local dVY = p1.vy - p2.vy
		local dVZ = p1.vz - p2.vz

		local separatingV = dVX * normalX + dVY * normalY + dVZ * normalZ
		if separatingV <= 0 then
			local ELASTICITY = 0.8
			local impulse = -(1 + ELASTICITY) * separatingV / (1/weight1 + 1/weight2) --j
			-- if impulse > 0.01 then
			-- 	PW.log("impulse: " .. impulse)
			-- end
			impulse = math.min(impulse, MAX_IMPULSE)
			local impulseX = impulse * normalX
			local impulseY = impulse * normalY
			local impulseZ = impulse * normalZ

			p1.vx = p1.vx + impulseX / weight1
			p1.vy = p1.vy + impulseY / weight1
			p1.vz = p1.vz + impulseZ / weight1

			p2.vx = p2.vx - impulseX / weight2
			p2.vy = p2.vy - impulseY / weight2
			p2.vz = p2.vz - impulseZ / weight2
		end

	end

	local t = os.epoch("utc")
	-- handle collisions
	for i = #fruits, 1, -1 do
		local fruit = fruits[i]
		local o1 = fruit.object
		for j = #fruits, i+1, -1 do
			if i ~= j then
				local fruit2 = fruits[j]
				local o2 = fruit2.object

				local dx = o1.x - o2.x
				local dy = o1.y - o2.y
				local dz = o1.z - o2.z
				local d = (dx*dx + dy*dy + dz*dz)^0.5
				if d <= (fruit.size + fruit2.size)*0.5 then
					if fruit.kindIndex == fruit2.kindIndex and fruit.kindIndex < #fruitKinds and (t > fruit.spawnTime + COMBINE_COOLDOWN or fruit.fromCursor) and (t > fruit2.spawnTime + COMBINE_COOLDOWN or fruit2.fromCursor) then
						local kind = fruitKinds[fruit.kindIndex+1]
						local newX = (fruit.object.x + fruit2.object.x)*0.5
						local newY = (fruit.object.y + fruit2.object.y)*0.5
						local newZ = (fruit.object.z + fruit2.object.z)*0.5
						local newFruit = makeFruit(kind, newX, newY, newZ)
						---@diagnostic disable-next-line: inject-field
						newFruit.physics = {
							vx = (fruit.physics.vx + fruit2.physics.vx)*0.5,
							vy = (fruit.physics.vy + fruit2.physics.vy)*0.5,
							vz = (fruit.physics.vz + fruit2.physics.vz)*0.5,
						}
						if not gameover then
							score = score + kind.score
							scoreText:setStr("Score: " .. score)
						end

						local effect = PW.effects.shrink

						PW.audio.playNote("xylophone", nil, kind.index*2 + 8)
						fruit2.object:remove({effect})
						table.remove(fruits, j)
						fruit.object:remove({effect})
						table.remove(fruits, i)

						fruits[#fruits+1] = newFruit

						break
					else
						resolveCollision(fruit, fruit2, d, dt)
					end
				end
			end
		end
	end

	-- force fruits in play area
	for i = 1, #fruits do
		local fruit = fruits[i]
		local o = fruit.object
		local p = fruit.physics

		local newX = o.x
		local newY = o.y
		local newZ = o.z

		local hSize = fruit.size * 0.5

		if newY < 0 + hSize then
			newY = 0 + hSize
			p.vy = math.abs(p.vy)*0.5
			-- p.vy = 0
		end

		if newY >= 1 + hSize and t >= fruit.spawnTime + GAMEOVER_SPAWN_COOLDOWN and not gameover then
			PW.audio.playNote("didgeridoo", nil, 14)
			gameover = true
			gameoverTime = os.epoch("utc")
			playerData.highscore = math.max(playerData.highscore, score)
			playerData.playcount = playerData.playcount + 1
			savePlayerdata()

			scoreText:setStr("Game over! Final score: " .. score)
			highscoreText:setStr("Highscore: " .. playerData.highscore)
		end

		if newX < -0.5 + hSize then
			newX = -0.5 + hSize
			p.vx = math.abs(p.vx)*0.5
			-- p.vx = 0
		elseif newX > 0.5 - hSize then
			newX = 0.5 - hSize
			p.vx = -math.abs(p.vx)*0.5
			-- p.vx = 0
		end

		if newZ < -0.5 + hSize then
			newZ = -0.5 + hSize
			p.vz = math.abs(p.vz)*0.5
			-- p.vz = 0
		elseif newZ > 0.5 - hSize then
			newZ = 0.5 - hSize
			p.vz = -math.abs(p.vz)*0.5
			-- p.vz = 0
		end

		o:setPos(newX, newY, newZ)
	end
end

-- local lastFrameTime = os.epoch("utc")

local physicsTime = 0
-- local frames = 0
scene:on("update", function(dt)
	cameraRotation(dt)

	local steps = math.max(MIN_PHYSICS_STEPS, math.min(MAX_PHYSICS_STEPS, math.ceil(20 / physicsTime)))
	-- PW.log("Doing " .. steps .. " steps, because last physics time per step: " .. physicsTime)
	local t1 = os.epoch("utc")
	local useDT = math.min(MAX_PHYSICS_DT, dt / steps)
	for i = 1, steps do
		fruitCollisions(useDT)
	end
	local t2 = os.epoch("utc")
	physicsTime = (t2 - t1) / steps

	-- frames = frames + 1
	-- if t2 >= lastFrameTime + 1000 then
	-- 	PW.log("FPS: " .. frames)
	-- 	lastFrameTime = t2
	-- 	frames = 0
	-- end


	local dt = math.min(0.01, dt)
	local dx = 0
	if PW.isDown[keys.left] then
		dx = -1.2
	end
	if PW.isDown[keys.right] then
		dx = 1.2
	end
	local dy = 0
	if PW.isDown[keys.up] then
		dy = -1.2
	end
	if PW.isDown[keys.down] then
		dy = 1.2
	end

	local cursorX, cursorZ = cursor.x, cursor.z
	local angle = -math.rad(scene.camera.rotY or 0)
	local moveX = dx * dt
	local moveZ = -dy * dt

	cursorX = cursorX
		+ moveX * math.sin(angle)
		+ moveZ * math.cos(angle)
	cursorZ = cursorZ
		+ moveX * math.sin(angle + math.pi*0.5)
		+ moveZ * math.cos(angle + math.pi*0.5)

	local fruitKind = fruitKinds[nextFruitKind]
	local halfSize = fruitKind.size*0.5
	cursorX = math.min(0.5 - halfSize, math.max(-0.5 + halfSize, cursorX))
	cursorZ = math.min(0.5 - halfSize, math.max(-0.5 + halfSize, cursorZ))

	cursor:setPos(cursorX, 1 + halfSize-0.01, cursorZ)
end)

local lastX, lastY = 0, 0
local lastDragtime = os.epoch("utc")
scene:on("mouse_click", function(button, x, y)
	lastX, lastY = x, y
	lastDragtime = os.epoch("utc")
end)

scene:on("mouse_drag", function(button, x, y)
	local t = os.epoch("utc")
	local dt = math.min(0.01, (t - lastDragtime)/1000)
	lastDragtime = t

	local dx, dy = x - lastX, y - lastY
	lastX, lastY = x, y
	if math.abs(dx) > 15 or math.abs(dy) > 15 then
		return
	end
	dx = dx * cameraZoom
	dy = dy * cameraZoom

	local w, h = term.getSize()
	dx = dx / w
	dy = dy / h

	local cursorX, cursorZ = cursor.x, cursor.z
	local angle = -math.rad(scene.camera.rotY or 0)
	local moveX = dx * 250 * dt
	local moveZ = -dy * 250 * dt

	cursorX = cursorX
		+ moveX * math.sin(angle)
		+ moveZ * math.cos(angle)
	cursorZ = cursorZ
		+ moveX * math.sin(angle + math.pi*0.5)
		+ moveZ * math.cos(angle + math.pi*0.5)

	local fruitKind = fruitKinds[nextFruitKind]
	local halfSize = fruitKind.size*0.5
	cursorX = math.min(0.5 - halfSize, math.max(-0.5 + halfSize, cursorX))
	cursorZ = math.min(0.5 - halfSize, math.max(-0.5 + halfSize, cursorZ))

	cursor:setPos(cursorX, 1 + halfSize-0.01, cursorZ)
end)

local lastDropTime = os.epoch("utc")
scene:on("key", function(key)
	if key == keys.tab then
		autoRotation = not autoRotation
	elseif key == keys.one then
		PW.audio.playNote("bit", nil, 8)
		renderQuality = 1
		buildEnvironment()
		refreshFruitModels()
	elseif key == keys.two then
		PW.audio.playNote("bit", nil, 10)
		renderQuality = 2
		buildEnvironment()
		refreshFruitModels()
	elseif key == keys.three then
		PW.audio.playNote("bit", nil, 12)
		renderQuality = 3
		buildEnvironment()
		refreshFruitModels()
	elseif key == keys.four then
		PW.audio.playNote("bit", nil, 14)
		renderQuality = 4
		buildEnvironment()
		refreshFruitModels()
	elseif key == keys.five then
		PW.audio.playNote("bit", nil, 16)
		renderQuality = 5
		buildEnvironment()
		refreshFruitModels()
	elseif key == keys.space then
		if gameover then
			local t = os.epoch("utc")
			if t > gameoverTime + 1000 then
				for i = #fruits, 1, -1 do
					local fruit = fruits[i]

					fruit.object:remove()
					table.remove(fruits, i)
				end
				gameover = false
				score = 0
				scoreText:setStr("Score: 0")
				highscoreText:setStr("")
				PW.audio.playNote("xylophone")
			end
		else
			local t = os.epoch("utc")
			if t > lastDropTime + 600 then
				lastDropTime = t

				local kind = fruitKinds[nextFruitKind]
				local fruit = makeFruit(kind, cursor.x, cursor.y, cursor.z)
				fruit.fromCursor = true
				fruits[#fruits+1] = fruit

				nextFruitKind = nextNextFruitKind
				nextNextFruitKind = math.random(1, 3)
				updateNextArrows(nextNextFruitKind)
				updateCursor()
				PW.audio.playNote("harp", 0.1, kind.index*2 + 8)
			end
		end
	end
end)

scene:on("mouse_scroll", function(dy, x, y)
	if dy > 0 then
		cameraZoom = math.min(MAX_CAMERA_ZOOM, cameraZoom * 1.05)
	elseif dy < 0 then
		cameraZoom = math.max(MIN_CAMERA_ZOOM, cameraZoom / 1.05)
	end
end)

PW.audio.playNote("xylophone")

PW.run({ disableDebug = true })