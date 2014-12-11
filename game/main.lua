local Object = require("util.object");
local Vector = require("util.vector");
local Asset = require("util.asset");

-- Get the factory initialization function.
local InitFactories = require("factories");

-- Your Slime
local YourSlime = nil;

local function LoadAssets()
	Asset.Add(Asset.IMAGE, "slime", "assets/graphics/SlimeSheet.png");
	Asset.Add(Asset.IMAGE, "props", "assets/graphics/Props.png");
	Asset.Add(Asset.IMAGE, "buttons", "assets/graphics/Pressed.png");
	Asset.Add(Asset.IMAGE, "hud", "assets/graphics/HUD.png");
	
	local slimeSheet = Asset.Get(Asset.IMAGE, "slime");
	local slimeBatch = love.graphics.newSpriteBatch(slimeSheet, 8);
	local slimeSprites = {};
	for i = 1, 8 do
		local slimeQuad = love.graphics.newQuad((i-1) * 32, 0, 32, 32, slimeSheet:getWidth(), slimeSheet:getHeight());
		table.insert(slimeSprites, slimeQuad);
	end
	
	local propSheet = Asset.Get(Asset.IMAGE, "props");
	local propBatch = love.graphics.newSpriteBatch(propSheet, 8);
	local propSprites = {};
	for i = 1, 8 do
		local propQuad = love.graphics.newQuad(((i-1) % 4) * 32, ((i-1) % 2) * 32, 32, 32, propSheet:getWidth(), propSheet:getHeight());
		table.insert(propSprites, propQuad);
	end
	
	local buttonSheet = Asset.Get(Asset.IMAGE, "buttons");
	local buttonBatch = love.graphics.newSpriteBatch(buttonSheet, 4);
	local buttonSprites = {};
	local buttonQuad = love.graphics.newQuad(0, 0, 54, 24, buttonSheet:getWidth(), buttonSheet:getHeight());
	table.insert(buttonSprites, buttonQuad);
	buttonQuad = love.graphics.newQuad(0, 25, 54, 24, buttonSheet:getWidth(), buttonSheet:getHeight());
	table.insert(buttonSprites, buttonQuad);
	buttonQuad = love.graphics.newQuad(55, 0, 32, 32, buttonSheet:getWidth(), buttonSheet:getHeight());
	table.insert(buttonSprites, buttonQuad);
	buttonQuad = love.graphics.newQuad(88, 0, 32, 32, buttonSheet:getWidth(), buttonSheet:getHeight());
	table.insert(buttonSprites, buttonQuad);
	--[[asset.Add(asset.SOUND, "eat", "assets/eat.mp3");
	asset.Add(asset.SOUND, "attack", "assets/attack.mp3");
	asset.Add(asset.SOUND, "place_food", "assets/placefood.mp3");
	asset.Add(asset.SOUND, "place_block", "assets/placeblock.mp3");]]
end

function love.load()
	LoadAssets();
	InitFactories();
	
	-- Create your slime
	YourSlime = Object.Fabricate("slime", Vector(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2), false, nil);
end

function love.draw()
	Object.DrawAll();
end

function love.update(dt)
	Object.UpdateAll(dt);
end

function love.keypressed(key, isrepeat)
	if (key == " ") then
		print("you did a thing!")
	end
end

function love.keyreleased(key)
	if (key == "escape") then
		love.event.quit();
	end
end

function love.mousepressed(x, y, button)
	if (button == "l") then
	end
end

function love.mousereleased(x, y, button)
	if (button == "l") then
		local food = Object.Fabricate("food", Vector(x, y), nil);
	elseif (button == "r") then
		local randAI = {Curious = math.random(0, 100), Angry = math.random(0, 100), Social = math.random(0, 100)};
		local enemy = Object.Fabricate("slime", Vector(x, y), true, randAI);
		enemy.Modifiers.Anger = 2;
		--enemy:ModifyAI("Aggression", 100);
	end
end
