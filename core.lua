local _, class = UnitClass("player");
if (class == "MAGE" or class == "WARLOCK" or class == "PRIEST") then
	return;
end

local GetTime = GetTime;
local FormatTime = AzCastBar.FormatTime;

-- Extra Options
local extraOptions = {
	{
		[0] = "Colors",
		{ type = "Color", var = "colNormal", default = { 0.4, 0.6, 0.8 }, label = "Normal Swing Color" },
		{ type = "Color", var = "colParry", default = { 1, 0.75, 0.5 }, label = "Parry Color" },
	},
};

-- Variables
local plugin = AzCastBar.CreateMainBar("Frame","Swing",extraOptions);
local off_plugin = AzCastBar.CreateMainBar("Frame","Swing",extraOptions);
local pName = UnitName("player");

-- Localized Names
local slam = GetSpellInfo(1464);
local autoShot = GetSpellInfo(75);
local wandShot = GetSpellInfo(5019);
local meleeSwing = GetLocale() == "enUS" and "Melee Swing" or GetSpellInfo(6603);

local Whammy = CreateFrame("FRAME", nil, UIParent);
Whammy.DualWield = nil;
Whammy.Ranged = nil;

-- relevant inventory slots
Whammy.MAINHAND_SLOT = GetInventorySlotInfo("MainHandSlot");
Whammy.OFFHAND_SLOT = GetInventorySlotInfo("SecondaryHandSlot");
-- ranged slot no longer exists

-- relevant spell ids
Whammy.RANGED_SPELL = {
  [75] = true,   -- Hunter AutoShot
  [5019] = true  -- Mage/Priest/Warlock Shoot Wand
}

-- relevant handedness strings
-- TODO: replace with non-string based detection if possible (should fix for all localizations)
local DETECT_DUALWIELD = {};
DETECT_DUALWIELD["One-Hand"] = true;
DETECT_DUALWIELD["Two-Hand"] = true;
DETECT_DUALWIELD["Off Hand"] = true;
--[[local spellSwingReset = {
	[GetSpellInfo(78)] = true,		-- Heroic Strike
	[GetSpellInfo(845)] = true,		-- Cleave
	[GetSpellInfo(2973)] = true,	-- Raptor Strike
	[GetSpellInfo(6807)] = true,	-- Maul
	[GetSpellInfo(56815)] = true,	-- Rune Strike
};]]

--------------------------------------------------------------------------------------------------------
--                                           Frame Scripts                                            --
--------------------------------------------------------------------------------------------------------

local function OnUpdate(self,elapsed)

	itemId = GetInventoryItemID("player", 16)
	itemIcon = GetItemIcon(itemId)
	self.icon:SetTexture(itemIcon)
	-- No update on slam suspend
	if (self.slamStart) then
		return;
	-- Progression
	elseif (not self.fadeTime) then
		self.timeLeft = max(0,self.startTime + self.duration - GetTime());
		self.status:SetValue(self.duration - self.timeLeft);
		self:SetTimeText(self.timeLeft);
		if (self.timeLeft == 0) then
			self.fadeTime = self.cfg.fadeTime;
		end
	-- FadeOut
	elseif (self.fadeElapsed < self.fadeTime) then
		self.fadeElapsed = (self.fadeElapsed + elapsed);
		self:SetAlpha(self.cfg.alpha - self.fadeElapsed / self.fadeTime * self.cfg.alpha);
	else
		self:Hide();
	end
end

--------------------------------------------------------------------------------------------------------
--                                           Event Handling                                           --
--------------------------------------------------------------------------------------------------------

local function StartSwing(time,text)
	plugin.duration = time;
	plugin.name:SetText(text);
	plugin.startTime = GetTime();
	plugin.status:SetMinMaxValues(0,time);
	plugin.status:SetStatusBarColor(unpack(plugin.cfg.colNormal));
	plugin.totalTimeText = (plugin.cfg.showTotalTime and " / "..FormatTime(time,1) or nil);
	plugin.fadeTime = nil;
	plugin.fadeElapsed = 0;
	plugin:SetAlpha(plugin.cfg.alpha);
	plugin:Show();
end

local who = 1
local oldtimestamp = 0
local time1 = 0
local time2 = 0
-- Combat Log Parser
function plugin:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp , type, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID,destName,destFlags,...)
	-- Something our Player does
	-- print("[1] "..timestamp)
	-- print("[2] "..type)
	-- print("[3] "..hideCaster)
	-- print("[4] "..sourceName)
	-- print("[5] "..sourceGUID)
	-- print("[6] "..sourceFlags)
	-- print("[7] "..destGUID)
	-- print("[8] "..destName)
	-- print("[9] "..destFlags)

	
	if (sourceName == pName) then
		local prefix, suffix = type:match("(.-)_(.+)");
		
		-- print(prefix)
		if (prefix == "SWING") then
			--print(who)
			local mainhand,offhand = UnitAttackSpeed("player")
			local speed = mainhand
			if(offhand) then
				local next1 = timestamp  - time1
				local next2 = timestamp  - time2
				--print("[1]"..next1)
				--print("[2]"..next2)
				if(next1 > next2)then
					speed = next1 - mainhand
				else
					speed = next2 - offhand
				end
				speed = mainhand - (timestamp - oldtimestamp)
				-- print("[S]->"..speed)
				-- print("[D]->"..timestamp - oldtimestamp)
			end
			StartSwing(speed, meleeSwing)
			oldtimestamp = timestamp
			if (who ==  1) then
				who = 2
			else
				who = 1
			end
			if(who == 1)then
				time1 = timestamp
			else
				time2 = timestamp
			end
			-- if (who == 2) then
				-- oldtimestamp = timestamp
			-- end
		end
		
	-- Something Happens to our Player
	elseif (destName == pName) then
		local prefix, suffix = type:match("(.-)_(.+)");
		local missType = ...;
		-- Az: the info on wowwiki seemed obsolete, so this might not be 100% correct, I had to ignore the 20% rule as that didn't seem to be correct from tests
		if (prefix == "SWING") and (suffix == "MISSED") and (self.duration) and (missType == "PARRY") then
			local newDuration = (self.duration * 0.6);
--			local newTimeLeft = (self.startTime + newDuration - GetTime());
			self.duration = newDuration;
			self.status:SetMinMaxValues(0,self.duration);
			self.status:SetStatusBarColor(unpack(self.cfg.colParry));
			self.totalTimeText = (self.cfg.showTotalTime and " / "..FormatTime(self.duration,1) or nil);
		end
	end
end

-- Spell Cast Succeeded
function plugin:UNIT_SPELLCAST_SUCCEEDED(event,unit,spell,id)
	if (unit == "player") then
		if (spell == autoShot) or (spell == wandShot) then
			StartSwing(UnitRangedDamage("player"),spell);
		elseif (spell == slam) and (self.slamStart) then
			self.startTime = (self.startTime + GetTime() - self.slamStart);
			self.slamStart = nil;
		-- Az: cata has no spells that are on next melee afaik?
--		elseif (spellSwingReset[spell]) then
--			StartSwing(UnitAttackSpeed("player"),meleeSwing);
		end
	end
end

-- Warrior Only
-- if (class == "WARRIOR") then
	-- -- Spell Cast Start
	-- function plugin:UNIT_SPELLCAST_START(event,unit,spell,id)
		-- if (unit == "player") and (spell == slam) then
			-- self.slamStart = GetTime();
		-- end
	-- end
	-- -- Spell Cast Interrupted
	-- function plugin:UNIT_SPELLCAST_INTERRUPTED(event,unit,spell,id)
		-- if (unit == "player") and (spell == slam) and (self.slamStart) then
			-- self.slamStart = nil;
		-- end
	-- end
-- end

-- OnConfigChanged
function plugin:OnConfigChanged(cfg)
	if (true) then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
		if (class == "WARRIOR") then
			self:RegisterEvent("UNIT_SPELLCAST_START");
			self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
		end
	else
		self:UnregisterAllEvents();
	end
end

--------------------------------------------------------------------------------------------------------
--                                          Initialise Plugin                                         --
--------------------------------------------------------------------------------------------------------

plugin:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
plugin:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
itemId = GetInventoryItemID("player", 16)
itemIcon = GetItemIcon(itemId)
plugin.icon:SetTexture(itemIcon)
plugin:SetScript("OnUpdate",OnUpdate)

