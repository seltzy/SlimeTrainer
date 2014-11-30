local asset = {};
asset.IMAGE = 0;
asset.SOUND = 1;
asset.FONT = 2;
asset.NONE = 3;

local assetReference = {};

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

return asset;