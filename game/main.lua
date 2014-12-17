local Object = require("util.object");
local Vector = require("util.vector");
local Asset = require("util.asset");

-- Get the factory initialization function.
local InitFactories = require("factories");

-- Your Slime
local YourSlime = nil;

local buttonQuads = {};
local function LoadAssets()
	Asset.Add(Asset.IMAGE, "slime", "assets/graphics/SlimeSheet.png");
	Asset.Add(Asset.IMAGE, "props", "assets/graphics/Props.png");
	Asset.Add(Asset.IMAGE, "buttons", "assets/graphics/Pressed.png");
	Asset.Add(Asset.IMAGE, "hud", "assets/graphics/HUD.png");
	
	local buttonSheet = Asset.Get(Asset.IMAGE, "buttons");
	buttonQuads.menu = love.graphics.newQuad(0, 0, 54, 24, buttonSheet:getWidth(), buttonSheet:getHeight()); -- menu
	buttonQuads.exit = love.graphics.newQuad(0, 25, 54, 24, buttonSheet:getWidth(), buttonSheet:getHeight());
	buttonQuads.block = love.graphics.newQuad(55, 0, 32, 32, buttonSheet:getWidth(), buttonSheet:getHeight());
	buttonQuads.food = love.graphics.newQuad(88, 0, 32, 32, buttonSheet:getWidth(), buttonSheet:getHeight());
	
	--[[local slimeSheet = Asset.Get(Asset.IMAGE, "slime");
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
	
	local buttonBatch = love.graphics.newSpriteBatch(buttonSheet, 4);
	local buttonSprites = {};]]
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

local function mouseInBounds(x, y, w, h)
	local mx, my = love.mouse.getPosition();
	return (mx > x and my > y and mx < x + w and my < y + h);
end
function love.draw()
	Object.DrawAll();
	
	love.graphics.setColor(255, 255, 255, 255);
	
	local hudOverlay = Asset.Get(Asset.IMAGE, "hud");
	local widthRatio = love.graphics.getWidth()/hudOverlay:getWidth();
	local heightRatio = love.graphics.getHeight()/hudOverlay:getHeight();
	love.graphics.draw(hudOverlay, 0, 0, 0, widthRatio, heightRatio);
	
	local buttons = Asset.Get(Asset.IMAGE, "buttons");
	-- Menu button
	if (mouseInBounds(widthRatio * 658, heightRatio * 8, 54, 24) and love.mouse.isDown("l")) then
		love.graphics.draw(buttons, buttonQuads.menu, widthRatio * 658, heightRatio * 8, 0, widthRatio, heightRatio);
	end
	-- Exit button
	if (mouseInBounds(widthRatio * 738, heightRatio * 8, 54, 24) and love.mouse.isDown("l")) then
		love.graphics.draw(buttons, buttonQuads.exit, widthRatio * 738, heightRatio * 8, 0, widthRatio, heightRatio);
	end
	-- Block button
	if (mouseInBounds(widthRatio * 4, heightRatio * 118, 32, 32) and love.mouse.isDown("l")) then
		love.graphics.draw(buttons, buttonQuads.block, widthRatio * 4, heightRatio * 118, 0, widthRatio, heightRatio);
	end
	-- Food buttons
	if (mouseInBounds(widthRatio * 4, heightRatio * 245, 32, 32) and love.mouse.isDown("l")) then
		love.graphics.draw(buttons, buttonQuads.food, widthRatio * 4, heightRatio * 245, 0, widthRatio, heightRatio);
	end
	-- 612 535, 669 535, 726 535
	local offset = 0;
	
	offset = heightRatio * 59 * (1 - YourSlime:GetMoodPercent("Social"));
	love.graphics.setColor(255, 0, 0, 255);
	love.graphics.rectangle("fill", widthRatio * 612, heightRatio * 535 + offset, widthRatio * 23, heightRatio * 59 * YourSlime:GetMoodPercent("Social"));
	
	offset = heightRatio * 59 * (1 - YourSlime:GetMoodPercent("Curious"));
	love.graphics.setColor(0, 255, 0, 255);
	love.graphics.rectangle("fill", widthRatio * 669, heightRatio * 535 + offset, widthRatio * 23, heightRatio * 59 * YourSlime:GetMoodPercent("Curious"));
	
	offset = heightRatio * 59 * (1 - YourSlime:GetMoodPercent("Angry"));
	love.graphics.setColor(0, 0, 255, 255);
	love.graphics.rectangle("fill", widthRatio * 726, heightRatio * 535 + offset, widthRatio * 23, heightRatio * 59 * YourSlime:GetMoodPercent("Angry"));
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
	if (mouseInBounds(49, 49, 751, 453)) then 
		if (button == "l") then
			local food = Object.Fabricate("food", Vector(x, y), nil);
		elseif (button == "r") then
			local randAI = {Curious = math.random(0, 100), Angry = math.random(0, 100), Social = math.random(0, 100)};
			local enemy = Object.Fabricate("slime", Vector(x, y), true, randAI);
			enemy.Modifiers.Anger = 2;
			--enemy:ModifyAI("Aggression", 100);
		end
	end
	if (mouseInBounds(love.graphics.getWidth()/Asset.Get(Asset.IMAGE, "hud"):getWidth() * 738, love.graphics.getHeight()/Asset.Get(Asset.IMAGE, "hud"):getHeight() * 8, 54, 24)) then
				love.event.quit();
	end
end
