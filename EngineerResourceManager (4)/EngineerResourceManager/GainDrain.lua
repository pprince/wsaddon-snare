local GainDrain = {}

function GainDrain:new(t)
	if t.nVal then
		setmetatable(t, self)
		self.__index = self
		
		t:Init()
		
		return t
	else
		Print("[ERM] nVal not defined for GainDrain creation.")
		return nil
	end
end

function GainDrain:Init()
	local ERM = Apollo.GetAddon("EngineerResourceManager")

	self.strInColor = self.strInColor or "00FF00" --green
	self.strOutColor = self.strOutColor or "FF0000" --red
	self.nWidth = self.nWidth or 1
	self.strSprite = self.strSprite or "WhiteFill"
	
	local wndGD = Apollo.LoadForm(ERM.xmlDoc, "GainDrain", ERM.wndMain:FindChild("GainDrains"), self)
	wndGD:SetAnchorOffsets(-self.nWidth, 0, self.nWidth, 0)
	
	local wndIcon = Apollo.LoadForm(ERM.xmlDoc, "Icon", wndGD, self)
	wndIcon:SetSprite(self.strSprite)
	
	self.wndGD = wndGD
end

function GainDrain:Destroy()
	for key,val in pairs(self) do
		if Window.is(val) and val.Destroy then
			val:Destroy()
		end
		self[key] = nil
	end
	self = nil
end

function GainDrain:OnUpdate(fVol, ERM)
	wndGainDrain = self.wndGD
	
	local fGD = fVol + self.nVal/ERM.nVolMax
	wndGainDrain:SetAnchorPoints(fGD,-2,fGD,3)
	if fGD > 1 or fGD < 0 then				--If it's not on the bar.
		wndGainDrain:Show(false)
	else									--If it's on the bar (0-100).
		if self.splObject then
			--local fCD = self.splObject:GetCooldownRemaining()
			wndGainDrain:Show(self.splObject:GetCooldownRemaining() == 0)
			--[[if fCD < 1 then
				wndGainDrain:FindChild("Icon"):SetText(string.format("%.1f",fCD))
			end]]--
		else
			wndGainDrain:Show(true)
		end
		if fGD >= ERM.tTheZone[1] and fGD <= ERM.tTheZone[2] then
			wndGainDrain:SetBGColor("FF"..self.strInColor)
		else
			wndGainDrain:SetBGColor("FF"..self.strOutColor)
		end
	end
end

function GainDrain:Test()
	Print("TestGD")
end


Apollo.RegisterPackage(GainDrain, "ERM:GainDrain", 1, {})