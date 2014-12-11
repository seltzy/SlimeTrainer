local asset = {};
asset.IMAGE = 0;
asset.SOUND = 1;
asset.FONT = 2;
asset.NONE = 3;

local assetReference = {};
local spriteBatches = {};

function asset.Add(assetType, name, path, ...)
	local newAsset;
	if (assetType == asset.IMAGE) then
		newAsset = love.graphics.newImage(path, ...);
	elseif (assetType == asset.SOUND) then
		newAsset = love.audio.newSource(path, ...);
	elseif (assetType == asset.FONT) then
		newAsset = love.graphics.newFont(path, ...)
	end
	
	if (not newAsset) then
		return false;
	end
	
	if (not assetReference[assetType]) then
		assetReference[assetType] = {};
	end
	
	assetReference[assetType][name] = newAsset;
	return true;
end

function asset.Get(assetType, name)
	if (not assetReference[assetType]) then
		return false;
	end
	if (not assetReference[assetType][name]) then
		return false;
	end
	return assetReference[assetType][name];
end

-- Initialize the batch with quad data.
function asset.InitSpriteBatch(name, quadData, maxSprites)
	local sheet = Asset.Get(Asset.IMAGE, "slime");
	local batch = love.graphics.newSpriteBatch(sheet, maxSprites);
	local quads = {};
	for i = 1, #quadData do
		local quad = love.graphics.newQuad(unpack(quadData[i]), sheet:getWidth(), sheet:getHeight());
		table.insert(quads, quad);
	end
	spriteBatches[name] = {Batch = batch, Quads = quads, Sprites = {}};
	return true;
end

function asset.AddSprite(name, quadID, ...)
	local spriteID = spriteBatches[name].Batch:add(spriteBatches[name].Quads[quadID], ...);
	table.insert(spriteBatches[name].Sprites, spriteID);
end

function asset.DrawSprites(name)
	spriteBatches[name].Batch:bind();
	for i = 1, #spriteBatches[name].Sprites do
		local quadID = spriteBatches[name].Sprites[i].id;
		spriteBatches[name].Batch:add(spriteBatches[name].Quads[quadID], unpack(spriteBatches[name].Sprites[i].args));
	end
	spriteBatches[name].Batch:unbind();
	spriteBatches[name].Batch:clear();
	spriteBatches[name].Sprites = {};
end

return asset;