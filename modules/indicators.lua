local Indicators = {}
local raidUnits, partyUnits = ShadowUF.raidUnits, ShadowUF.partyUnits
local indicatorList = {"status", "pvp", "leader", "masterLoot", "raidTarget", "happiness", "ready"}

ShadowUF:RegisterModule(Indicators, "indicators", ShadowUFLocals["Indicators"])

function Indicators:UpdateHappiness(frame)
	if( not frame.indicators.happiness.enabled ) then return end

	local happyHappy = GetPetHappiness()
	if( not happyHappy ) then
		frame.indicators.happiness:Hide()
	elseif( happyHappy == 3 ) then
		frame.indicators.happiness:SetTexCoord(0, 0.1875, 0, 0.359375)
		frame.indicators.happiness:Show()
	elseif( happyHappy == 2 ) then
		frame.indicators.happiness:SetTexCoord(0.1875, 0.375, 0, 0.359375)
		frame.indicators.happiness:Show()
	elseif( happyHappy == 1 ) then
		frame.indicators.happiness:SetTexCoord(0.375, 0.5625, 0, 0.359375)
		frame.indicators.happiness:Show()
	end
end

function Indicators:UpdateMasterLoot(frame)
	if( not frame.indicators.masterLoot.enabled ) then return end

	local lootType, partyID, raidID = GetLootMethod()
	if( lootType ~= "master" ) then
		frame.indicators.masterLoot:Hide()
	elseif( ( partyID and partyID == 0 and UnitIsUnit(frame.unit, "player") ) or ( partyID and partyID > 0 and UnitIsUnit(frame.unit, partyUnits[partyID]) ) or ( raidID and raidID > 0 and UnitIsUnit(frame.unit, raidUnits[raidID]) ) ) then
		frame.indicators.masterLoot:Show()
	else
		frame.indicators.masterLoot:Hide()
	end
end
			
function Indicators:UpdateRaidTarget(frame)
	if( not frame.indicators.raidTarget.enabled ) then return end

	if( UnitExists(frame.unit) and GetRaidTargetIndex(frame.unit) ) then
		SetRaidTargetIconTexture(frame.indicators.raidTarget, GetRaidTargetIndex(frame.unit))
		frame.indicators.raidTarget:Show()
	else
		frame.indicators.raidTarget:Hide()
	end
end
			
function Indicators:UpdateLeader(frame)
	if( not frame.indicators.leader.enabled ) then return end

	if( UnitIsPartyLeader(frame.unit) ) then
		frame.indicators.leader:Show()
	else
		frame.indicators.leader:Hide()
	end
end

function Indicators:UpdatePVPFlag(frame)
	if( not frame.indicators.pvp.enabled ) then return end

	if( UnitIsPVP(frame.unit) and UnitFactionGroup(frame.unit) ) then
		frame.indicators.pvp:SetTexture(string.format("Interface\\TargetingFrame\\UI-PVP-%s", UnitFactionGroup(frame.unit)))
		frame.indicators.pvp:Show()
	elseif( UnitIsPVPFreeForAll(frame.unit) ) then
		frame.indicators.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		frame.indicators.pvp:Show()
	else
		frame.indicators.pvp:Hide()
	end
end

function Indicators:UpdateStatus(frame)
	if( not frame.indicators.status.enabled ) then return end

	if( UnitAffectingCombat(frame.unit) ) then
		frame.indicators.status:SetTexCoord(0.50, 1.0, 0.0, 0.49)
		frame.indicators.status:Show()
	elseif( frame.unit == "player" and IsResting() ) then
		frame.indicators.status:SetTexCoord(0.0, 0.50, 0.0, 0.421875)
		frame.indicators.status:Show()
	else
		frame.indicators.status:Hide()
	end
end

local function fadeReadyStatus(self, elapsed)
	self.timeLeft = self.timeLeft - elapsed
	self.ready:SetAlpha(self.timeLeft / self.startTime)
	
	if( self.timeLeft <= 0 ) then
		self:SetScript("OnUpdate", nil)

		self.ready.status = nil
		self.ready:Hide()
	end
end

function Indicators:UpdateReadyCheck(frame, event)
	if( not frame.indicators.ready.enabled ) then return end

	-- We're done, and should fade it out if it's shown
	if( event == "READY_CHECK_FINISHED" ) then
		if( frame.indicators.ready:IsShown() ) then
			frame.indicators.startTime = 6
			frame.indicators.timeLeft = frame.indicators.startTime
			frame.indicators:SetScript("OnUpdate", fadeReadyStatus)
			
			if( frame.indicators.ready.status == "waiting" ) then
				frame.indicators.ready:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
			end
		end
		return
	end
	
	-- Have a state change in ready status
	local status = GetReadyCheckStatus(frame.unit)
	if( not status ) then
		frame.indicators.ready.status = nil
		frame.indicators.ready:Hide()
		return
	end
	
	frame.indicators:SetScript("OnUpdate", nil)
	frame.indicators.ready.status = status
	frame.indicators.ready:SetAlpha(1.0)
	frame.indicators.ready:SetTexture((status == "ready" and READY_CHECK_READY_TEXTURE or status == "notready" and READY_CHECK_NOT_READY_TEXTURE or status == "waiting" and READY_CHECK_WAITING_TEXTURE))
	frame.indicators.ready:Show()
end

function Indicators:OnEnable(frame)
	-- Forces the indicators to be above the bars/portraits/etc
	if( not frame.indicators ) then
		frame.indicators = CreateFrame("Frame", nil, frame)
		frame.indicators:SetFrameLevel(frame.topFrameLevel)
		frame.indicators.list = indicatorList
	else
		-- Just start off fresh
		frame:UnregisterAll(self)
		
		for _, key in pairs(frame.indicators.list) do
			if( frame.indicators[key] ) then
				frame.indicators[key]:Hide()
			end
		end
	end
	
	-- Now lets enable all the indicators
	local config = ShadowUF.db.profile.units[frame.unitType]
	if( config.indicators.status and config.indicators.status.enabled ) then
		frame:RegisterNormalEvent("PLAYER_REGEN_ENABLED", self, "UpdateStatus")
		frame:RegisterNormalEvent("PLAYER_REGEN_DISABLED", self, "UpdateStatus")
		frame:RegisterNormalEvent("PLAYER_UPDATE_RESTING", self, "UpdateStatus")
		frame:RegisterNormalEvent("UPDATE_FACTION", self, "UpdateStatus")
		frame:RegisterUpdateFunc(self, "UpdateStatus")

		frame.indicators.status = frame.indicators.status or frame.indicators:CreateTexture(nil, "OVERLAY")
		frame.indicators.status:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
		frame.indicators.status:Hide()
	end
		
	if( config.indicators.pvp and config.indicators.pvp.enabled ) then
		frame:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", self, "UpdatePVPFlag")
		frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdatePVPFlag")
		frame:RegisterUpdateFunc(self, "UpdatePVPFlag")

		frame.indicators.pvp = frame.indicators.pvp or frame.indicators:CreateTexture(nil, "OVERLAY")
		frame.indicators.pvp:Hide()
	end
		
	if( config.indicators.leader and config.indicators.leader.enabled ) then
		frame:RegisterNormalEvent("PARTY_LEADER_CHANGED", self, "UpdateLeader")
		frame:RegisterNormalEvent("PARTY_MEMBERS_CHANGED", self, "UpdateLeader")
		frame:RegisterUpdateFunc(self, "UpdateLeader")

		frame.indicators.leader = frame.indicators:CreateTexture(nil, "OVERLAY")
		frame.indicators.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
		frame.indicators.leader:Hide()
	end
		
	if( config.indicators.masterLoot and config.indicators.masterLoot.enabled ) then
		frame:RegisterNormalEvent("PARTY_LOOT_METHOD_CHANGED", self, "UpdateMasterLoot")
		frame:RegisterUpdateFunc(self, "UpdateMasterLoot")

		frame.indicators.masterLoot = frame.indicators.masterLoot or frame.indicators:CreateTexture(nil, "OVERLAY")
		frame.indicators.masterLoot:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
		frame.indicators.masterLoot:Hide()
	end
		
	if( config.indicators.raidTarget and config.indicators.raidTarget.enabled ) then
		frame:RegisterNormalEvent("RAID_TARGET_UPDATE", self, "UpdateRaidTarget")
		frame:RegisterUpdateFunc(self, "UpdateRaidTarget")
		
		frame.indicators.raidTarget = frame.indicators.raidTarget or frame.indicators:CreateTexture(nil, "OVERLAY")
		frame.indicators.raidTarget:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		frame.indicators.raidTarget:Hide()
	end

	if( config.indicators.ready and config.indicators.ready.enabled ) then
		frame:RegisterNormalEvent("READY_CHECK", self, "UpdateReadyCheck")
		frame:RegisterNormalEvent("READY_CHECK_CONFIRM", self, "UpdateReadyCheck")
		frame:RegisterNormalEvent("READY_CHECK_FINISHED", self, "UpdateReadyCheck")
		frame:RegisterUpdateFunc(self, "UpdateReadyCheck")
		
		frame.indicators.ready = frame.indicators.raidTarget or frame.indicators:CreateTexture(nil, "OVERLAY")
		frame.indicators.ready:Hide()
	end
	
	if( config.indicators.happiness and config.indicators.happiness.enabled ) then
		frame:RegisterUnitEvent("UNIT_HAPPINESS", self, "UpdateHappiness")
		frame:RegisterUpdateFunc(self, "UpdateHappiness")
		
		frame.indicators.happiness = frame.indicators.happiness or frame.indicators:CreateTexture(nil, "OVERLAY")
		frame.indicators.happiness:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
		frame.indicators.happiness:Hide()
	end
end

function Indicators:OnDisable(frame)
	frame:UnregisterAll(self)

	if( frame.indicators ) then
		for _, key in pairs(frame.indicators.list) do
			local indicator = frame.indicators[key]
			if( indicator ) then
				indicator:Hide()
			end
		end
	end
end

function Indicators:OnLayoutApplied(frame)
	if( frame.indicators ) then
		for _, key in pairs(frame.indicators.list) do
			local indicator = frame.indicators[key]
			if( indicator and not indicator.enabled ) then
				indicator:Hide()
			end
		end
	end
end
