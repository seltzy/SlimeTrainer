local Object = require("util.object");

local Init = {
	require("factories.slime"),
	require("factories.food"),
	require("factories.block")
};
-- Returns an initialization function of object factories
return function()
	for i = 1, #Init do
		Init[i]();
	end
end
