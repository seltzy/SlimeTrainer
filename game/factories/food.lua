
local Object = require("util.object");
local Vector = require("util.vector");

--[[
  Food Factory
--]]
local FoodFactoryName = "food";

local MFood = {};
MFood.__index = MFood;
MFood.Type = FoodFactoryName;

MFood.Satisfaction = 20;
MFood.Size = 5;

function MFood:Draw()
	love.graphics.setColor(255, 255, 200);
	love.graphics.circle("fill", self:GetPos().x, self:GetPos().y, self.Size, 100); -- Draw white circle with 100 segments.
end

local function MakeFood(pos, satisfaction)
	return {pos = pos, Satisfaction = satisfaction, Eater = nil};
end

return function()
	Object.Register(FoodFactoryName, MFood, MakeFood);
end