local MVector = {};
MVector.__index = MVector;
MVector.__newindex = function(t, k, v)
	if k == "x" or k == "y" then
		--[[if v == nil then
			error("Cannot set " .. k .. " to nil");
		elseif type(v) ~= "number" then
			error("Cannot set " .. k .. " to value of type " .. type(v));
		end]]
		return; -- This line makes vector values immutable
	end
	rawset(t, k, v);
end

local function IsVector(vec)
	return vec ~= nil and getmetatable(vec) == MVector;
end
local function Vector(x, y)
	if (not x or type(x) ~= "number") then
		x = 0;
	end
	if (not y or type(y) ~= "number") then
		y = 0;
	end
	return setmetatable({x = x, y = y}, MVector);
end
local function RandVector(size)
	return Vector(math.random(-size, size), math.random(-size, size));
end

function MVector.__unm(t)
	return Vector(-t.x, -t.y);
end

function MVector.__eq(a, b)
	return IsVector(a) and IsVector(b) and (a.x == b.x) and (a.y == b.y);
end

function MVector.__add(a, b)
	if (IsVector(a) ~= IsVector(b)) then
		error("Cannot add vector and non-vector");
		return;
	end
	return Vector(a.x + b.x, a.y + b.y);
end

function MVector.__sub(a, b)
	if (IsVector(a) ~= IsVector(b)) then
		error("Cannot sub vector and non-vector");
		return;
	end
	return Vector(a.x - b.x, a.y - b.y);
end

function MVector.__mul(a, b)
	local scalar, vector;
	if (type(a) == "number" and IsVector(b)) then
		scalar = a;
		vector = b;
	elseif (type(b) == "number" and IsVector(a)) then
		scalar = b;
		vector = a;
	else
		error("Cannot mul vector and non-scalar");
		return;
	end
	return Vector(scalar * vector.x, scalar * vector.y);
end

function MVector.__div(a, b)
	if (not IsVector(a) or not type(b) == "number") then
		error("Cannot div a scalar by a vector");
		return;
	elseif (b == 0) then
		error("Cannot div by zero");
		return;
	end
	return Vector(a.x / b, a.y / b);
end

function MVector.__tostring(t)
	return "Vector(" .. t.x .. ", " .. t.y .. ")";
end

function MVector:lengthSqr()
	return math.pow(self.x, 2) + math.pow(self.y, 2);
end

function MVector:length()
	return math.sqrt(self:lengthSqr());
end

function MVector:distanceSqr(vec)
	local lenVec = vec - self;
	return lenVec:lengthSqr();
end

function MVector:distance(vec)
	local lenVec = vec - self;
	return lenVec:length();
end

function MVector:normalize()
	if (self:length() == 0) then
		return Vector();
	end
	return self / self:length();
end

-- Test Cases
--[[
local oldError = error;
error = print;

local v = Vector()
print("Made zero-vector with no values", v)

v = Vector(0, 0)
print("Made zero-vector using values", v)

v.x = 1;
v.y = 1;
print("Attempt to edit vector (1, 1)", v)

v = Vector(true, "test")
print("Made vector with non-scalar values (true, \"test\")", v)

v = Vector(nil, nil)
print("Made vector with nil values", v)

v = Vector(1, false)
print("Made vector with mixed values (1, false)", v)

v = Vector(true, 1)
print("Made vector with mixed values (true, 1)", v)

v = Vector(100, 100)
print("Made non-zero-vector (100, 100)", v)

print("Normalized vector (100, 100)", v:normalize());
print("Normalized vector (0, 0)", Vector(0,0):normalize());

print("Length of vector (100, 100)", v:length());
print("LengthSqr of vector (100, 100)", v:lengthSqr());

print("Distance between vector (100, 100) and vector (0, 100)", v:distance(Vector(0, 100)));
print("DistanceSqr between vector (100, 100) and vector (0, 100)", v:distanceSqr(Vector(0, 100)));

print("Attempting (0, 1) + (-1, 0)", Vector(0, 1) + Vector(-1, 0));
print("Attempting (0, 1) - (-1, 0)", Vector(0, 1) - Vector(-1, 0));

print("Attempting -(1, 1)", -Vector(1, 1));

print("Attempting 5 * (1, 1)", Vector(1, 1) * 5);
print("Attempting (1, 1) * 5", 5 * Vector(1, 1));

print("Attempting (5, 5) / 5", Vector(5, 5) / 5);
print("Attempting 5 / (5, 5)", 5 / Vector(5, 5));
print("Attempting (5, 5) / 0", Vector(5, 5) / 0);

print("Attempting (1, 1) == nil", Vector(1, 1) == nil);
print("Attempting (1, 1) == 1", Vector(1, 1) == 1);
print("Attempting (1, 1) == {1, 1}", Vector(1, 1) == {x = 1, y = 1});
print("Attempting (1, 1) == (1, 1)", Vector(1, 1) == Vector(1, 1));
print("Attempting (1, 1) ~= (1, 1)", Vector(1, 1) ~= Vector(1, 1));
print("Attempting (1, 1) == (2, 1)", Vector(1, 1) == Vector(2, 1));
print("Attempting (1, 1) ~= (2, 1)", Vector(1, 1) ~= Vector(2, 1));

error = oldError;
--]]

local lib = {};
lib.__index = lib;
lib.__call = function(t, ...)
	return Vector(...);
end
return setmetatable({New = Vector, IsValid = IsVector, Random = RandVector}, lib);