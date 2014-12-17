--[[
  Slime Factory
--]]

local Object = require("util.object");
local Vector = require("util.vector");

local function CopyRecur(source, dest)
	for k, v in pairs(source) do
		if (type(v) == "table") then
			if (not dest[k]) then
				dest[k] = {};
				CopyRecur(v, dest[k]);
			end
		else
			dest[k] = v;
		end
	end
end

local function TableHasValue(t, val)
	for _, v in ipairs(t) do
		if (val == v) then
			return true;
		end
	end
	return false;
end

local AI_MAX = 100;
local AI_MIN = 0;

local SlimeFactoryName = "slime";

local SlimeConfig = {
	Timers = {
		Mood = {},
		Vitality = {}
	},
	Maxima = {
		Vitality = {
			Health = 100,
			Hunger = 100,
			Rested = 100
		}
	},
	-- Modifiers table holds info as to how much certain AI state variables change each second
	Modifiers = {
		Recovery = 1, -- additional health/sec while not resting
		AI = {}
	},
	Constants = {
		EatTime = 3, -- Time it takes to eat food in seconds
		FleeSpeedMultiplier = 3 -- Increased speed multiplier for when fleeing an enemy.
	},
	Attributes = {
		MaxHealth = 100,
		Speed = 100, -- units moved/sec
		Power = 10, -- dmg dealt/sec
		Toughness = 0.0, -- %dmg mitigated
		Size = 10, -- physical radius of the slime
		Sight = 100 -- distance it can see in units
	},
	State = {
		-- Mood State - Homogenized AI State Vars
		--[[
			The following variables are guaranteed to stay in a quasi-homogenized state.
			That is, they will always add up to 100. These are used to dictate the general "mood" of the AI.
			Assume that an over abundance in one of these variables will cause an under abundance in the others.
			This is why Health is not among these variables, even though it dictates behaviour.
			In addition, these variables are monitored, and recorded over time for averaging.
			This causes the AI to gravitate to the state it is in the most.
		--]]
		Mood = {
			Curious = 34,
			Angry = 33,
			Social = 33
		},
		-- Vitality State - Unhomogenized AI State Vars
		--[[
			These do affect AI, but do not need to add up to 100, and are independent of the Mood variables.
			These should be viewed as basic needs for the AI, and should have a drastic effect on the AI in certain cases.
			For instance, when deciding when to fight or flee, health should always take priority to aggression.
		--]]
		Vitality = {
			Health = 100,
			Hunger = 0,
			Rested = 100
		},
		Mood_Snapshots = {},
		Mood_Avg = {},
		-- Behaviour State
		--[[ 
		Valid Behaviours:
			- none : monitors its AI state variables until a new behaviour is apparent
			- explore : chooses a random direction and moves in it, while exhibiting the same behaviour as none
			- eat (target) : moves to the target and attempts to eat it when in range, then reverts to none
			- use (target) : moves to the target and attempts to 'use' it when in range, then reverts to none
			- attack (target) : chases the target and fights it when in range
			- flee (target) : flees the target until out of range, then reverts to none
		--]]
		Behaviour = "none"
	}
};

-- Takes in AI state vars and tries its best to homogenize them to a total of 100.
local function HomogenizeAI(aiData)
	local aiKeys = {};
	local curTotal = 0;
	for k, v in pairs(aiData) do
		curTotal = curTotal + v;
		table.insert(aiKeys, k);
	end
	local newTotal = 0;
	local aiKeysFloating = {};
	for i, k in pairs(aiKeys) do
		aiData[k] = (100 * aiData[k]) / curTotal;
		if (tonumber(tostring(aiData[k])) ~= tonumber(tostring(math.floor(aiData[k])))) then
			table.insert(aiKeysFloating, k);
		end
		aiData[k] = math.floor(aiData[k]);
		newTotal = newTotal + aiData[k];
	end
	local divvy = 100 - newTotal;
	while (divvy > 0) do
		for i, k in pairs(aiKeysFloating) do
			if (divvy == 0) then
				break;
			end
			divvy = divvy - 1;
			aiData[k] = aiData[k] + 1;
		end
	end
end
	
-- Start Slime Metatable
local MSlime = {};
MSlime.__index = MSlime;
MSlime.Type = SlimeFactoryName;

-- List of valid behaviours in order of priority.
MSlime.BehaviourOrder = {"flee", "fight", "eat", "rest", "explore", "use", "none"};
--MSlime.BehaviourThreshold = {};

-- List of functions that calculate desire for a particular behaviour - indexed by behaviour name.
MSlime.Desire = {
	flee = function(slime)
		-- If we're too tired, it's sleep time.
		local rested = slime:GetVitalityPercent("Rested");
		if (rested < 0.10) then
			return 0, nil;
		end
		
		local behav = slime:GetBehaviour();
		local aggro = slime:GetMoodPercent("Angry");
		
		-- Calculate distance needed to be "safe"
		local dist = slime.Attributes.Sight;
		if (behav == "flee") then
			dist = dist * 1.5 + (1 - aggro); -- Only flee beyond your sight radius if you've already decided to flee.
		end
		local target = slime:GetClosestAttacker(dist);
		
		-- If nothing has attacked us yet, don't flee.
		if (behav ~= "flee" and (not target or slime:GetPos():distance(target:GetPos()) > slime.Attributes.Size + target.Attributes.Size)) then
			return 0, nil;
		end
		-- If nothing is currently attacking/chasing us, don't flee.
		if (not target or target:GetBehaviour() ~= "fight" or not target:GetTarget() or target:GetTarget() ~= slime or target:GetVitality("Health") <= 0) then
			return 0, nil;
		end
		
		-- Desire to flee relates to remaining HP and aggression.
		local hpLeft = slime:GetVitalityPercent("Health");
		return 1 - (hpLeft * aggro), target;
	end,
	fight = function(slime)
		local behav = slime:GetBehaviour();
		local hpLeft = slime:GetVitalityPercent("Health");
		local aggro = slime:GetMoodPercent("Angry");
		-- Calculate distance needed to give chase.
		local dist = slime.Attributes.Sight;
		if (behav ~= "fight") then
			dist = dist * aggro; --(math.min(math.max(0, aggro + 0.1), 1));
		end
		local target = slime:GetClosestSlime(dist);
		if (not target or target:GetVitality("Health") <= 0) then
			return 0, nil;
		end
		return (hpLeft * aggro), target;
	end,
	eat = function(slime)
		local hunger = slime:GetVitalityPercent("Hunger");
		local target = slime:GetClosestFood();
		if (not target --[[or hunger < .1]]) then
			return 0, nil;
		end
		return hunger, target;
	end,
	explore = function(slime)
		local behav = slime:GetBehaviour();
		local target = slime:GetTarget();
		
		-- If we're too tired, it's sleep time.
		local rested = slime:GetVitalityPercent("Rested");
		if (behav == "rest" and slime:GetVitalityPercent(target[1]) < target[2]) then
			return 0, nil;
		end
		
		--[[if (behav == "explore" and rested < 0.20) then
			return 0, nil;
		end]]
		
		-- Don't explore if we're already eating.
		if (behav == "eat" and slime:GetTarget() and slime:GetTarget():GetEater() == slime) then
			return 0, nil;
		end
		
		-- Calculate curiosity and hunger - we will take the max of the two.
		local hunger = slime:GetVitalityPercent("Hunger");
		local curious = slime:GetMoodPercent("Curious");
		
		-- If hunger is really low, don't even pay attention to it?
		if (hunger < .1) then
			hunger = 0;
		end
		
		-- Pick a random place to go to.
		local target = slime:GetPos() + Vector.Random(slime.Attributes.Sight);
		-- Don't go off the screen for now.
		while (target.x < 49 or target.x > love.graphics.getWidth() or target.y < 49 or target.y > love.graphics.getHeight() - 98) do
			target = slime:GetPos() + Vector.Random(slime.Attributes.Sight);
		end
		
		return math.max(curious, hunger), target;
	end,
	rest = function(slime)
		local behav = slime:GetBehaviour();
		local target = slime:GetTarget();
		if (behav == "rest" and slime:GetVitalityPercent(target[1]) < target[2]) then
			return 1, target;
		end
		-- Don't rest if we're currently eating.
		if (behav == "eat" and slime:GetTarget() and slime:GetTarget():GetEater() == slime) then
			return 0, nil;
		end
		
		local rested = slime:GetVitalityPercent("Rested");
		if (rested > 0.50) then
			return 0, nil;
		end
		
		local hpLeft = 1; --slime:GetVitalityPercent("Health");
		local targetVit = "Rested";
		--[[if (rested > hpLeft) then
			targetVit = "Rested";
		else
			targetVit = "Health";
		end]]
		local targetPercent = (math.random(80, 100) / 100);
		return math.max(1 - rested, 1 - hpLeft), {targetVit, targetPercent};
	end,
	use = function(slime)
		local curious = slime:GetMoodPercent("Curious");
		local target = slime:GetClosestObjective();
		if (not target) then
			return 0, nil;
		end
		return curious, target;
	end,
	none = function(slime)
		return 0, nil;
	end
};

-- Filter list of elements using filterMeFunc - if filterMeFunc returns true, the value will not appear in the returned table.
local function FilterList(list, filterMeFunc)
	local t = {};
	for i = 1, #list do
		if (not filterMeFunc(list[i])) then
			table.insert(t, list[i]);
		end
	end
	return t;
end

-- Returns a list of the closest objects from objList in relation to obj.
local function GetClosest(obj, objList)
	local t = {};
	local closest = math.huge; -- Change to MAXINT
	for _, obj in pairs(objList) do
		local dist = obj:GetPos():distance(obj:GetPos());
		if (dist < closest) then
			closest = dist;
			t = {obj};
		elseif (dist == closest) then
			table.insert(t, obj);
		end
	end
	return t;
end

-- Finds all objects of the named type within the specified radius.
function MSlime:FindInImmediateArea(typeName, radius)
	local t = Object.GetAll();
	if (not radius) then
		radius = self.Attributes.Sight;
	end
	t = FilterList(t, function(obj)
		return (obj == self or obj:GetType() ~= typeName or self:GetPos():distance(obj:GetPos()) > radius);
	end);
	return t;
end

-- Helper function for finding food.
function MSlime:GetClosestFood(radius)
	local objs = self:FindInImmediateArea("food", radius);
	-- Filter foods that are currently being eaten.
	objs = FilterList(objs, function(obj)
								local eater = obj:GetEater();
								return (eater and eater ~= self);
							end);
	-- Get the closest one.
	objs = GetClosest(self, objs);
	-- If more than one is closest, choose a random one.
	if (#objs > 0) then
		return objs[math.random(1, #objs)];
	else
		return nil;
	end
end

-- Helper function for finding enemies.
function MSlime:GetClosestSlime(radius)
	local objs = self:FindInImmediateArea("slime", radius);
	-- Get the closest one.
	objs = GetClosest(self, objs);
	-- If more than one is closest, choose a random one.
	if (#objs > 0) then
		return objs[math.random(1, #objs)];
	else
		return nil;
	end
end
function MSlime:GetClosestAttacker(radius)
	local objs = self:FindInImmediateArea("slime", radius);
	-- Filter enemies that are not attacking.
	objs = FilterList(objs, function(obj) 
									return (obj:GetBehaviour() == "attack" and obj:GetTarget() == self);
								end);
	-- Get the closest one.
	objs = GetClosest(self, objs);
	-- If more than one is closest, choose a random one.
	if (#objs > 0) then
		return objs[math.random(1, #objs)];
	else
		return nil;
	end
end

-- TODO
function MSlime:GetClosestObjective(radius)
	local objs = self:FindInImmediateArea("objective", radius);
	objs = FilterList(objs, function(obj) return obj.IsEnemy ~= self.IsEnemy; end);
	objs = GetClosest(self, objs);
	if (#objs > 0) then
		-- go eat the food
		return objs[math.random(1, #objs)];
	else
		return nil;
	end
end

-- Calculates desire for each behaviour using the Desire function table, and returns list of desire values.
function MSlime:CalculateDesire()
	local curDesire = {};
	for i, b in pairs(self.BehaviourOrder) do
		local desire, target = self.Desire[b](self);
		--print("Calculated " .. b .. " desire:\t", desire, target);
		if (desire and desire > 0) then
			curDesire[b] = {desire, target};
		end
	end
	return curDesire;
end

-- Returns the most desired behaviour, and a relevant target if applicable
function MSlime:GetDisiredBehaviour()
	-- First calculate the desire for all behaviours.
	local desireVars = self:CalculateDesire();
	local behav, desire, target = "none", 0, nil;
	
	-- Go through behaviours in order of priority.
	for i, thisBehaviour in pairs(self.BehaviourOrder) do
		if (desireVars[thisBehaviour]) then
			-- Grab the desire level and corresponding target for this behaviour.
			local thisDesire, thisTarget = unpack(desireVars[thisBehaviour]);
			
			-- Grab the next behaviour name for comparison.
			local nextBehaviour = self.BehaviourOrder[i+1];
			
			-- Print some debug info
			local str = "Comparing " .. thisBehaviour .. " desire:\t[" .. tostring(desireVars[thisBehaviour][1]) .. ", " .. tostring(desireVars[thisBehaviour][2]) .. "]";
			if (desireVars[nextBehaviour]) then
				str = str .. " to [" .. tostring(desireVars[nextBehaviour][1]) .. ", " .. tostring(desireVars[nextBehaviour][2]) .. "]";
			end
			print(str);
			
			-- If we've reached the end of the list, or the desire of this behaviour exceeds the next one.
			if (not nextBehaviour or not desireVars[nextBehaviour] or (thisDesire > 0 and thisDesire >= desireVars[nextBehaviour][1])) then
				behav = thisBehaviour
				desire = thisDesire;
				target = thisTarget;
				break;
			end
		end
	end
	print("Most desired behaviour = {" .. behav .. ", " .. tostring(target) .. "} @ " .. desire);
	return behav, target;
end

function MSlime:SelectBestBehaviour()
	local behav, target = self:GetDisiredBehaviour();
	-- If we're changing the behaviour, nullify the current target.
	if (behav ~= self:GetBehaviour()) then
		self:SetTarget(nil);
	end
	if (behav == "flee") then
		-- If we're fleeing, update the target.
		self:SetTarget(target);
	elseif (behav == "fight" or behav == "eat" or behav == "use" or behav == "rest") then
		-- If we're fighting, eating, or using, prioritize current target before changing it.
		if (not self:GetTarget()) then
			self:SetTarget(target);
		end
	elseif (behav == "explore") then
		-- Don't update target until we've reached our current one.
		if (not self:GetTarget() or self:GetPos():distance(self:GetTargetPos()) == 0) then
			self:SetTarget(target);
		end
	else
		-- Invalid behaviour, or none - no target.
		self:SetTarget(nil);
	end
	self.State.Behaviour = behav;
	print("Set behaviour = {" .. self.State.Behaviour .. ", " .. tostring(self:GetTarget()) .. "}");
end

-- Target accessors
function MSlime:SetTarget(target)
	self.CurrentTarget = target;
end
function MSlime:GetTarget()
	if (not self.CurrentTarget) then
		self.CurrentTarget = nil;
	end
	return self.CurrentTarget;
end
function MSlime:GetTargetPos()
	local targetPos = self:GetTarget();
	if (Object.IsValid(targetPos)) then
		targetPos = targetPos:GetPos();
	elseif (not Vector.IsValid(targetPos)) then
		targetPos = self:GetPos();
	end
	return targetPos;
end

-- Behaviour accessors
function MSlime:GetBehaviour()
	return self.State.Behaviour;
end
function MSlime:SetBehaviour(behav)
	if (not TableHasValue(t, behav)) then
		error("Attempt to set invalid behaviour (" .. behav .. ")!", 2);
	end
	self.State.Behaviour = behav;
end


-- Vitality accessors
function MSlime:GetVitality(vitKey)
	return self.State.Vitality[vitKey];
end
function MSlime:GetVitalityPercent(vitKey)
	return self.State.Vitality[vitKey] / self.Maxima.Vitality[vitKey];
end
function MSlime:SetVitality(vitKey, val)
	val = math.ceil(val); -- Round up
	if (val < 0) then
		val = 0;
	elseif (val > self.Maxima.Vitality[vitKey]) then -- TODO: change this to some variable (like max health)
		val = self.Maxima.Vitality[vitKey];
	end
	self.State.Vitality[vitKey] = val;
end
function MSlime:ModifyVitality(vitKey, amount)
	self:SetVitality(vitKey, self:GetVitality(vitKey) + amount);
end

-- Mood Accessors
function MSlime:GetMood(aiKey)
	return self.State.Mood[aiKey];
end
function MSlime:GetMoodPercent(aiKey)
	return self.State.Mood[aiKey] / AI_MAX;
end
function MSlime:SetMood(aiKey, aiVal)
	aiVal = math.floor(aiVal); -- Round down
	--[[local total = 0;
	for k, v in pairs(self.State.Mood) do
		if (k ~= aiKey) then
			total = total + v;
		end
	end
	total = total + aiVal;
	if (total ~= 100) then
		error("Attempt to modify homogenized set to invalid value", 2);
	end]]
	self.State.Mood[aiKey] = aiVal;
end

-- Take damage (damage can be an object, or a number.
function MSlime:TakeDamage(damage)
	local amount;
	if (damage == self) then
		-- if the damage source is itself, it takes hunger damage.
		amount = self.Constants.HungerDamageAmount;
	elseif (type(damage) == "table" and Object.IsValid(damage) and damage:GetType() == "slime") then
		-- if the damage source is an enemy slime, it takes power damage.
		amount = damage.Attributes.Power;
	elseif (type(damage) == "number" and damage > 0) then
		-- if the damage source is a number, it takes that amount of damage.
		amount = damage
	else
		-- otherwise, no damage is taken.
		amount = 0;
	end
	-- Mitigate damage from external sources
	if (damage ~= self) then
		amount = amount - amount * self.Attributes.Toughness;
		print("Mitigating " .. (amount * self.Attributes.Toughness) .. " damage");
	end
	-- Update health
	print("Updating health to " .. self.State.Vitality.Health .. " - " .. amount .. " = " .. (self.State.Vitality.Health - amount));
	self.State.Vitality.Health = self.State.Vitality.Health - amount;
	if (self.State.Vitality.Health < 0) then
		self.State.Vitality.Health = 0;
		-- I'm gonna die!
	end
end

function MSlime:UpdateMood(moodKey, amount)
	-- If there's no valid timer for updating this value, set the reference time to now.
	if (not self.Timers.Mood[moodKey] or self.Timers.Mood[moodKey] <= 0) then
		self.Timers.Mood[moodKey] = love.timer.getTime();
	end
	-- If less than 1 second has passed, don't update.
	if (love.timer.getTime() - self.Timers.Mood[moodKey] < 1) then
		return;
	end
	-- Calculate adjusted amount based on average mood over time.
	local delta = math.floor(self.State.Mood_Avg[moodKey] - self.State.Mood[moodKey]);
	amount = amount + delta;
	-- Modify by the amount given.
	self:ModifyMood(moodKey, amount);
	-- Reset the timer.
	self.Timers.Mood[moodKey] = nil;
end

function MSlime:UpdateVitality(vitKey, amount)
	-- If there's no valid timer for updating this value, set the reference time to now.
	if (not self.Timers.Vitality[vitKey] or self.Timers.Vitality[vitKey] <= 0) then
		self.Timers.Vitality[vitKey] = love.timer.getTime();
	end
	-- If less than 1 second has passed, don't update.
	if (love.timer.getTime() - self.Timers.Vitality[vitKey] < 1) then
		return;
	end
	-- Modify by the amount given.
	self:ModifyVitality(vitKey, amount);
	-- Reset the timer.
	self.Timers.Vitality[vitKey] = nil;
end

-- Deletes the food object and modifies state accordingly.
function MSlime:Eat(food)
	-- Calculate new hunger
	local amount = food.Satisfaction;
	-- Delete the food object
	Object.Delete(food);
	
	-- Modify vitality state.
	self:ModifyVitality("Hunger", -amount);
	self:ModifyVitality("Health", amount * 0.5);
	-- Make it fat if we exceed min hunger?
end

-- Update position to move toward a target object or vector
function MSlime:MoveToward(targetPos, dt)
	-- If we're at the target, do nothing.
	if (self:GetPos() == targetPos) then
		return;
	end
	-- Figure out where we need to move.
	local direction = (targetPos - self:GetPos()):normalize();
	local offset = direction * self.Attributes.Speed * dt;
	local newPos = self:GetPos() + offset;
	-- If we're about to pass the target location, stop at the target location.
	if (((targetPos - newPos):normalize() + direction):length() <= 0.1) then
		newPos = targetPos;
	end
	if (newPos.x < 49 or newPos.x > love.graphics.getWidth()) then
		newPos = self:GetPos() + Vector(-offset.x, 0);
	end
	if (newPos.y < 49 or newPos.y > love.graphics.getHeight() - 98) then
		newPos = self:GetPos() + Vector(0, -offset.y);
	end
	-- Update position.
	self:SetPos(newPos);
end

-- Update position to move toward a target object or vector
function MSlime:MoveAway(targetPos, dt)
	-- Figure out where we need to move.
	local forward = (targetPos - self:GetPos()):normalize();
	local right = Vector(forward.y, forward.x);
	local direction = (forward + (right * (math.random(-100, 100) / 100)):normalize()):normalize();
	local offset = -(direction * self.Attributes.Speed * self.Constants.FleeSpeedMultiplier * dt);
	local newPos = self:GetPos() + offset;
	if (newPos.x < 49 or newPos.x > love.graphics.getWidth()) then
		newPos = self:GetPos() + Vector(-offset.x, 0);
	end
	if (newPos.y < 49 or newPos.y > love.graphics.getHeight() - 98) then
		newPos = self:GetPos() + Vector(0, -offset.y);
	end
	-- Update position.
	self:SetPos(newPos);
end

local function GetAffectedKeys(aiKey, aiData, amount)
	local keysToChange = {};
	for k, v in pairs(aiData) do
		-- Affect only unmodified keys
		if (k ~= aiKey) then
			-- If change is positive, then affected change will be negative, and vice-versa.
			-- That means negative affected change only be applied to keys with values greater than zero, and vice-versa.
			if ((amount > 0 and v > AI_MIN) or (amount < 0 and v < AI_MAX)) then
				table.insert(keysToChange, k);
			end
		end
	end
	return keysToChange;
end

local function GetCausedChange(keysToChange, aiData, amount)

	local changeSign = 1;
	if (amount > 0) then
		changeSign = -1;
	end

	local affectedKeys = {};
	while (#affectedKeys < #keysToChange) do
		table.insert(affectedKeys, keysToChange[#affectedKeys+1]);
	end
	table.sort(affectedKeys, function(a, b) return aiData[a] < aiData[b]; end);

	-- Find the proposed change on affected keys
	local proposedChange = math.abs(amount / #affectedKeys);
	--print("Proposed change = " .. proposedChange);

	-- Figure out the minimum value of change for each affected key.
	local baseChange = math.floor(proposedChange);
	--print("Minimum change = " .. baseChange);

	local changes = {};
	for _, ai in pairs(affectedKeys) do
		changes[ai] = baseChange * changeSign;
	end

	-- Figure out if there's some floating decimal places on the proposed change
	local floating = proposedChange - baseChange;

	-- If there are, distribute the extra decimal places as evenly as possible.
	if (floating > 0) then
		-- Calculate amount to be distributed
		--print("Proposed change has decimal = " .. floating);
		local divvy = tonumber(tostring(floating * #affectedKeys));

		-- ATTN: tonumber(tostring(f)) is a super-shady way of fixing rounding error, but it totally worked. #fml

		-- Sanity check
		if (divvy ~= tonumber(tostring(math.floor(divvy)))) then
			print("Rounding error was experienced in calculating " .. floating .. " * " .. #affectedKeys .. " : " .. divvy .. " vs " .. math.floor(divvy));
			return false;
		end

		-- Distribute as evenly as possible
		--print("Distributing: " .. divvy);
		while (divvy > 0) do
			for _, ai in pairs(affectedKeys) do
				if (divvy > 0) then
					divvy = divvy - 1;
					changes[ai] = changes[ai] + changeSign;
				end
			end
		end
	end

	local changeTxt = "";
	for k, v in pairs(changes) do
		if (string.len(changeTxt) > 0) then
			changeTxt = changeTxt .. ", ";
		end
		changeTxt = changeTxt .. k .. " = " .. v;
	end
	--print("Resulting change is: { " .. changeTxt .. " }");

	return changes;
end

-- This is kind of complicated, but basically, this keeps AI variables at a unit value.
function MSlime:ModifyMood(aiKey, amount)
	-- If the proposed key is invalid, do nothing.
	if (not self:GetMood(aiKey)) then
		return false;
	end
	
	-- Round the amount
	local amountAbs = math.abs(amount);
	local floating = amountAbs - math.floor(amountAbs);
	if (floating > 0) then
		if (floating >= 0.5) then
			amountAbs = math.ceil(amountAbs);
		else
			amountAbs = math.floor(amountAbs);
		end
		if (amount > 0) then
			amount = amountAbs;
		else
			amount = -amountAbs;
		end
	end

	-- Calculate the new value without correction.
	local newValue = self:GetMood(aiKey) + amount;

	-- Calculate correction.
	if (newValue < AI_MIN) then
		--print("Proposed amount " .. amount .. " exceeded AI_MIN - correcting to " .. (amount - newValue));
		amount = amount - newValue;
	elseif (newValue > AI_MAX) then
		--print("Proposed amount " .. amount .. " exceeded AI_MAX - correcting to " .. (amount - (newValue - AI_MAX)));
		amount = amount - (newValue - AI_MAX);
	end

	if (amount == 0) then
		--print("No changes were made to " .. aiKey);
		return false;
	end

	-- Calculate the new value.
	self:SetMood(aiKey, self:GetMood(aiKey) + amount);
	--print("Updating " .. aiKey .. " to change by " .. amount .. ", becoming " .. self.State.Mood[aiKey]);

	-- Figure out which keys also need to change as a result.
	local keysToChange = GetAffectedKeys(aiKey, self.State.Mood, amount);

	-- Update the keys that need to be changed.
	--print("Changing " .. #keysToChange .. " keys [" .. table.concat(keysToChange, ", ") .. "]");

	local change = GetCausedChange(keysToChange, self.State.Mood, amount);
	repeat
		local leftOverChange = 0;
		for _, ai in pairs(keysToChange) do
			local causedChange = change[ai];
			--print("Calculated caused change for " .. ai .. " to be " .. causedChange);
			local causedValue = self:GetMood(ai) + causedChange;
			--print("Attempting to have " .. ai .. " to change by " .. causedChange .. ", which would make it " .. causedValue);
			if (causedValue < AI_MIN) then
				leftOverChange = leftOverChange - (causedValue);
				causedValue = AI_MIN;
				--print("Change of " .. causedChange .. " in " .. ai .. " would give " .. causedValue .. " - correcting to " .. causedValue .. " - leftover becomes " .. leftOverChange);
			elseif (causedValue > AI_MAX) then
				leftOverChange = leftOverChange - (causedValue - AI_MAX);
				causedValue = AI_MAX;
				--print("Change of " .. causedChange .. " in " .. ai .. " would give " .. causedValue .. " - correcting to " .. causedValue .. " - leftover becomes " .. leftOverChange);
			end
			--print("Caused " .. ai .. " to change by " .. (causedValue - self.State.Mood[ai]) .. ", becoming " .. causedValue);
			self:SetMood(ai, causedValue);
		end
		if (leftOverChange ~= 0) then
			--print("Leftover change of " .. leftOverChange .. " was found!");
			keysToChange = GetAffectedKeys(aiKey, self.State.Mood, leftOverChange);
			--print("Need to adjust " .. #keysToChange .. " keys [" .. table.concat(keysToChange, ", ") .. "]");
			change = GetCausedChange(keysToChange, self.State.Mood, leftOverChange);
		end
	until (leftOverChange == 0);

	-- Calculate the total to see if there was an error in calculation.
	local total = 0;
	for k, v in pairs(self.State.Mood) do
		total = total + v;
	end
	if (total ~= AI_MAX) then
		--print("Math error on [" .. tostring(self) .. "]!");
		--for k, v in pairs(self.State.Mood) do
			--print(k, v);
		--end
		error("Unable to keep AI data homogenized - it became " .. total, 2);
	end

	return total == AI_MAX;
end

-- Takes a snapshot of the AI state to figure out what kind of AI config it should gravitate to.
function MSlime:TakeSnapshot()
	local snapshot = {};
	for k, v in pairs(self.State.Mood) do
		snapshot[k] = v;
	end
	table.insert(self.State.Mood_Snapshots, snapshot);
	if (#self.State.Mood_Snapshots > 10) then
		table.remove(self.State.Mood_Snapshots, 1);
	end
	local avg = {};
	for i, t in ipairs(self.State.Mood_Snapshots) do
		for k, v in pairs(t) do
			if (not avg[k]) then
				avg[k] = 0;
			end
			avg[k] = avg[k] + v;
		end
	end
	for k, v in pairs(avg) do
		avg[k] = avg[k] / #self.State.Mood_Snapshots;
	end
	self.State.Mood_Avg = avg;
end

-- The Update function
function MSlime:Update(dt)
	
	if (self.State.Vitality.Health == 0) then
		-- Kill me!
		Object.Delete(self);
		return;
	end
	
	-- Select best behaviour (automatically chooses a target)
	self:SelectBestBehaviour();
	
	local target = self:GetTarget();
	local targetPos = self:GetTargetPos();
	
	local sightDistSqr = math.pow(self.Attributes.Sight, 2);
	local distToTargetSqr = self:GetPos():distanceSqr(targetPos);
	
	local behav = self:GetBehaviour();
	--print("Current behaviour = " .. behav .. " -- target = " .. tostring(target) .. " -- target pos = " .. tostring(targetPos));
	
	-- Take snapshot every so often
	if (not self.Timers.Snapshot or self.Timers.Snapshot < 0) then
		self.Timers.Snapshot = love.timer.getTime();
	end
	if (love.timer.getTime() - self.Timers.Snapshot >= 3) then
		self:TakeSnapshot();
		self.Timers.Snapshot = nil;
	end
	
	-- Speed up the process for testing - 1 for normal.
	local testMul = 1;
	
	-- Vitality modifiers
	local healthMod = 1;
	local hungerMod = 1;
	local restedMod = -1;
	
	-- Mood modifiers
	local curiousMod = 0;
	local angryMod = 0;
	local socialMod = 0;
	
	-- Modify vitality based on behaviour.
	
	-- Behaviours that don't require moving cause better health regeneration. Fighting/Fleeing causes no regeneration.
	if (behav == "none" or behav == "rest" or behav == "eat" or behav == "use") then
		healthMod = 2;
	elseif (behav == "flee" or behav == "fight") then
		healthMod = 0;
	end
	
	-- When hunger is too high, and we don't see any food, take hunger damage.
	if (behav ~= "eat" and self:GetVitalityPercent("Hunger") > 0.90) then
		healthMod = -1; -- Hunger Damage amount
	end
	
	-- Don't increase hunger when eating.
	if (behav == "eat" and self:GetTarget() and self:GetTarget():GetEater() and self:GetTarget():GetEater() == self) then
		hungerMod = 0;
	end
	
	if (behav == "flee") then
		restedMod = -1;
	elseif (behav == "fight") then
		restedMod = -1;
	elseif (behav == "explore") then
		restedMod = -1;
	elseif (behav == "eat" or behav == "use") then
		restedMod = 0;
	elseif (behav == "rest") then
		restedMod = 3;
	end
	
	-- Modify mood based on behaviour.
	
	-- Prolonged exposure to violence adds to aggression. Time away reduces it.
	if (behav == "flee" or behav == "fight") then
		angryMod = 1; -- Add to aggression
	else
		angryMod = -1; -- Subtract from aggression
	end
	
	-- Prolonged exploratory behaviours adds to curiosity. Time away reduces it.
	if (behav == "explore" or behav == "use") then
		curiousMod = 1;
	else
		curiousMod = -1;
	end
	
	-- Do things based on behaviour
	if (behav == "none") then
		--return;
	elseif (behav == "use") then
		--self:Use(target);
	elseif (behav == "explore") then
		self:MoveToward(targetPos, dt);
	elseif (behav == "eat") then
		if (distToTargetSqr > math.pow(self.Attributes.Size + target.Size*target.Scale, 2)) then
			-- Move to the food until we reach it.
			self:MoveToward(targetPos, dt);
		else
			-- Eat the food when we get to it.
			target:SetEater(self);
			if (not self.Timers.Eating or self.Timers.Eating < 0) then
				self.Timers.Eating = love.timer.getTime();
			end
			local timeSpentEating = love.timer.getTime() - self.Timers.Eating;
			if (timeSpentEating >= self.Constants.EatTime) then
				self:Eat(target);
				self:SetTarget(nil);
				self.Timers.Eating = nil;
			end
		end
	elseif (behav == "fight") then
		if (distToTargetSqr > math.pow(self.Attributes.Size + target.Attributes.Size, 2)) then
			-- Give chase
			self:MoveToward(targetPos, dt);
		else
			-- Attack the enemy
			if (not self.Timers.Attacking or self.Timers.Attacking < 0) then
				self.Timers.Attacking = love.timer.getTime();
			end
			local timeSinceAttack = love.timer.getTime() - self.Timers.Attacking;
			if (timeSinceAttack >= 1) then
				target:TakeDamage(self);
				self.Timers.Attacking = nil;
			end
		end
	elseif (behav == "flee") then
		self:MoveAway(targetPos, dt);
	end
	
	self:UpdateVitality("Health", healthMod); -- Heal over time, or take hunger damage.
	self:UpdateVitality("Hunger", hungerMod * testMul);
	self:UpdateVitality("Rested", restedMod * testMul);
	
	self:UpdateMood("Curious", curiousMod);
	self:UpdateMood("Angry", angryMod);
	self:UpdateMood("Social", socialMod);
end

-- The Draw function
function MSlime:Draw()
	local hpMod = self:GetVitalityPercent("Health");
	local red = self:GetMood("Angry") * 2 + 55;
	local green = self:GetMood("Social") * 2 + 55;
	local blue = self:GetMood("Curious") * 2 + 55;
	love.graphics.setColor(red, green, blue);
	
	-- Draw slime
	love.graphics.circle("fill", self:GetPos().x, self:GetPos().y, self.Attributes.Size, 100);
	
	-- Draw sight radius
	love.graphics.circle("line", self:GetPos().x, self:GetPos().y, self.Attributes.Sight, 100);
	love.graphics.line( self:GetPos().x, self:GetPos().y, self:GetTargetPos().x, self:GetTargetPos().y);
	
	love.graphics.setColor(255, 255, 255);
	love.graphics.rectangle("line", self:GetPos().x + self.Attributes.Size * 0.75, self:GetPos().y - 15, 20, 10)
	love.graphics.setColor(0, 0, 0);
	love.graphics.rectangle("fill", self:GetPos().x + self.Attributes.Size * 0.75 + 1, self:GetPos().y - 15 + 1, 18, 8);
	if (hpMod > .75) then
		love.graphics.setColor(0, 0, 255);
	elseif (hpMod > .50) then
		love.graphics.setColor(0, 255, 255);
	elseif (hpMod > .25) then
		love.graphics.setColor(255, 255, 0);
	else
		love.graphics.setColor(255, 0, 0);
	end
	love.graphics.rectangle("fill", self:GetPos().x + self.Attributes.Size * 0.75 + 1, self:GetPos().y - 15 + 1, (18 * hpMod), 8);
	
	love.graphics.setColor(255, 255, 255);
	-- Draw Debug data:
	local data = "";
	data = data .. "Behaviour" .. " = " .. tostring(self.State.Behaviour) .. "\n";
	data = data .. "Target" .. " = " .. tostring(self:GetTarget()) .. "\n";
	data = data .. "---\n";
	for k, v in pairs(self.State.Mood) do
		if (not self.State.Mood_Avg[k]) then
			self.State.Mood_Avg[k] = v;
		end
		data = data .. k .. " = " .. v .. " (" .. self.State.Mood_Avg[k] .. ")\n";
	end
	data = data .. "---\n";
	for k, v in pairs(self.State.Vitality) do
		data = data .. k .. " = " .. v .. "\n";
	end
	love.graphics.printf(data, self:GetPos().x + self.Attributes.Size + 1, self:GetPos().y + 5, 200, "left")
	
end

-- End Slime Metatable

-- Define Slime Constructor
local MakeSlime = function(pos, isEnemy, aiData)
	local t = {};
	CopyRecur(SlimeConfig, t);
	if (aiData) then
		HomogenizeAI(aiData);
		--print(aiData.Curious, aiData.Angry, aiData.Hunger);
		CopyRecur(aiData, t.State.Mood);
		--print(t.State.Mood.Curious, t.State.Mood.Angry, t.State.Mood.Hunger);
	end
	t.IsEnemy = isEnemy;
	t.pos = pos;
	return t;
end

return function()
	Object.Register(SlimeFactoryName, MSlime, MakeSlime);
end


