-----------------------------------------------------------------------------------------------
-- Client Lua Script for EngineerResourceManager
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- EngineerResourceManager Module Definition
-----------------------------------------------------------------------------------------------
local EngineerResourceManager = {} 
local GainDrain = Apollo.GetPackage("ERM:GainDrain").tPackage
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local bEditorMode = false
unitPlayer = {}

local tDefaults = {
	--Gains (Dash is hardcoded)
	["Bio Shell"] = {strName="Bio Shell",nVal=30,strSprite="Icon_SkillEngineer_BioShell"},
	["Energy Auger"] = {strName="Energy Auger",nVal=30,strSprite="Icon_SkillEngineer_Energy_Trail"},
	["Pulse Blast"] = {strName="Pulse Blast",nVal=15,strSprite="Icon_SkillEngineer_Pulse_Blast"},
	--Drains
	["Mortar Strike"] = {strName="Mortar Strike",nVal=-25,strSprite="Icon_SkillEngineer_Mortar_Strike"},
	["Bolt Caster"] = {strName="Bolt Caster",nVal=-25,strSprite="Icon_SkillEngineer_Bolt_Caster"},
	["Electrocute"] = {strName="Electrocute",nVal=-24,strSprite="Icon_SkillEngineer_Electrocute"},
}

local tDash = {
	
}

local tActiveGD = {}
local bVI = false

--[[local tAbilitySprites = {
    ["Energy Auger"] = "Icon_SkillEngineer_Energy_Trail",
    ["Urgent Withdrawal"] = "ClientSprites:Icon_SkillEngineer_Urgent_Withdrawal",
    ["Particle Ejector"] = "Icon_SkillEngineer_Particule_Ejector",
    ["Unstable Anomaly"] = "Icon_SkillEngineer_Anomaly_Launcher",
    ["Bolt Caster"] = "Icon_SkillEngineer_Bolt_Caster",
    ["Target Acquisition"] = "ClientSprites:Icon_SkillEngineer_Target_Acquistion",
    ["Hyper Wave"] = "Icon_SkillEngineer_Hyper_Wave",
    ["Electrocute"] = "Icon_SkillEngineer_Electrocute",
    ["Bio Shell"] = "Icon_SkillEngineer_BioShell",
    ["Flak Cannon"] = "Icon_SkillEngineer_Flak_Cannon",
    ["Ricochet"] = "ClientSprites:Icon_SkillEngineer_Ricochet",
    ["Zap"] = "ClientSprites:Icon_SkillEngineer_Zap",
    ["Quick Burst"] = "ClientSprites:Icon_SkillEngineer_Quick_Burst",
    ["Unsteady Miasma"] = "Icon_SkillEngineer_Give_Em_Gas",
    ["Mortar Strike"] = "Icon_SkillEngineer_Mortar_Strike",
    ["Code Red"] = "Icon_SkillEngineer_Code_Red",
    ["Volatile Injection"] = "ClientSprites:Icon_SkillEngineer_Volatile_Injection",
    ["Disruptive Module"] = "Icon_SkillEngineer_Disruptive_Mod",
    ["Feedback"] = "Icon_SkillEngineer_Feedback",
    ["Pulse Blast"] = "ClientSprites:Icon_SkillEngineer_Pulse_Blast",
    ["Recursive Matrix"] = "ClientSprites:Icon_SkillEngineer_Recursive_Matrix",
    ["Shock Pulse"] = "ClientSprites:Icon_SkillEngineer_Shock_Pulse",
    ["Shatter Impairment"] = "ClientSprites:Icon_SkillEngineer_Shatter_Impairment",
    ["Repairbot"] = "ClientSprites:Icon_SkillEngineer_Repair_Bot",
    ["Artillerybot"] = "Icon_SkillEngineer_Artillery_Bot",
    ["Diminisherbot"] = "Icon_SkillEngineer_Diminisher_Bot",
    ["Bruiserbot"] = "Icon_SkillEngineer_Bruiser_Bot",
    ["Personal Defense Unit"] = "ClientSprites:Icon_SkillEngineer_Personal_Defense_Unit",
}--]]

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function EngineerResourceManager:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function EngineerResourceManager:Init()
	local bHasConfigureFunction = true
	local strConfigureButtonText = "EngineerResource"
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- EngineerResourceManager OnLoad
-----------------------------------------------------------------------------------------------
function EngineerResourceManager:OnLoad()
	Apollo.LoadSprites("ERMSprites.xml", "ERMSprites")
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("EngineerResourceManager.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- EngineerResourceManager OnDocLoaded
-----------------------------------------------------------------------------------------------
function EngineerResourceManager:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "Bar", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		self.wndMain:SetSizingMinimum(175,10)
		
		-- Variables --------------------------------------------------------------------------
		self.tTheZone = {0.3,0.7}
		self.nVolMax = self.nVolMax or 100
		self.fDash = self.fDash or 1.75
		self.nRefreshRate = self.nRefreshRate or 0.1
		
		--Ability Gain/Drains
		self.tGainDrains = self.tGainDrains or tDefaults
	
		--Dash Gain
		self:AddDashGain()
				
		-- Events -----------------------------------------------------------------------------
		Apollo.RegisterSlashCommand("erm", "OnConfigure", self)
		if GameLib.GetPlayerUnit() then
			self:OnCharacterCreated()
		else
			Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
		end
		Apollo.RegisterEventHandler("OnZoneChange", "PlayerChanged", self)
		
		Apollo.RegisterEventHandler("AbilityBookChange", "OnAbilityBookChange", self)
		Apollo.RegisterTimerHandler("AbilityChangeTimer", "AbilityChanged", self)
		Apollo.CreateTimer("AbilityChangeTimer", 1.5, false)
		
		self.timer = ApolloTimer.Create(self.nRefreshRate, true, "OnTimer", self)
	end
end

function EngineerResourceManager:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	
	local tSave = {}
	
	tSave.nRefreshRate = self.nRefreshRate
	
	return tSave
end

function EngineerResourceManager:OnRestore(eLevel, tSavedData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	
	for key,val in pairs(tSavedData) do
		self[key] = val
	end
end

function EngineerResourceManager:OnConfigure()
	if not self.wndSettings and not bEditorMode then
		self:OnToggleEditing()
	end
end

function EngineerResourceManager:OnTimer()
	if unitPlayer and unitPlayer:IsValid() then
		local nVolatility = unitPlayer:GetResource(1)
		local fDash = unitPlayer:GetResource(7)
		self:SetVolatility(nVolatility)
		self:SetGainDrains(nVolatility)
		self:SetDashGain(nVolatility, fDash)
		
		--Glow effects (Innate or VI - Note: VI causes serious performance loss due to buff checking.)
		--Possibly use event "CombatLogVitalModifier" and check splCallingSpell for 10vol/sec; however, not resilient to innate changes.
		if bVI then
			local tBuffs = unitPlayer:GetBuffs().arBeneficial
			local bFound = false
			for _,tBuff in pairs(tBuffs) do
				if tBuff.splEffect:GetName() == "Volatile Injection" then
					bFound = true
					break
				end
			end
			self.wndMain:FindChild("Glow"):Show(bFound or GameLib.IsCurrentInnateAbilityActive())
		else
			self.wndMain:FindChild("Glow"):Show(GameLib.IsCurrentInnateAbilityActive()) 
		end
	else
		--self:OnCharacterCreated()
	end
end

function EngineerResourceManager:OnCharacterCreated()
	unitPlayer = GameLib.GetPlayerUnit()
	self:OnAbilityBookChange()
end

function EngineerResourceManager:OnZoneChange()
	self:OnCharacterCreated()
end

function EngineerResourceManager:OnAbilityBookChange()
	Apollo.StartTimer("AbilityChangeTimer")
end

function EngineerResourceManager:AbilityChanged()
	local tLAS = ActionSetLib.GetCurrentActionSet()
	local tAbilities = AbilityBook.GetAbilitiesList()
	
	self:ClearActiveGD()
	bVI = false
	
	for _,ability in pairs(tAbilities) do
		if ability.bIsActive then
			for _,nLASId in pairs(tLAS) do
	        	if ability.nId == nLASId then
					if self.tGainDrains[ability.strName] then
						local tSettings = TableUtil:Copy(self.tGainDrains[ability.strName])
						local tCurrTier = ability.tTiers[ability.nCurrentTier]
						if tCurrTier.splObject:GetCooldownTime() > 0 then
							tSettings.splObject = tCurrTier.splObject
						end
						tActiveGD[ability.strName] = GainDrain:new(tSettings)
						--ability.nCurrentTier <-- use in future if needed
					end
					if ability.strName == "Volatile Injection" then
						bVI = true
					end
				end
			end
		end
	end
	
	if self.wndSettings then
		self:PopulateSettings()
	end
end

-----------------------------------------------------------------------------------------------
-- EngineerResourceManager Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here
function EngineerResourceManager:SetVolatility(nVol)
	local fVol = nVol/self.nVolMax
	self.wndMain:FindChild("VolValue"):SetAnchorPoints(fVol,-4,fVol,5)
end

function EngineerResourceManager:SetGainDrains(nVol)
	local fVol = nVol/self.nVolMax
	for strGainDrain,luaGainDrain in pairs(tActiveGD) do
		luaGainDrain:OnUpdate(fVol, self)
	end
end

function EngineerResourceManager:SetDashGain(nVol, nDash)
	if self.wndDash then
		local fVol = nVol/self.nVolMax
		local fDash = nDash/100
		local fGD = fVol + 0.15
		self.wndDash:SetAnchorPoints(fGD,-2,fGD,3)
		if (fGD > 1 or fGD < 0) or fDash < self.fDash then
			self.wndDash:Show(false)
		else
			if not self.wndDash:IsShown() then
				self.wndDash:Show(true)
			end
			if fGD >= self.tTheZone[1] and fGD <= self.tTheZone[2] then
				self.wndDash:SetBGColor("ffff00ff")
			else
				self.wndDash:SetBGColor("ff00ffff")
			end
		end
	end
end

function EngineerResourceManager:AddDashGain()
	if not self.wndDash then
		local wndDash = Apollo.LoadForm(self.xmlDoc, "GainDrain", self.wndMain, self)
		Apollo.LoadForm(self.xmlDoc, "Icon", wndDash, self)
		--wndDash:DoWhatever
		self.wndDash = wndDash
	end
end


function EngineerResourceManager:ClearActiveGD()
	for strGainDrain,luaGainDrain in pairs(tActiveGD) do
		luaGainDrain:Destroy()
	end
	tActiveGD = {}
end











function EngineerResourceManager:ColorProfileTest(nProfile)
	local tProfiles = {
		{ --Dark1
			bg={
				color = "232323",
				trans = 100,
				glow = "AttributeName"
			},
			zone={
				color = "CF5300",
				trans = 100,
				glow = "black"
			},
			incolor={
				base="FF00FF00",
				dash="FF00FFFF"
			},
			outcolor={
				base="FFFF0000",
				dash="FFFF00FF"
			}
		},
		{ --Dark2
			bg={
				color = "232323",
				trans = 100,
				glow = "cyan"
			},
			zone={
				color = "ADD8E6",
				trans = 100,
				glow = "black"
			},
			incolor={
				base="FF00FF00",
				dash="FF00FFFF"
			},
			outcolor={
				base="FFFF0000",
				dash="FFFF00FF"
			}
		}
	}
	self:SetColorProfile(tProfiles[nProfile])
end

function EngineerResourceManager:SetColorProfile(tProfile)
	self.wndMain:SetBGColor(string.format("%02X%s",tProfile.bg.trans/100*255,tProfile.bg.color))
	self.wndMain:FindChild("Glow:BG"):SetBGColor(tProfile.bg.glow)
	self.wndMain:FindChild("InTheZone"):SetBGColor(string.format("%02X%s",tProfile.zone.trans/100*255,tProfile.zone.color))
	self.wndMain:FindChild("Glow:Zone"):SetBGColor(tProfile.zone.glow)
	
	for _,luaGainDrain in pairs(tActiveGD) do
		
	end
end








function EngineerResourceManager:OnToggleEditing()
	bEditorMode = not bEditorMode
	if bEditorMode then
		self.wndSettings = Apollo.LoadForm(self.xmlDoc, "Settings", nil, self)
		self:PopulateSettings()
	else
		self.wndSettings :Destroy()
		self.wndSettings = nil
	end
	self.wndMain:SetStyle("Moveable", bEditorMode)
	self.wndMain:SetStyle("Sizable", bEditorMode)
	self.wndMain:SetStyle("IgnoreMouse", not bEditorMode)
end

function EngineerResourceManager:PopulateSettings()
	local wndSettings = self.wndSettings
	wndSettings:FindChild("MaxVol"):FindChild("EditBox"):SetText(self.nVolMax)
	wndSettings:FindChild("InTheZone"):FindChild("EditBoxLow"):SetText(self.tTheZone[1]*100)
	wndSettings:FindChild("InTheZone"):FindChild("EditBoxHigh"):SetText(self.tTheZone[2]*100)
	wndSettings:FindChild("DashReserve"):FindChild("SliderBar"):SetValue(self.fDash)
	wndSettings:FindChild("DashReserve"):FindChild("EditBox"):SetText(self.fDash)
	
	local wndGainDrains = wndSettings:FindChild("GainDrains")
	wndGainDrains:DestroyChildren()
	local wndDash = Apollo.LoadForm(self.xmlDoc, "GainDrainSettings", wndGainDrains, self)
	wndDash:FindChild("Name"):SetText("Dash")
	wndDash:FindChild("Sprite"):SetSprite("IconSprites:Icon_SkillMisc_Explorer_safefail")
	wndDash:FindChild("Volatility:EditBox"):SetText("15")
	wndDash:FindChild("Active"):SetBGColor("green")
	wndDash:FindChild("Enabled"):SetCheck(true)

	for strGainDrain,tGainDrain in pairs(self.tGainDrains) do
		local wndGDSettings = Apollo.LoadForm(self.xmlDoc, "GainDrainSettings", wndGainDrains, tActiveGD[strGainDrain] or self)
		wndGDSettings:FindChild("Name"):SetText(strGainDrain)
		wndGDSettings:FindChild("Sprite"):SetSprite(tGainDrain.strSprite)
		wndGDSettings:FindChild("Volatility:EditBox"):SetText(tGainDrain.nVal)
		wndGDSettings:FindChild("Active"):SetBGColor(tActiveGD[strGainDrain] and "green" or "red")
		wndGDSettings:FindChild("Enabled"):SetCheck(true)
	end
	wndGainDrains:ArrangeChildrenVert()
end

function EngineerResourceManager:Test()
	Print("TestERM")
end

function EngineerResourceManager:OnCancel()
	self:OnToggleEditing()
end

-----------------------------------------------------------------------------------------------
-- EngineerResourceManager Instance
-----------------------------------------------------------------------------------------------
local EngineerResourceManagerInst = EngineerResourceManager:new()
EngineerResourceManagerInst:Init()
ermv2 = EngineerResourceManagerInst
