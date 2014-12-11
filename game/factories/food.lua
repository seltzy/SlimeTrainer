
local Object = require("util.object");
local Vector = require("util.vector");
local Asset = require("util.asset");

--[[
  Food Factory
--]]
local FoodFactoryName = "food";

local FoodImage = nil;
local FoodQuad = nil;

local MFood = {};
MFood.__index = MFood;
MFood.Type = FoodFactoryName;

MFood.Satisfaction = 20;
MFood.Size = 10;
MFood.Scale = 1;

function MFood:GetEater()
	return self.Eater;
end
function MFood:SetEater(obj)
	self.Eater = obj;
end

function MFood:Draw()
	love.graphics.setColor(255, 255, 200);
	--love.graphics.circle("fill", self:GetPos().x, self:GetPos().y, self.Size, 100); -- Draw white circle with 100 segments.-- Draw AI data:
	love.graphics.draw(FoodImage, FoodQuad, self:GetPos().x, self:GetPos().y, 0, self.Scale, self.Scale, 32/2, 32/2);
	local data = "";
	local eater = "nil";
	if (self.Eater) then
		eater = tostring(self.Eater);
	end
	data = data .. "Eater" .. " = " .. eater .. "\n";
	love.graphics.printf(data, self:GetPos().x - 70, self:GetPos().y - 20, 200, "left")
end

function MFood:Update(dt)
	local eater = self:GetEater();
	if (not eater or eater:GetBehaviour() ~= "eat" or eater:GetTarget() ~= self) then
		self:SetEater(nil);
	end
end

local function MakeFood(pos, satisfaction)
	if (not FoodImage) then
		FoodImage = Asset.Get(Asset.IMAGE, "props");
	end
	if (not FoodQuad) then
		FoodQuad = love.graphics.newQuad( 0, 0, 32, 32, FoodImage:getWidth(), FoodImage:getHeight() );
	end
	return {pos = pos, Satisfaction = satisfaction, Eater = nil};
end

return function()
	Object.Register(FoodFactoryName, MFood, MakeFood);
end