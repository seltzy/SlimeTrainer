local Object = require("util.object");
local Vector = require("util.vector");
local Asset = require("util.asset");

-- Get the factory initialization function.
local InitFactories = require("factories");

-- Your Slime
local YourSlime = nil;

local function LoadAssets()
	Asset.Add(0, "slime", "assets/slime.png");
	--[[asset.Add(asset.IMAGE, "food", "assets/food.png");
	asset.Add(asset.IMAGE, "block", "assets/block.png");
	
	asset.Add(asset.SOUND, "eat", "assets/eat.mp3");
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
		local food = Object.Fabricate("food", Vector(x, y), nil)
	elseif (button == "r") then
		local enemy = Object.Fabricate("slime", Vector(x, y), true, nil)
		enemy:ModifyAI("Aggression", 100);
	end
end
