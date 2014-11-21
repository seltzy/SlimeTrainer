local Vector = require("util.vector");

local factories = {};
local objects = {};
local deleted = {};

-- Define the base object metatable
local MObject = {};
MObject.__index = MObject;

function MObject:GetType()
	return self.Type;
end

MObject.pos = Vector();
function MObject:SetPos(vec)
	self.pos = Vector(vec.x, vec.y);
end
function MObject:GetPos()
	return self.pos;
end

function MObject:Draw()
	-- define me!
end
function MObject:Update(dt)
	-- define me!
end

local function Register(name, metatable, constructor)
	if (metatable.__metatable) then
		error("Cannot use __metatable for factory creation!");
	end
	factories[name] = {m = setmetatable(metatable, MObject), c = constructor};
end
local function Fabricate(name, ...)
	local obj = setmetatable(factories[name].c(...), factories[name].m);
	table.insert(objects, obj);
	return obj;
end

local function UpdateAll(dt)
	local deleteMe = {};
	for i = 1, #objects do
		local obj = objects[i];
		if (not obj or deleted[objects[i]]) then
			table.insert(deleteMe, i);
			print("found obj [" .. tostring(obj) .. "] as deleted (" .. i .. ")");
		else
			if (obj.Update and type(obj.Update) == "function") then
				obj:Update(dt);
			end
		end
	end
	for i = 1, #deleteMe do
		local obj = objects[deleteMe[i] - (i - 1)];
		print("deleting obj [" .. tostring(obj) .. "] (" .. deleteMe[i] .. " => " .. (deleteMe[i] - (i - 1)) .. ")");
		deleted[obj] = nil;
		table.remove(objects, deleteMe[i] - (i - 1));
	end
end
local function DrawAll()
	for i = 1, #objects do
		local obj = objects[i];
		if (obj and not deleted[objects[i]]) then
			if (obj.Draw and type(obj.Draw) == "function") then
				obj:Draw();
			end
		end
	end
end

local function Delete(obj)
	for i = 1, #objects do
		if (objects[i] == obj) then
			deleted[obj] = true;
			print("marking obj [" .. tostring(obj) .. "] as deleted (" .. i .. ")");
			return true;
		end
	end
	return false;
end
local function GetAll()
	local t = {};
	for i = 1, #objects do
		local obj = objects[i];
		if (obj and not deleted[obj]) then
			table.insert(t, obj);
		end
	end
	return t;
end

local function IsObject(obj)
	if obj == nil or type(obj) ~= "table" then
		return false;
	end
	while (getmetatable(obj) ~= getmetatable({})) do
		obj = getmetatable(obj);
		if (obj == MObject) then
			return true;
		end
	end
	return false;
end

return {IsValid = IsObject, Register = Register, Fabricate = Fabricate, UpdateAll = UpdateAll, DrawAll = DrawAll, Delete = Delete, GetAll = GetAll};