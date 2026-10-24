local Root = script.Parent.Parent
local Element = require(Root.Element)
local Style = require(Root.Style)
local Theme = require(Root.Theme)
local Util = require(Root.Util)
local Type = require(Root.Type)
local Signal = require(Root.Signal)

local Checkbox = Element.new()
Checkbox.__index = Checkbox
Checkbox.ClassName = "Checkbox"

function Checkbox.new(data)
	local self = setmetatable(Element.new(), Checkbox)

	self._value = false
	self._hasBeenAnimated = false

	self:AddSignal("OnChanged")

	self._instance = Instance.new("Frame")
	self._instance.Name = "Checkbox"
	self._instance.BackgroundTransparency = 1
	self._instance.Size = UDim2.new(1, 0, 0, data.Height or 30)

	self._layout = Instance.new("UIListLayout")
	self._layout.Padding = UDim.new(0, 8)
	self._layout.FillDirection = Enum.FillDirection.Horizontal
	self._layout.VerticalAlignment = Enum.VerticalAlignment.Center
	self._layout.SortOrder = Enum.SortOrder.LayoutOrder
	self._layout.Parent = self._instance

	-- Box (ô vuông tick)
	self._box = Instance.new("Frame")
	self._box.Name = "Box"
	self._box.Size = UDim2.fromOffset(18, 18)
	self._box.BackgroundColor3 = Theme.Colors.ElementBg
	self._box.BorderSizePixel = 0
	self._box.LayoutOrder = 1
	self._box.Parent = self._instance

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 4)
	boxCorner.Parent = self._box

	local boxStroke = Instance.new("UIStroke")
	boxStroke.Thickness = 1
	boxStroke.Color = Theme.Colors.ElementBorder
	boxStroke.Parent = self._box
	self._boxStroke = boxStroke

	-- Icon tick
	self._icon = Instance.new("ImageLabel")
	self._icon.Name = "Check"
	self._icon.Size = UDim2.fromScale(0.8, 0.8)
	self._icon.Position = UDim2.fromScale(0.5, 0.5)
	self._icon.AnchorPoint = Vector2.new(0.5, 0.5)
	self._icon.BackgroundTransparency = 1
	self._icon.Image = Theme.Icons.Check
	self._icon.ImageColor3 = Theme.Colors.ElementText
	self._icon.ImageTransparency = 1
	self._icon.Parent = self._box

	-- Label
	self._label = Instance.new("TextLabel")
	self._label.Name = "Label"
	self._label.Size = UDim2.new(1, -26, 1, 0)
	self._label.BackgroundTransparency = 1
	self._label.Text = data.Title or "Checkbox"
	self._label.TextColor3 = Theme.Colors.ElementText
	self._label.Font = Theme.Fonts.Regular
	self._label.TextSize = 14
	self._label.TextXAlignment = Enum.TextXAlignment.Left
	self._label.LayoutOrder = 2
	self._label.Parent = self._instance

	-- Interaction button (phủ toàn bộ để dễ click)
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.ZIndex = 2
	button.Parent = self._instance

	-- Hover effect
	button.MouseEnter:Connect(function()
		if not self._isHovering then
			self._isHovering = true
			boxStroke.Color = Theme.Colors.ElementBorderHover
		end
	end)

	button.MouseLeave:Connect(function()
		if self._isHovering then
			self._isHovering = false
			boxStroke.Color = Theme.Colors.ElementBorder
		end
	end)

	-- Click handler
	button.MouseButton1Click:Connect(function()
		self:SetValue(not self._value, true)
	end)

	-- Sub-elements cho Checkbox
	self:AddSubElement(self._box)
	self:AddSubElement(self._label)

	-- Nếu có data.Value thì set ban đầu
	if data.Value ~= nil then
		self:SetValue(data.Value, false)
	end

	-- Cho phép Tooltip nếu có
	if data.Tooltip then
		self:SetTooltip(data.Tooltip)
	end

	return self
end

function Checkbox:GetValue()
	return self._value
end

function Checkbox:SetValue(value, doCallback)
	assert(Type.typeof(value) == "boolean", "Expected boolean for Checkbox value")

	if value == self._value then
		return self
	end

	self._value = value

	-- Animation
	if not self._hasBeenAnimated then
		self._hasBeenAnimated = true
		self._icon.ImageTransparency = value and 0 or 1
		self._box.BackgroundColor3 = value and Theme.Colors.Accent or Theme.Colors.ElementBg
	else
		-- Tween mượt
		Util.Tween(0.15, "Quad", "Out", function(alpha)
			self._icon.ImageTransparency = value and alpha or (1 - alpha)
			self._box.BackgroundColor3 = value
				and Theme.Colors.Accent:Lerp(Theme.Colors.ElementBg, 1 - alpha)
				or Theme.Colors.ElementBg:Lerp(Theme.Colors.Accent, 1 - alpha)
		end)
	end

	if doCallback then
		self:Fire("OnChanged", value)
	end

	return self
end

function Checkbox:OnChanged(callback)
	return self:AddConnection("OnChanged", callback)
end

return Checkbox