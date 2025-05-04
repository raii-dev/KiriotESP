-- (Thanks Kiriot22/Amia)


--Settings--
local ESP = {
	Enabled = false,
	Boxes = true,
	HeadCircle = true,
	BoxShift = CFrame.new(0,-0.5,0),
	BoxSize = Vector3.new(4.5,6.5,0),
	Color = Color3.fromRGB(255, 60, 60),
	FaceCamera = true,
	Names = true,
	TeamColor = true,
	Thickness = 2,
	AttachShift = 1,
	TeamMates = true,
	Players = true,
	Highlights = true, 
	Skeletons = true,
    ExtraInfo = true,
	HealthBar = true,
	MaxHealth = 100,

	Objects = setmetatable({}, {__mode="kv"}),
	Overrides = {},

	CurrentHealth = 100
}

--Declarations--
local cam = workspace.CurrentCamera
local plrs = cloneref(game:GetService("Players"))
local plr = plrs.LocalPlayer
local mouse = plr:GetMouse()

local V3new = Vector3.new
local WorldToViewportPoint = cam.WorldToViewportPoint

--Functions--
local function Draw(obj, props)
	local new = Drawing.new(obj)

	props = props or {}
	for i,v in pairs(props) do
		new[i] = v
	end
	return new
end

function ESP:UpdateHealth(health)
	self.CurrentHealth = health
end

function ESP:GetTeam(p)
	local ov = self.Overrides.GetTeam
	if ov then
		return ov(p)
	end

	return p and p.Team
end

function ESP:IsTeamMate(p)
	local ov = self.Overrides.IsTeamMate
	if ov then
		return ov(p)
	end

	return self:GetTeam(p) == self:GetTeam(plr)
end

function ESP:GetColor(obj)
	local ov = self.Overrides.GetColor
	if ov then
		return ov(obj)
	end
	local p = self:GetPlrFromChar(obj)
	return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end

function ESP:GetPlrFromChar(char)
	local ov = self.Overrides.GetPlrFromChar
	if ov then
		return ov(char)
	end

	return plrs:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
	self.Enabled = bool
	if not bool then
		for i,v in pairs(self.Objects) do
			if v.Type == "Box" then --fov circle etc
				if v.Temporary then
					v:Remove()
				else
					for i,v in pairs(v.Components) do
						v.Visible = false
					end
				end
			end
		end
	end
end

function ESP:GetBox(obj)
	return self.Objects[obj]
end

function ESP:AddObjectListener(parent, options)
	local function NewListener(c)
		if type(options.Type) == "string" and c:IsA(options.Type) or options.Type == nil then
			if type(options.Name) == "string" and c.Name == options.Name or options.Name == nil then
				if not options.Validator or options.Validator(c) then
					local primaryPart = c:WaitForChild("HumanoidRootPart", 5) 
						or c:WaitForChild("Head", 5) 
						or c:FindFirstChildWhichIsA("BasePart") 
						or c:IsA("Model") and c

					if primaryPart then
						local box = ESP:Add(c, {
							PrimaryPart = primaryPart,
							Color = type(options.Color) == "function" and options.Color(c) or options.Color,
							ColorDynamic = options.ColorDynamic,
							Name = type(options.CustomName) == "function" and options.CustomName(c) or options.CustomName,
							IsEnabled = options.IsEnabled,
							RenderInNil = options.RenderInNil
						})

						if options.OnAdded then
							coroutine.wrap(options.OnAdded)(box)
						end
					else
						print("No valid primary part found for:", c.Name)
					end
				end
			end
		end
	end

	if options.Recursive then
		parent.DescendantAdded:Connect(function(c)
			coroutine.wrap(function()  
				NewListener(c)
			end)()
		end)

		for i, v in pairs(parent:GetDescendants()) do
			coroutine.wrap(function()
				NewListener(v)
			end)()
		end
	else
		parent.ChildAdded:Connect(function(c)
			coroutine.wrap(function() 
				NewListener(c)
			end)()
		end)

		for i, v in pairs(parent:GetChildren()) do
			coroutine.wrap(function()
				NewListener(v)
			end)()
		end
	end
end



local boxBase = {}
boxBase.__index = boxBase

function boxBase:Remove()
	ESP.Objects[self.Object] = nil
	for i, v in pairs(self.Components) do
		if typeof(v) == "Instance" and v:IsA("Highlight") then
			v:Destroy()
		elseif typeof(v) == "table" and (i == "Skeleton" or i == "SkeletonOutline") then
			for _, line in ipairs(v) do
				if line and line.Remove then
					line.Visible = false
					line:Remove()
				end
			end
		elseif v and v.Remove then
			v.Visible = false
			v:Remove()
		end
		self.Components[i] = nil
	end
end

function boxBase:Update()
	if not self.PrimaryPart then
		--warn("not supposed to print", self.Object)
		return self:Remove()
	end

	local color
	if ESP.Highlighted == self.Object then
		color = ESP.HighlightColor
	else
		color = self.Color or self.ColorDynamic and self:ColorDynamic() or ESP:GetColor(self.Object) or ESP.Color
	end

	local allow = true
	if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
		allow = false
	end
	if self.Player and not ESP.TeamMates and ESP:IsTeamMate(self.Player) then
		allow = false
	end
	if self.Player and not ESP.Players then
		allow = false
	end
	if self.IsEnabled and (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or type(self.IsEnabled) == "function" and not self:IsEnabled()) then
		allow = false
	end
	if not workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
		allow = false
	end

	if not allow then
		for i,v in pairs(self.Components) do
			if v.Name ~= "raii_highlight" then
				v.Visible = false
			end
		end
		return
	end

	if ESP.Highlighted == self.Object then
		color = ESP.HighlightColor
	end

	--calculations--
	local cf = self.PrimaryPart.CFrame
	if ESP.FaceCamera then
		cf = CFrame.new(cf.p, cam.CFrame.p)
	end
	local size = self.Size
	
	local head = self.Object:FindFirstChild("Head")


	local tagPosWorld = head and (head.Position + Vector3.new(0, 3.5, 0)) or (cf.Position + Vector3.new(0, size.Y/2 + 0.5, 0))

	local locs = {
		TopLeft = cf * ESP.BoxShift * CFrame.new(size.X/2, size.Y/2, 0),
		TopRight = cf * ESP.BoxShift * CFrame.new(-size.X/2, size.Y/2, 0),
		BottomLeft = cf * ESP.BoxShift * CFrame.new(size.X/2, -size.Y/2, 0),
		BottomRight = cf * ESP.BoxShift * CFrame.new(-size.X/2, -size.Y/2, 0),
		TagPos = ESP.BoxShift * CFrame.new(tagPosWorld),
		Torso = cf * ESP.BoxShift
	}

	local distance = (cam.CFrame.p - cf.p).magnitude 

	if ESP.MaxDistance and distance > ESP.MaxDistance then
		for i,v in pairs(self.Components) do
			-- v.Visible = false -- (nothing yet because i need to fix for each individual component)
		end
		return
	end

	if ESP.Boxes then
		local humanoid = self.Object:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local TopLeft, Vis1 = WorldToViewportPoint(cam, locs.TopLeft.p)
			local TopRight, Vis2 = WorldToViewportPoint(cam, locs.TopRight.p)
			local BottomLeft, Vis3 = WorldToViewportPoint(cam, locs.BottomLeft.p)
			local BottomRight, Vis4 = WorldToViewportPoint(cam, locs.BottomRight.p)

			if self.Components.Quad then
				if Vis1 or Vis2 or Vis3 or Vis4 then
					self.Components.QuadOutline.Visible = true
					self.Components.QuadOutline.PointA = Vector2.new(TopRight.X, TopRight.Y)
					self.Components.QuadOutline.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
					self.Components.QuadOutline.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
					self.Components.QuadOutline.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
					self.Components.QuadOutline.Color = Color3.fromRGB(0, 0, 0)  
					self.Components.QuadOutline.Thickness = 4 
					
					self.Components.Quad.Visible = true
					self.Components.Quad.PointA = Vector2.new(TopRight.X, TopRight.Y)
					self.Components.Quad.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
					self.Components.Quad.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
					self.Components.Quad.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
					self.Components.Quad.Color = color  
				else
					self.Components.QuadOutline.Visible = false
					self.Components.Quad.Visible = false
				end
			end
		end
	end

	if ESP.Skeletons and self.Components.Skeleton then
		local model = self.Object
		local bones = {
			{"Head", "UpperTorso"},
			{"UpperTorso", "LowerTorso"},
			{"UpperTorso", "LeftUpperArm"},
			{"LeftUpperArm", "LeftLowerArm"},
			{"LeftLowerArm", "LeftHand"},
			{"UpperTorso", "RightUpperArm"},
			{"RightUpperArm", "RightLowerArm"},
			{"RightLowerArm", "RightHand"},
			{"LowerTorso", "LeftUpperLeg"},
			{"LeftUpperLeg", "LeftLowerLeg"},
			{"LeftLowerLeg", "LeftFoot"},
			{"LowerTorso", "RightUpperLeg"},
			{"RightUpperLeg", "RightLowerLeg"},
			{"RightLowerLeg", "RightFoot"},
		}

		for i, pair in ipairs(bones) do
			local a = model:FindFirstChild(pair[1])
			local b = model:FindFirstChild(pair[2])
			local line = self.Components.Skeleton[i]
			local outlineLine = self.Components.SkeletonOutline[i]
			
			if a and b and line then
				local aPos, aOnScreen = WorldToViewportPoint(cam, a.Position)
				local bPos, bOnScreen = WorldToViewportPoint(cam, b.Position)
				
				line.Visible = aOnScreen or bOnScreen
				outlineLine.Visible = aOnScreen or bOnScreen 
				
				if line.Visible then
					line.From = Vector2.new(aPos.X, aPos.Y)
					line.To = Vector2.new(bPos.X, bPos.Y)
					line.Color = color
					line.Thickness = ESP.Thickness

					outlineLine.From = Vector2.new(aPos.X, aPos.Y)
					outlineLine.To = Vector2.new(bPos.X, bPos.Y)
					outlineLine.Color = Color3.fromRGB(0, 0, 0)  
					outlineLine.Thickness = ESP.Thickness + 2.5
				end
			elseif line then
				line.Visible = false
				outlineLine.Visible = false
			end
		end
	end

	if ESP.HeadCircle and self.Components.HeadCircle then
		local head = self.Object:FindFirstChild("Head")
		if head then
			local headPos3D = head.Position
			local topOfHead3D = headPos3D + Vector3.new(0, head.Size.Y / 2, 0)

			local headPos2D, onScreen1 = WorldToViewportPoint(cam, headPos3D)
			local topPos2D, onScreen2 = WorldToViewportPoint(cam, topOfHead3D)

			if onScreen1 or onScreen2 then
				local radius = (headPos2D - topPos2D).Magnitude

				local outline = self.Components.HeadCircleOutline
				local circle = self.Components.HeadCircle

				outline.Position = Vector2.new(headPos2D.X, headPos2D.Y)
				outline.Radius = radius
				outline.Thickness = 6
				outline.Color = Color3.fromRGB(0, 0, 0)
				outline.Visible = true

				circle.Position = outline.Position
				circle.Radius = radius + 2
				circle.Thickness = 2
				circle.Color = color
				circle.Visible = true
			else
				self.Components.HeadCircle.Visible = false
				self.Components.HeadCircleOutline.Visible = false
			end
		else
			self.Components.HeadCircle.Visible = false
			self.Components.HeadCircleOutline.Visible = false
		end
	end

	if self.Components.Highlight then
		local highlight = self.Components.Highlight

		local shouldShow = ESP.Highlights and (self.ShowHighlight ~= false)

		highlight.FillColor = color
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.Enabled = shouldShow
	end

    if ESP.Names then
		local TagPos, Vis5 = WorldToViewportPoint(cam, locs.TagPos.p)

		if Vis5 then
			local distance = (cam.CFrame.p - cf.p).Magnitude

			self.Components.Name.Visible = true
			self.Components.Name.Position = Vector2.new(TagPos.X, TagPos.Y)
			self.Components.Name.Text = self.Name
			self.Components.Name.Color = Color3.fromRGB(255, 255, 255)

			local offsetY = 18

			if self.Components.ExtraInfo then
				if self.ExtraInfo and self.ExtraInfo ~= "" then
					self.Components.ExtraInfo.Visible = true
					self.Components.ExtraInfo.Position = Vector2.new(TagPos.X, TagPos.Y + offsetY)
					self.Components.ExtraInfo.Text = self.ExtraInfo
					self.Components.ExtraInfo.Color = Color3.fromRGB(255, 255, 255)
					offsetY = offsetY + 18 -- push distance further down
				else
					self.Components.ExtraInfo.Visible = false
				end
			end

			self.Components.Distance.Visible = true
			self.Components.Distance.Position = Vector2.new(TagPos.X, TagPos.Y + offsetY)
			self.Components.Distance.Text = "[" .. math.floor(distance) .. "m]"
			self.Components.Distance.Color = Color3.fromRGB(255, 255, 255)
		else
			self.Components.Name.Visible = false
			self.Components.Distance.Visible = false
			if self.Components.ExtraInfo then
				self.Components.ExtraInfo.Visible = false
			end
		end
	else
		self.Components.Name.Visible = false
		self.Components.Distance.Visible = false
		if self.Components.ExtraInfo then
			self.Components.ExtraInfo.Visible = false
		end
	end

	if ESP.HealthBar and self.Components.HealthBar and self.Components.HealthBarBG then
		local humanoid = self.Object:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local health = ESP.CurrentHealth
			local TopLeft, Vis1 = WorldToViewportPoint(cam, locs.TopLeft.p)
			local BottomLeft, Vis3 = WorldToViewportPoint(cam, locs.BottomLeft.p)

			if Vis1 or Vis3 then	
				local healthPercent = math.clamp(health / ESP.MaxHealth, 0, 1)

				local offset = ESP.HealthBarOffset or -10

				local top = Vector2.new(TopLeft.X, TopLeft.Y)
				local bottom = Vector2.new(BottomLeft.X, BottomLeft.Y)

				local barDir = (bottom - top).Unit
				local perp = Vector2.new(-barDir.Y, barDir.X)

				local barTop = top + perp * -offset
				local barBottom = bottom + perp * -offset

				local filled = barBottom:Lerp(barTop, healthPercent)

				self.Components.HealthBarBG.Visible = true
				self.Components.HealthBarBG.From = barTop
				self.Components.HealthBarBG.To = barBottom
				self.Components.HealthBarBG.Color = Color3.new(0, 0, 0)
				self.Components.HealthBarBG.Thickness = 6

				self.Components.HealthBar.Visible = true
				self.Components.HealthBar.From = barBottom
				self.Components.HealthBar.To = filled
				self.Components.HealthBar.Color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), healthPercent)
				self.Components.HealthBar.Thickness = 3 

			else
				self.Components.HealthBar.Visible = false
				self.Components.HealthBarBG.Visible = false
			end
		else
			self.Components.HealthBar.Visible = false
			self.Components.HealthBarBG.Visible = false
		end
	else
		if self.Components.HealthBar then
			self.Components.HealthBar.Visible = false
		end
		if self.Components.HealthBarBG then
			self.Components.HealthBarBG.Visible = false
		end
	end
end	

function ESP:Add(obj, options)
	if not obj.Parent and not options.RenderInNil then
		return warn(obj, "has no parent")
	end

	local box = setmetatable({
		Name = options.Name or obj.Name,
		Type = "Box",
		Color = options.Color --[[or self:GetColor(obj)]],
		Size = options.Size or self.BoxSize,
		Object = obj,
		Player = options.Player or plrs:GetPlayerFromCharacter(obj),
		PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
		Components = {},
		IsEnabled = options.IsEnabled,
		Temporary = options.Temporary,
		ColorDynamic = options.ColorDynamic,
		RenderInNil = options.RenderInNil,
		MaxDistance = options.MaxDistance,
		ShowHighlight = options.ShowHighlight ~= false,
	}, boxBase)

	if self:GetBox(obj) then
		self:GetBox(obj):Remove()
	end

	box.Components["QuadOutline"] = Draw("Quad", {
		Thickness = 4, 
		Color = Color3.fromRGB(0, 0, 0),  
		Transparency = 1,
		Filled = false,
		Visible = false  
	})

	box.Components["Quad"] = Draw("Quad", {
		Thickness = self.Thickness,
		Color = color,
		Transparency = 1,
		Filled = false,
		Visible = self.Enabled and self.Boxes
	})
	box.Components["Name"] = Draw("Text", {
		Text = box.Name,
		Color = box.Color,
		Center = true,
		Outline = true,
		Size = 15,
		Visible = self.Enabled and self.Names
	})
	box.Components["Distance"] = Draw("Text", {
		Color = box.Color,
		Center = true,
		Outline = true,
		Size = 15,
		Visible = self.Enabled and self.Names
	})
    box.Components["ExtraInfo"] = Draw("Text", {
		Color = box.Color,
		Center = true,
		Outline = true,
		Size = 15,
		Visible = self.Enabled and self.ExtraInfo
	})
	box.Components["Tracer"] = Draw("Line", {
		Thickness = ESP.Thickness,
		Color = box.Color,
		Transparency = 1,
		Visible = self.Enabled and self.Tracers
	})

	box.Components["SkeletonOutline"] = {}
	box.Components["Skeleton"] = {}

	for i = 1, 13 do
		box.Components["SkeletonOutline"][i] = Draw("Line", {
			Color = Color3.fromRGB(0, 0, 0), 
			Thickness = ESP.Thickness + 2,     
			Visible = false              
		})

		box.Components["Skeleton"][i] = Draw("Line", {
			Color = box.Color,
			Thickness = ESP.Thickness,
			Visible = false             
		})
	end

	box.Components["HeadCircleOutline"] = Draw("Circle", {
		Radius = 10,
		Thickness = 5,
		Color = Color3.fromRGB(0, 0, 0),
		NumSides = 20,
		Filled = false,
		Visible = false
	})

	box.Components["HeadCircle"] = Draw("Circle", {
		Radius = 10,
		Thickness = 2,
		Color = box.Color,
		NumSides = 20,
		Filled = false,
		Visible = false
	})

	box.Components["HealthBarBG"] = Draw("Line", {
		Thickness = 4,
		Color = Color3.fromRGB(0, 0, 0),
		Transparency = 1,
		Visible = false
	})

	box.Components["HealthBar"] = Draw("Line", {
		Thickness = 2,
		Color = Color3.fromRGB(0, 255, 0),
		Transparency = 1,
		Visible = false
	})


	self.Objects[obj] = box

	if options.Highlight then
		local highlight = Instance.new("Highlight")
		highlight.Name = "raii_highlight"
		highlight.Adornee = obj
		highlight.Enabled = true 
		highlight.FillColor = box.Color or Color3.fromRGB(255, 0, 0)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Parent = obj

		box.Components.Highlight = highlight
	end

	obj.AncestryChanged:Connect(function(_, parent)
		if parent == nil and ESP.AutoRemove ~= false then
			box:Remove()
		end
	end)
	obj:GetPropertyChangedSignal("Parent"):Connect(function()
		if obj.Parent == nil and ESP.AutoRemove ~= false then
			box:Remove()
		end
	end)

	local hum = obj:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			if ESP.AutoRemove ~= false then
				box:Remove()
			end
		end)
	end

	return box
end

local function CharAdded(char)
	local p = plrs:GetPlayerFromCharacter(char)
	if not char:FindFirstChild("HumanoidRootPart") then
		local ev
		ev = char.ChildAdded:Connect(function(c)
			if c.Name == "HumanoidRootPart" then
				ev:Disconnect()
				ESP:Add(char, {
					Name = p.Name,
					Player = p,
					ShowHighlight = true,
					Highlight = true,
					PrimaryPart = c
				})
			end
		end)
	else
		ESP:Add(char, {
			Name = p.Name,
			Player = p,
			ShowHighlight = true,
			Highlight = true,
			PrimaryPart = char.HumanoidRootPart
		})
	end
end
local function PlayerAdded(p)
	p.CharacterAdded:Connect(CharAdded)
	if p.Character then
		coroutine.wrap(CharAdded)(p.Character)
	end
end
plrs.PlayerAdded:Connect(PlayerAdded)
for i,v in pairs(plrs:GetPlayers()) do
	if v ~= plr then
		PlayerAdded(v)
	end
end

local RunService = cloneref(game:GetService("RunService"))
RunService.RenderStepped:Connect(function()
	cam = workspace.CurrentCamera
	for i,v in (ESP.Enabled and pairs or ipairs)(ESP.Objects) do
		if v.Update then
			local s,e = pcall(v.Update, v)
			if not s then warn("[EU]", e, v.Object:GetFullName()) end
		end
	end
end)

ESP:Toggle(true)
