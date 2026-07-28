local TweenService = game:GetService("TweenService")
local Root = script.Parent.Parent
local Creator = require(Root.Creator)

local New = Creator.New
local Components = Root.Components

local Element = {}
Element.__index = Element
Element.__type = "Toggle"

function Element:New(Idx, Config)
	local Library = self.Library
	assert(Config.Title, "Toggle - Missing Title")

	local Toggle = {
		Value = Config.Default or false,
		Callback = Config.Callback or function(Value) end,
		Type = "Toggle",
	}

	local ToggleFrame = require(Components.Element)(Config.Title, Config.Description, self.Container, true)
	ToggleFrame.DescLabel.Size = UDim2.new(1, -54, 0, 14)

	Toggle.SetTitle = ToggleFrame.SetTitle
	Toggle.SetDesc = ToggleFrame.SetDesc

	-- Hình tròn duy nhất, không trượt, chỉ đổi màu + icon check khi bật
	local ToggleCircle = New("ImageLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -10, 0.5, 0),
		Image = "rbxassetid://3926305904", -- icon check (roblox default sprite sheet, thay bằng icon check bạn muốn)
		ImageRectOffset = Vector2.new(312, 4),
		ImageRectSize = Vector2.new(24, 24),
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		BackgroundTransparency = 0,
		ThemeTag = {
			BackgroundColor3 = "ToggleSlider",
			ImageColor3 = "ToggleToggled",
		},
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(1, 0), -- bo tròn hoàn toàn
		}),
		New("UIStroke", {
			Transparency = 0.5,
			ThemeTag = {
				Color = "ToggleSlider",
			},
		}),
	})

	ToggleCircle.Parent = ToggleFrame.Frame

	function Toggle:OnChanged(Func)
		Toggle.Changed = Func
		Func(Toggle.Value)
	end

	function Toggle:SetValue(Value)
		Value = not not Value
		Toggle.Value = Value

		Creator.OverrideTag(ToggleCircle, {
			BackgroundColor3 = Toggle.Value and "Accent" or "ToggleSlider",
		})

		TweenService:Create(
			ToggleCircle,
			TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ ImageTransparency = Toggle.Value and 0 or 1 }
		):Play()

		Library:SafeCallback(Toggle.Callback, Toggle.Value)
		Library:SafeCallback(Toggle.Changed, Toggle.Value)
	end

	function Toggle:Destroy()
		ToggleFrame:Destroy()
		Library.Options[Idx] = nil
	end

	Creator.AddSignal(ToggleFrame.Frame.MouseButton1Click, function()
		Toggle:SetValue(not Toggle.Value)
	end)

	Toggle:SetValue(Toggle.Value)

	Library.Options[Idx] = Toggle
	return Toggle
end

return Element