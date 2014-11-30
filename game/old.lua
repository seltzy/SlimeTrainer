
--[[
  Block Factory
--]]

-- Returns an initialization function of object factories
return function()
	Object.Register(SlimeFactoryName, MSlime, MakeSlime);
	Object.Register(FoodFactoryName, MFood, MakeFood);
	--Object.Register(BlockFactoryName, MBlock, MakeBlock);
end
