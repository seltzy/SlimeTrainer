
local Object = require("util.object");
local Vector = require("util.vector");

local function CopyRecur(source, dest)
	for k, v in pairs(source) do
		if (not dest[k]) then
			if (type(v) == "table") then
				dest[k] = {};
				CopyRecur(v, dest[k]);
			else
				dest[k] = v;
			end
		end
	end
end

local AI_MAX = 100;
local AI_MIN = 0;

--[[
  Slime Factory
--]]
local SlimeFactoryName = "slime";
local SlimeConfig = {
	Timers = {
		Hunger = -1,
		Attacking = -1,
		Eating = -1,
		Recovery = -1
	},
	Interaction = {
		Attackers = {}
	},
	Constants = {
		EatTime = 3, -- Time it takes to eat food in seconds
		HungerDamageAmount = 10, -- Amount of damage to take from hunger
		HungerDamageThreshold = 80, -- Threshold value of the Hunger state variable for hunger damage
		FleeDamageThreshold = 80, -- Threshold value for percent health missing before fleeing
		FleeSpeedModifier = 3
	},
	Attributes = {
		MaxHealth = 100,
		Speed = 100, -- units moved/sec
		Power = 10, -- dmg dealt/sec
		Toughness = 0.0, -- %dmg mitigated
		Metabolism = 1, -- additional hunger/sec
		Recover = 1, -- additional health/sec
		Size = 10, -- physical radius of the slime
		Sight = 100 -- distance it can see in units
	},
	State = {
		Health = 100, -- current hp
		-- AI State
		AI = {
			-- The following are percentages, ranging from 0 to 1
			Curiosity = 34, -- how likely it is to explore on its own (0 = completely idle, 1 = exploring whenever possible)
			Aggression = 33, -- how likely it is to fight, give chase, or flee  (0 = completely docile, 1 = extremely irritable)
			Hunger = 33 -- how likely it is to respond to food sources (0 = completely satisfied, 1 = starving)
		},
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
	
-- Start Slime Metatable
local MSlime = {};
MSlime.__index = MSlime;
MSlime.Type = SlimeFactoryName;

MSlime.Desire = {
	flee = function(slime)
		local hpLeft = slime:GetHealth() / slime:GetMaxHealth();
		local aggro = slime.State.AI.Aggression / 100;
		--local behav = slime:GetBehaviour();
		local target = slime:GetClosestEnemy();
		if (not target) then
			return 0, nil;
		end
		return 1 - (hpLeft * aggro), target;
	end,
	fight = function(slime)
		local hpLeft = slime:GetHealth() / slime:GetMaxHealth();
		local aggro = slime.State.AI.Aggression / 100;
		local target = slime:GetClosestEnemy(slime.Attributes.Sight * 0.75);
		if (not target) then
			return 0, nil;
		end
		return (hpLeft * aggro), target;
	end,
	eat = function(slime)
		local hunger = slime.State.AI.Hunger / 100;
		local target = slime:GetClosestFood();
		if (not target or hunger < .1) then
			return 0, nil;
		end
		return hunger, target;
	end,
	explore = function(slime)
		local curious = slime.State.AI.Curiosity / 100;
		local hunger = slime.State.AI.Hunger / 100;
		local target = slime:GetPos() + Vector.Random(slime.Attributes.Sight);
		while (target.x < 0 or target.x > love.graphics.getWidth() or target.y < 0 or target.y > love.graphics.getHeight()) do
			target = slime:GetPos() + Vector.Random(slime.Attributes.Sight);
		end
		if (hunger < .1) then
			hunger = 0;
		end
		return math.max(curious, hunger), target;
	end,
	rest = function(slime)
		local hpLeft = slime:GetHealth() / slime:GetMaxHealth();
		return 1 - hpLeft, (math.random(75, 100) / 100);
	end,
	use = function(slime)
		local curious = slime.State.AI.Curiosity / 100;
		local target = slime:GetClosestObjective();
		if (not target) then
			return 0, nil;
		end
		return curious, target;
	end,
	none = function(slime)
		return 1, nil;
	end
};
MSlime.BehaviourOrder = {"flee", "fight", "eat", "rest", "explore", "use", "none"};

local function GetClosest(obj, objList)
	local t = {};
	local closest = 99999;
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

local function FilterTargets(targets, func)
	local t = {};
	for _, obj in pairs(targets) do
		if (not func(obj)) then
			table.insert(t, obj);
		end
	end
	return t;
end

function MSlime:FindInImmediateArea(typeName, radius)
	local t = {};
	if (not radius) then
		radius = self.Attributes.Sight;
	end
	for _, obj in pairs(Object.GetAll()) do
		if (obj ~= self and obj:GetType() == typeName and self:GetPos():distance(obj:GetPos()) <= radius) then
			table.insert(t, obj);
		end
	end
	return t;
end
function MSlime:GetClosestFood(radius)
	local objs = self:FindInImmediateArea("food", radius);
	objs = FilterTargets(objs, function(obj) if (obj.Eater and obj.Eater:GetBehaviour() ~= "eat") then obj.Eater = nil; end return obj.Eater; end);
	objs = GetClosest(self, objs);
	if (#objs > 0) then
		-- go eat the food
		return objs[math.random(1, #objs)];
	else
		return nil;
	end
end
function MSlime:GetClosestEnemy(radius)
	local objs = self:FindInImmediateArea("slime", radius);
	--objs = FilterTargets(objs, function(obj) return obj.IsEnemy == self.IsEnemy; end);
	objs = GetClosest(self, objs);
	if (#objs > 0) then
		-- go eat the food
		return objs[math.random(1, #objs)];
	else
		return nil;
	end
end
function MSlime:GetClosestObjective(radius)
	local objs = self:FindInImmediateArea("objective", radius);
	objs = FilterTargets(objs, function(obj) return obj.IsEnemy ~= self.IsEnemy; end);
	objs = GetClosest(self, objs);
	if (#objs > 0) then
		-- go eat the food
		return objs[math.random(1, #objs)];
	else
		return nil;
	end
end

function MSlime:CalculateDesire()
	local curDesire = {};
	for i, b in pairs(self.BehaviourOrder) do
		local desire, target = self.Desire[b](self);
		--print("Calculated " .. b .. " desire:\t", desire, target);
		if (not desire or desire < 0) then
			desire = 0;
		end
		curDesire[b] = {desire, target};
	end
	return curDesire;
end

function MSlime:GetDisiredBehaviour()
	local desireVars = self:CalculateDesire();
	for i, b in pairs(self.BehaviourOrder) do
		local nextBehaviour = self.BehaviourOrder[i+1];
		local desire, target = unpack(desireVars[b]);
		--print("Comparing " .. b .. " desire:\t", unpack(desireVars[b]));
		if (not nextBehaviour or (desire > 0 and desire >= desireVars[nextBehaviour][1])) then
			return b, target;
		end
	end
	return "none", nil;
end

function MSlime:SelectBestBehaviour()
	local behav, target = self:GetDisiredBehaviour();
	if (behav ~= self:GetBehaviour()) then
		self:SetTarget(nil);
	end
	if (behav == "flee") then
		self:SetTarget(target);
	elseif (behav == "fight") then
		if (not self:GetTarget()) then
			self:SetTarget(target);
		end
	elseif (behav == "eat") then
		if (not self:GetTarget()) then
			self:SetTarget(target);
		end
	elseif (behav == "rest") then
		if (not self:GetTarget()) then
			self:SetTarget(target);
		end
	elseif (behav == "explore") then
		if (not self:GetTarget() or self:GetPos():distance(self:GetTargetPos()) == 0) then
			self:SetTarget(target);
		end
	elseif (behav == "use") then
		if (not self:GetTarget()) then
			self:SetTarget(self:GetClosestObjective());
		end
	else
		self:SetTarget(nil);
	end
	self.State.Behaviour = behav;
end

-- Accessors for current target (used by AI)
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
function MSlime:GetHealth()
	return self.State.Health;
end
function MSlime:GetMaxHealth()
	return self.Attributes.MaxHealth;
end
function MSlime:GetBehaviour()
	return self.State.Behaviour;
end

-- Take damage
function MSlime:TakeDamage(damage)
	local amount;
	if (damage == self) then
		-- if the damage source is itself, it takes hunger damage.
		amount = self.Constants.HungerDamageAmount;
	elseif (type(damage) == "table" and damage:GetType() == "slime") then
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
	end
	-- Update health
	self.State.Health = self.State.Health - amount;
	if (self.State.Health < 0) then
		self.State.Health = 0;
		-- I'm gonna die!
	end
end

-- Increases hunger depending on metabolism - a multiplier may be provided to increase metabolism (def: 1)
function MSlime:UpdateHunger(modifier)
	if (not self.Timers.Hunger or self.Timers.Hunger < 0) then
		self.Timers.Hunger = love.timer.getTime();
	end
	if (love.timer.getTime() - self.Timers.Hunger < 1) then
		--print("Hunger timer: " .. love.timer.getTime() .. " - " .. self.State.AI.Hunger .. " = " .. (love.timer.getTime() - self.Timers.Hunger));
		return;
	end
	
	-- Calculate new hunger
	if (not modifier) then
		modifier = 1;
	end
	local amount = (self.Attributes.Metabolism * modifier);
	self:ModifyAI("Hunger", amount);
	self.Timers.Hunger = love.timer.getTime();
	
	--print("Updating hunger on [" .. tostring(self) .. "] to " .. self.State.AI.Hunger);
	
	-- Take damage if we exceed max hunger
	if (self.State.AI.Hunger > self.Constants.HungerDamageThreshold) then
		--print("Taking hunger damage...");
		self:TakeDamage(self.Constants.HungerDamageAmount, self); 
	end
end

-- Increases hunger depending on metabolism - a multiplier may be provided to increase metabolism (def: 1)
function MSlime:UpdateHealth(modifier)
	if (not self.Timers.Recovery or self.Timers.Recovery < 0) then
		self.Timers.Recovery = love.timer.getTime();
	end
	if (love.timer.getTime() - self.Timers.Recovery < 1) then
		return;
	end
	
	-- Calculate new hunger
	if (not modifier) then
		modifier = 1;
	end
	local amount = (self.Attributes.Recover * modifier);
	self.State.Health = self:GetHealth() + amount
	if (self:GetHealth() > self:GetMaxHealth()) then
		self.State.Health = self:GetMaxHealth();
	end
	
	self.Timers.Recovery = love.timer.getTime();
end

function MSlime:Eat(food)
	-- Calculate new hunger
	local amount = food.Satisfaction;
	self:ModifyAI("Hunger", -amount);
	Object.Delete(food);
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
	if (newPos.x < 0 or newPos.x > love.graphics.getWidth()) then
		newPos = self:GetPos() + Vector(-offset.x, 0);
	end
	if (newPos.y < 0 or newPos.y > love.graphics.getHeight()) then
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
	local offset = -(direction * self.Attributes.Speed * self.Constants.FleeSpeedModifier * dt);
	local newPos = self:GetPos() + offset;
	if (newPos.x < 0 or newPos.x > love.graphics.getWidth()) then
		newPos = self:GetPos() + Vector(-offset.x, 0);
	end
	if (newPos.y < 0 or newPos.y > love.graphics.getHeight()) then
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

		-- Sanity check this shit
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
function MSlime:ModifyAI(aiKey, amount)
	-- If the proposed key is invalid, do nothing.
	if (not self.State.AI[aiKey]) then
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
	local newValue = self.State.AI[aiKey] + amount;

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
	self.State.AI[aiKey] = self.State.AI[aiKey] + amount;
	--print("Updating " .. aiKey .. " to change by " .. amount .. ", becoming " .. self.State.AI[aiKey]);

	-- Figure out which keys also need to change as a result.
	local keysToChange = GetAffectedKeys(aiKey, self.State.AI, amount);

	-- Update the keys that need to be changed.
	--print("Changing " .. #keysToChange .. " keys [" .. table.concat(keysToChange, ", ") .. "]");

	local change = GetCausedChange(keysToChange, self.State.AI, amount);
	repeat
		local leftOverChange = 0;
		for _, ai in pairs(keysToChange) do
			local causedChange = change[ai];
			--print("Calculated caused change for " .. ai .. " to be " .. causedChange);
			local percent = self.State.AI[ai];
			--print("Adjusting affected key " .. ai .. " currently at " .. percent);
			local causedValue = self.State.AI[ai] + causedChange;
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
			--print("Caused " .. ai .. " to change by " .. (causedValue - self.State.AI[ai]) .. ", becoming " .. causedValue);
			self.State.AI[ai] = causedValue;
		end
		if (leftOverChange ~= 0) then
			--print("Leftover change of " .. leftOverChange .. " was found!");
			keysToChange = GetAffectedKeys(aiKey, self.State.AI, leftOverChange);
			--print("Need to adjust " .. #keysToChange .. " keys [" .. table.concat(keysToChange, ", ") .. "]");
			change = GetCausedChange(keysToChange, self.State.AI, leftOverChange);
		end
	until (leftOverChange == 0);

	-- Calculate the total to see if there was an error in calculation.
	local total = 0;
	for k, v in pairs(self.State.AI) do
		total = total + v;
	end
	if (total > AI_MAX or total < AI_MIN) then
		--print("Math error on [" .. tostring(self) .. "]!");
		--for k, v in pairs(self.State.AI) do
			--print(k, v);
		--end
		error("Unable to keep AI data unit-sized - it became " .. total, 2);
	end

	return total == AI_MAX;
end

-- The Update function
function MSlime:Update(dt)
	
	if (self.State.Health == 0) then
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
	
	local behav = self.State.Behaviour;
	--print("Current behaviour = " .. behav .. " -- target = " .. tostring(target) .. " -- target pos = " .. tostring(targetPos));
	
	if (behav ~= "rest") then
		-- Update hunger
		self:UpdateHunger();
		self:UpdateHealth();
	end
	
	if (behav == "none") then
		return;
	elseif (behav == "rest") then
		--if (self:GetHealth() < self:GetMaxHealth() * self:GetTarget()) then
			self:UpdateHealth(10);
		--end
	elseif (behav == "use") then
		--self:Use(target);
	elseif (behav == "explore") then
		self:MoveToward(targetPos, dt);
	elseif (behav == "eat") then
		if (distToTargetSqr > math.pow(self.Attributes.Size + target.Size, 2)) then
			-- Move to the food until we reach it.
			self:MoveToward(targetPos, dt);
		else
			-- Eat the food.
			if (self.Timers.Eating < 0) then
				self.Timers.Eating = love.timer.getTime();
				target.Eater = self;
			end
			local timeSpentEating = love.timer.getTime() - self.Timers.Eating;
			if (timeSpentEating >= self.Constants.EatTime) then
				self:Eat(target);
				self:SetTarget(nil);
				self.Timers.Eating = -1;
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
				self.Timers.Attacking = love.timer.getTime();
			end
			-- If the enemy dies...
			--if (target.State.Health <= 0) then
			--	self:SetTarget(nil);
			--end
		end
	elseif (behav == "flee") then
		self:MoveAway(targetPos, dt);
	end
end

-- The Draw function
function MSlime:Draw()
	local hpMod = (self.State.Health / self.Attributes.MaxHealth);
	local red = self.State.AI.Aggression * 2 + 55;
	local green = self.State.AI.Hunger * 2 + 55;
	local blue = self.State.AI.Curiosity * 2 + 55;
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
	-- Draw AI data:
	local data = "";
	data = data .. "Behaviour" .. " = " .. tostring(self.State.Behaviour) .. "\n";
	for k, v in pairs(self.State.AI) do
		data = data .. k .. " = " .. v .. "\n";
	end
	data = data .. "Target" .. " = " .. tostring(self:GetTarget()) .. "\n";
	love.graphics.printf(data, self:GetPos().x + self.Attributes.Size + 1, self:GetPos().y + 5, 200, "left")
	
end

-- End Slime Metatable

-- Define Slime Constructor
local MakeSlime = function(pos, isEnemy, attributes)
	local t = {};
	CopyRecur(SlimeConfig, t);
	t.IsEnemy = isEnemy;
	t.pos = pos;
	return t;
end

return function()
	Object.Register(SlimeFactoryName, MSlime, MakeSlime);
end


--[[
function MSlime:GetDominantAIs()
	local dominant = {};
	local largest = 0;
	for ai, percent in pairs(self.State.AI) do
		if (percent > largest) then
			largest = percent;
			dominant = {ai};
		elseif (percent == largest) then
			table.insert(dominant, ai);
		end
	end
	return dominant;
end
function MSlime:SelectBestBehaviour()
	local behav = "none";
	-- Randomly select from the list of dominant AIs (usually there should only be one).
	local dominant = {};
	for ai, percent in pairs(self.State.AI) do
		table.insert(dominant, ai);
	end
	table.sort(dominant, function(a, b) return self.State.AI[a] > self.State.AI[b]; end);
	while (not behav) do
		if (#dominant < 1) then
			-- decide whether to explore or do nothing
			if (math.random(AI_MIN, AI_MAX) <= self.State.AI.Curiosity) then
				behav = "explore";
			else
				behav = "none";
			end
		else
			local chosen = 1; --math.random(1, #dominant);
			if (dominant[chosen] == "Hunger") then
				-- look for food in surrounding area
				local foods = self:FindInImmediateArea("food");
				foods = FilterTargets(foods, function(obj) return not obj.Eater; end);
				foods = GetClosest(self, foods);
				if (#foods > 0) then
					-- go eat the food
					local target = foods[math.random(1, #foods)];
					target.Eater = self;
					self:SetTarget(target);
					behav = "eat";
				else
					table.remove(dominant, chosen);
				end
			elseif (dominant[chosen] == "Aggression") then
				-- look for slimes in surrounding area
				local enemies = self:FindInImmediateArea("slime");
				-- filter out non-enemies
				--enemies = FilterTargets(enemies, function(obj) return obj.IsEnemy ~= self.IsEnemy; end);
				enemies = GetClosest(self, enemies);
				if (#enemies > 0) then
					-- go attack a random enemy
					local target = enemies[math.random(1, #enemies)];
					self:SetTarget(target);
					behav = "attack";
				else
					table.remove(dominant, chosen);
				end
			elseif (dominant[chosen] == "Curiosity") then
				-- look for objectives in surrounding area
				-- otherwise, explore
				behav = "explore";
			end
		end
	end
	self.State.Behaviour = behav;
end]]

--[[function MSlime:Update(dt)
	-- Update hunger
	self:UpdateHunger();
	
	if (self.State.Health == 0) then
		-- Kill me!
		Object.Delete(self);
		return;
	end
	
	local target = self:GetTarget();
	local targetPos = self:GetTargetPos();
	
	local sightDistSqr = math.pow(self.Attributes.Sight, 2);
	local distToTargetSqr = self:GetPos():distanceSqr(targetPos);
	
	local behav = self.State.Behaviour;
	print("Current behaviour = " .. behav .. " -- target = " .. tostring(target));
	if (behav == "none" or behav == "explore") then
		-- if we're exploring, choose a random direction to go in.
		if (behav == "explore") then
			if (not target) then
				local pos = self:GetPos();
				local randVec = Vector.Random(self.Attributes.Sight);
				self:SetTarget(pos + randVec);
				target = self:GetTarget();
				targetPos = self:GetTargetPos();
				print("Selected random target = " .. tostring(target));
			end
			if (self:GetPos() == targetPos) then
				self.State.Behaviour = "none";
				self:SetTarget(nil);
			else
				self:MoveToward(targetPos, dt);
			end
		end
	
		-- examine state vars
		self:SelectBestBehaviour();
		print("Selected best behaviour = " .. self.State.Behaviour);
		
	elseif (behav == "eat") then
		if (not target or target:GetType() ~= "food" or distToTargetSqr > sightDistSqr) then
			self.State.Behaviour = "none";
			self:SetTarget(nil);
		else
			if (distToTargetSqr > math.pow(self.Attributes.Size + target.Size, 2)) then
				-- Move to the food until we reach it.
				self:MoveToward(targetPos, dt);
			else
				-- Eat the food.
				if (self.Timers.Eating < 0) then
					self.Timers.Eating = love.timer.getTime();
					target.Eater = self;
				end
				local timeSpentEating = love.timer.getTime() - self.Timers.Eating;
				if (timeSpentEating >= self.Constants.EatTime) then
					self:Eat(target);
					self.State.Behaviour = "none";
					self:SetTarget(nil);
					self.Timers.Eating = -1;
				end
			end
		end
		
	elseif (behav == "attack") then
		if (not target or target:GetType() ~= "slime" or target.IsEnemy == false or distToTargetSqr > sightDistSqr) then
			self.State.Behaviour = "none";
			self:SetTarget(nil);
		else
			if (100 * (self.State.Health / self.Attributes.MaxHealth) < self.State.AI.Aggression / 2) then
				-- If lack of health outweighs aggression, flee!
				self.State.Behaviour = "flee";
			elseif (distToTargetSqr > math.pow(self.Attributes.Size + target.Attributes.Size, 2)) then
				-- Give chase
				self:MoveToward(targetPos, dt);
				
				-- TODO: maybe do a fancier check for whether we're bored of chasing.
				self:SelectBestBehaviour();
				
			else
				-- Attack the enemy
				if (not self.Timers.Attacking or self.Timers.Attacking < 0) then
					self.Timers.Attacking = love.timer.getTime();
				end
				local timeSinceAttack = love.timer.getTime() - self.Timers.Attacking;
				if (timeSinceAttack >= 1) then
					target:TakeDamage(self);
					self.Timers.Attacking = love.timer.getTime();
				end
				-- If the enemy dies...
				if (target.State.Health <= 0) then
					self.State.Behaviour = "none";
					self:SetTarget(nil);
				end
			end
		end
	elseif (behav == "flee") then
		if (not target or target:GetType() ~= "slime" or target.IsEnemy == false or distToTargetSqr > sightDistSqr or target.State.Behaviour ~= "attack" or target:GetTarget() ~= self) then
			self.State.Behaviour = "none";
			self:SetTarget(nil);
		else
			self:MoveAway(targetPos, dt);
		end
	end
end]]

