local Movers = {headers = {["party"] = true, ["raid"] = true}}
local L = ShadowUFLocals
local frameList, dummyPosition = {}, {}
ShadowUF:RegisterModule(Movers, "movers")

function Movers:Enable()
	-- Enable it for all units that are enabled
	for _, unit in pairs(ShadowUF.units) do
		if( ShadowUF.db.profile.units[unit].enabled ) then
			if( not self.headers[unit] ) then
				self:CreateFrame(unit, unit)
			else
				self:CreateHeader(unit)
			end
		elseif( frameList[unit] ) then
			if( frameList[unit].children ) then
				for _, child in pairs(frameList[unit].children) do
					child:Hide()
				end
			end
			
			frameList[unit]:Hide()
		end
	end
end

function OnDragStart(self)
	self = frameList[self.unitType] or self
	self.isMoving = true
	self.parentMoving = nil
	self:StartMoving()
	
	local parent = ShadowUF.Units.unitFrames[self.unitType] or ShadowUF.Units.unitFrames[self.unit]
	if( parent ) then
		self.parent = parent

		parent:SetAllPoints(self)
	end
end

function OnDragStop(self)
	self = frameList[self.unitType] or self
	self.isMoving = false
	self:StopMovingOrSizing()
	
	local scale = self:GetEffectiveScale()
	local position = ShadowUF.db.profile.positions[self.unitType]
	local point, _, relativePoint, x, y = self:GetPoint()
		
	position.anchorPoint = ""
	position.point = point
	position.anchorTo = "UIParent"
	position.relativePoint = relativePoint
	position.x = x * scale
	position.y = y * scale
	
	ShadowUF.Layout:AnchorFrame(UIParent, self, ShadowUF.db.profile.positions[self.unitType])

	-- Unlock the parent frame from the mover now
	if( self.parent ) then
		ShadowUF.Layout:AnchorFrame(UIParent, self.parent, ShadowUF.db.profile.positions[self.parent.unitType])
	end
end

function OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(self.overrideText or L.units[self.unitType] or self.unitType)
end

function OnLeave(self)
	GameTooltip:Hide()
end

-- Handles the header creation to mimick all the frames they have
function getRelativeAnchor(point)
	if( not point ) then return end
	if( point == "TOP") then
		return "BOTTOM", 0, -1
	elseif( point == "BOTTOM") then
		return "TOP", 0, 1
	elseif( point == "LEFT") then
		return "RIGHT", 1, 0
	elseif( point == "RIGHT") then
		return "LEFT", -1, 0
	elseif( point == "TOPLEFT") then
		return "BOTTOMRIGHT", 1, -1
	elseif( point == "TOPRIGHT") then
		return "BOTTOMLEFT", -1, -1
	elseif( point == "BOTTOMLEFT") then
		return "TOPRIGHT", 1, 1
	elseif( point == "BOTTOMRIGHT") then
		return "TOPLEFT", -1, 1
	else
		return "CENTER", 0, 0
	end
end

-- Need to make sure we keep the mover frames updated to what their owners would look like
local updateThrottle
function Movers:OnLayoutApplied(frame)
	local moverFrame = frameList[frame.unit] or frameList[frame.unitType]
	if( moverFrame and moverFrame:IsVisible() ) then
		ShadowUF.Layout:ApplyUnitFrame(moverFrame, ShadowUF.db.profile.units[moverFrame.unitType])
		
		moverFrame.text:SetWidth(moverFrame:GetWidth() - 10)
		moverFrame.text:SetHeight(moverFrame:GetHeight() - 10)
		
		-- Now reposition it
		-- Creating a dummy positioning table so we can keep the moving blocks anchored to each other as long as needed.
		if( moverFrame.unitType == moverFrame.unit ) then
			for k in pairs(dummyPosition) do dummyPosition[k] = nil end
			for k, v in pairs(ShadowUF.db.profile.positions[frame.unitType]) do dummyPosition[k] = v end
			dummyPosition.anchorTo = string.gsub(dummyPosition.anchorTo, "#SUFUnit", "#SUFMover")
			dummyPosition.anchorTo = string.gsub(dummyPosition.anchorTo, "#SUFHeader", "#SUFMover")
									
			ShadowUF.Layout:AnchorFrame(UIParent, moverFrame, dummyPosition)
		-- Bit hackish yes, but no sense in adding call backs for headers being updated
		elseif( not updateThrottle or updateThrottle < GetTime() ) then
			updateThrottle = GetTime() + 1
			
			Movers:CreateHeader(moverFrame.unitType)
		end
	end
end
		
function Movers:CreateHeader(type)
	local headerFrame = frameList[type] or CreateFrame("Frame", "SUFMover" .. type, UIParent)
	headerFrame:SetMovable(true)
	headerFrame.unitType = type
	headerFrame.unit = type
	
	frameList[type] = headerFrame
	
	-- Create frames for each child
	if( not headerFrame.children ) then
		updateThrottle = GetTime() + 1
		headerFrame.children = {}
		
		for id, unit in pairs(ShadowUF[type .. "Units"]) do
			self:CreateFrame(unit, type, string.format(L.headers[type], id))
			table.insert(headerFrame.children, frameList[unit])
		end
	end
				
	-- Position all of the children headers so they mimick the real ones
	local config = ShadowUF.db.profile.units[type]
	local unitsPerColumn = config.unitsPerColumn or #(headerFrame.children)
	local maxUnits = 0
	if( config.filters ) then
		for _, enabled in pairs(config.filters) do
			if( enabled ) then
				maxUnits = maxUnits + 5
			end
		end
		
		if( unitsPerColumn > maxUnits ) then
			unitsPerColumn = maxUnits
		end
	else
		maxUnits = #(headerFrame.children)
	end
	
	local point = config.attribPoint or "TOP"
    local relativePoint, xOffsetMulti, yOffsetMulti = getRelativeAnchor(point)
    local xMultiplier, yMultiplier = math.abs(xOffsetMulti), math.abs(yOffsetMulti)
	local columnRelativePoint, colxMulti, colyMulti = getRelativeAnchor(config.attribAnchorPoint)
    local maxColumns = config.maxColumns or 1
	local totalDisplayed = math.min(maxUnits, (maxColumns * unitsPerColumn))
	local numColumns = math.ceil(totalDisplayed / unitsPerColumn)
    local x = config.xOffset or 0
    local y = config.yOffset or 0
		
	-- Position all of the children
	local columnTotal = 0
	for id, child in pairs(headerFrame.children) do
		columnTotal = columnTotal + 1
		if( numColumns > 0 and columnTotal > unitsPerColumn ) then
			columnTotal = 1
		end
				
		if( id == 1 ) then
			child:ClearAllPoints()
			child:SetPoint(point, headerFrame, point, 0, 0)
			
			if( config.attribAnchorPoint and numColumns > 1 ) then
				child:SetPoint(config.attribAnchorPoint, headerFrame, config.attribAnchorPoint, 0, 0)
			end
		elseif( columnTotal == 1 ) then
			child:ClearAllPoints()
			child:SetPoint(config.attribAnchorPoint, headerFrame.children[id - unitsPerColumn], columnRelativePoint, colxMulti * config.columnSpacing, colyMulti * config.columnSpacing)
		else
			child:ClearAllPoints()
			child:SetPoint(point, headerFrame.children[id - 1], relativePoint, xMultiplier * x, yMultiplier * y)
		end
	end

	-- Figure out the size of the total header
	local width = xMultiplier * ( unitsPerColumn - 1 ) * config.width + ( ( unitsPerColumn - 1 ) * ( x * xOffsetMulti ) ) + config.width
	local height = yMultiplier * ( unitsPerColumn - 1 ) * config.height + ( ( unitsPerColumn - 1 ) * ( y * yOffsetMulti ) ) + config.height

	if( numColumns > 1 ) then
		width = width + ( ( numColumns - 1 ) * math.abs(colxMulti) * ( width + config.columnSpacing ) )
		height = height + ( ( numColumns - 1 ) * math.abs(colyMulti) * ( height + config.columnSpacing ) )
	end
	
	headerFrame:SetHeight(height)
	headerFrame:SetWidth(width)
		
	-- Now set which of the frames is shown vs hidden
	for id, frame in pairs(headerFrame.children) do
		if( id <= totalDisplayed ) then
			frame:Show()
		else
			frame:Hide()
		end
	end
	
	-- Position the header
	for k in pairs(dummyPosition) do dummyPosition[k] = nil end
	for k, v in pairs(ShadowUF.db.profile.positions[type]) do dummyPosition[k] = v end
	dummyPosition.anchorTo = string.gsub(dummyPosition.anchorTo, "#SUFUnit", "#SUFMover")
	dummyPosition.anchorTo = string.gsub(dummyPosition.anchorTo, "#SUFHeader", "#SUFMover")

	ShadowUF.Layout:AnchorFrame(UIParent, headerFrame, dummyPosition)
end

function Movers:CreateFrame(unit, unitType, overrideText)
	if( frameList[unit] ) then
		frameList[unit]:Show()
		return
	end
	
	local moverFrame = CreateFrame("Frame", "SUFMover" .. unit, UIParent)
	moverFrame:SetScript("OnDragStart", OnDragStart)
	moverFrame:SetScript("OnDragStop", OnDragStop)
	moverFrame:SetScript("OnEnter", OnEnter)
	moverFrame:SetScript("OnLeave", OnLeave)
	moverFrame:SetFrameStrata("HIGH")
	moverFrame:SetClampedToScreen(true)
	moverFrame:SetMovable(true)
	moverFrame:EnableMouse(true)
	moverFrame:RegisterForDrag("LeftButton")
	moverFrame.text = moverFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	moverFrame.text:SetText(overrideText or L.units[unitType] or unitType)
	moverFrame.text:SetPoint("CENTER", moverFrame, "CENTER")
	moverFrame.unitType = unitType
	moverFrame.unit = unit
	moverFrame.ignoreAnchor = true
	moverFrame.overrideText = overrideText
	
	
	frameList[unit] = moverFrame
	
	self:OnLayoutApplied(moverFrame)
end

function Movers:Update()
	if( not ShadowUF.db.profile.locked ) then
		self:Enable()
	elseif( ShadowUF.db.profile.locked ) then
		self:Disable()
	end
end

function Movers:Disable()
	for _, frame in pairs(frameList) do
		if( frame.isMoving ) then
			OnDragStop(frame)
		end
		
		frame:Hide()
	end
end
