
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

function MFood:GetEater()
	return self.Eater;
end
function MFood:SetEater(obj)
	self.Eater = obj;
end

function MFood:Draw()
	love.graphics.setColor(255, 255, 200);
	love.graphics.circle("fill", self:GetPos().x, self:GetPos().y, self.Size, 100); -- Draw white circle with 100 segments.-- Draw AI data:
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
	return {pos = pos, Satisfaction = satisfaction, Eater = nil};
end

return function()
	Object.Register(FoodFactoryName, MFood, MakeFood);
end