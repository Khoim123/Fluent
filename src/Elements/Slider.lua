local UserInputService = game:GetService("UserInputService")
local Root = script.Parent.Parent
local Creator = require(Root.Creator)

local New = Creator.New
local Components = Root.Components

local Element = {}
Element.__index = Element
Element.__type = "Slider"

function Element:New(Idx, Config)
	local Library = self.Library
	assert(Config.Title, "Slider - Missing Title.")
	assert(Config.Default, "Slider - Missing default value.")
	assert(Config.Min, "Slider - Missing minimum value.")
	assert(Config.Max, "Slider - Missing maximum value.")
	assert(Config.Rounding, "Slider - Missing rounding value.")

	local Slider = {
		Value = nil,
		Min = Config.Min,
		Max = Config.Max,
		Rounding = Config.Rounding,
		Callback = Config.Callback or function(Value) end,
		Type = "Slider",
	}

	local Dragging = false
	local ActiveTouch = nil -- theo dõi đúng ngón tay đang kéo

	local SliderFrame = require(Components.Element)(Config.Title, Config.Description, self.Container, false)
	SliderFrame.DescLabel.Size = UDim2.new(1, -170, 0, 14)

	Slider.SetTitle = SliderFrame.SetTitle
	Slider.SetDesc = SliderFrame.SetDesc

	local SliderDot = New("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -7, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Image = "http://www.roblox.com/asset/?id=12266946128",
		ZIndex = 2,
		ThemeTag = {
			ImageColor3 = "Accent",
		},
	})

	-- Vùng chạm mở rộng, vô hình, to hơn hẳn để dễ bấm trúng trên điện thoại
	local SliderDotHitbox = New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 3,
		Parent = SliderDot,
	})

	local SliderRail = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(7, 0),
		Size = UDim2.new(1, -14, 1, 0),
	}, {
		SliderDot,
	})

	local SliderFill = New("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		ThemeTag = {
			BackgroundColor3 = "Accent",
		},
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
	})

	local SliderDisplay = New("TextLabel", {
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
		Text = "Value",
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 100, 0, 14),
		Position = UDim2.new(0, -4, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		ThemeTag = {
			TextColor3 = "SubText",
		},
	})

	local SliderInner = New("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		BackgroundTransparency = 0.4,
		Parent = SliderFrame.Frame,
		ThemeTag = {
			BackgroundColor3 = "SliderRail",
		},
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		New("UISizeConstraint", {
			MaxSize = Vector2.new(150, math.huge),
		}),
		SliderDisplay,
		SliderFill,
		SliderRail,
	})

	local function UpdateFromX(XPos)
		local SizeScale = math.clamp((XPos - SliderRail.AbsolutePosition.X) / SliderRail.AbsoluteSize.X, 0, 1)
		Slider:SetValue(Slider.Min + ((Slider.Max - Slider.Min) * SizeScale))
	end

	-- Bắt đầu kéo từ chấm (hitbox to hơn)
	Creator.AddSignal(SliderDotHitbox.InputBegan, function(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Dragging = true
			ActiveTouch = Input
		end
	end)

	-- Cho phép bấm/chạm bất kỳ đâu trên cả thanh trượt để nhảy tới đó và bắt đầu kéo luôn
	-- (giúp thao tác trên điện thoại dễ hơn nhiều vì không cần bấm trúng chấm nhỏ)
	Creator.AddSignal(SliderInner.InputBegan, function(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Dragging = true
			ActiveTouch = Input
			UpdateFromX(Input.Position.X)
		end
	end)

	local function StopDragging(Input)
		if ActiveTouch == nil or Input == ActiveTouch or Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Dragging = false
			ActiveTouch = nil
		end
	end

	Creator.AddSignal(SliderDotHitbox.InputEnded, StopDragging)
	Creator.AddSignal(SliderInner.InputEnded, StopDragging)
	Creator.AddSignal(UserInputService.InputEnded, StopDragging)

	Creator.AddSignal(UserInputService.InputChanged, function(Input)
		if
			Dragging
			and (
				Input.UserInputType == Enum.UserInputType.MouseMovement
				or Input.UserInputType == Enum.UserInputType.Touch
			)
		then
			UpdateFromX(Input.Position.X)
		end
	end)

	function Slider:OnChanged(Func)
		Slider.Changed = Func
		Func(Slider.Value)
	end

	function Slider:SetValue(Value)
		self.Value = Library:Round(math.clamp(Value, Slider.Min, Slider.Max), Slider.Rounding)
		SliderDot.Position = UDim2.new((self.Value - Slider.Min) / (Slider.Max - Slider.Min), -7, 0.5, 0)
		SliderFill.Size = UDim2.fromScale((self.Value - Slider.Min) / (Slider.Max - Slider.Min), 1)
		SliderDisplay.Text = tostring(self.Value)

		Library:SafeCallback(Slider.Callback, self.Value)
		Library:SafeCallback(Slider.Changed, self.Value)
	end

	function Slider:Destroy()
		SliderFrame:Destroy()
		Library.Options[Idx] = nil
	end

	Slider:SetValue(Config.Default)

	Library.Options[Idx] = Slider
	return Slider
end

return Element