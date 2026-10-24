local Root = script.Parent.Parent
local Element = require(Root.Element)
local Style = require(Root.Style)
local Theme = require(Root.Theme)
local Util = require(Root.Util)
local Type = require(Root.Type)
local Signal = require(Root.Signal)

local Radio = Element.new()
Radio.__index = Radio
Radio.ClassName = "Radio"

function Radio.new(data)
	local self = setmetatable(Element.new(), Radio)

	self._value = false
	self._hasBeenAnimated = false
	self._group = data.Group  -- optional, gán từ RadioGroup

	self:AddSignal("OnChanged")

	self._instance = Instance.new("Frame")
	self._instance.Name = "Radio"
	self._instance.BackgroundTransparency = 1
	self._instance.Size = UDim2.new(1, 0, 0, data.Height or 30)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self._instance

	-- Vòng tròn ngoài (khung)
	self._circle = Instance.new("Frame")
	self._circle.Name = "Circle"
	self._circle.Size = UDim2.fromOffset(18, 18)
	self._circle.BackgroundColor3 = Theme.Colors.ElementBg
	self._circle.BorderSizePixel = 0
	self._circle.LayoutOrder = 1
	self._circle.Parent = self._instance

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(1, 0)  -- tròn hoàn toàn
	circleCorner.Parent = self._circle

	self._circleStroke = Instance.new("UIStroke")
	self._circleStroke.Thickness = 1
	self._circleStroke.Color = Theme.Colors.ElementBorder
	self._circleStroke.Parent = self._circle

	-- Chấm tròn đặc ở giữa (chỉ hiện khi được chọn)
	self._dot = Instance.new("Frame")
	self._dot.Name = "Dot"
	self._dot.Size = UDim2.fromScale(0.5, 0.5)  -- ~9px
	self._dot.Position = UDim2.fromScale(0.5, 0.5)
	self._dot.AnchorPoint = Vector2.new(0.5, 0.5)
	self._dot.BackgroundColor3 = Theme.Colors.Accent
	self._dot.BorderSizePixel = 0
	self._dot.Visible = false
	self._dot.Parent = self._circle

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = self._dot

	-- Label
	self._label = Instance.new("TextLabel")
	self._label.Name = "Label"
	self._label.Size = UDim2.new(1, -26, 1, 0)
	self._label.BackgroundTransparency = 1
	self._label.Text = data.Title or "Radio"
	self._label.TextColor3 = Theme.Colors.ElementText
	self._label.Font = Theme.Fonts.Regular
	self._label.TextSize = 14
	self._label.TextXAlignment = Enum.TextXAlignment.Left
	self._label.LayoutOrder = 2
	self._label.Parent = self._instance

	-- Button phủ để bắt click
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.ZIndex = 2
	button.Parent = self._instance

	button.MouseEnter:Connect(function()
		self._circleStroke.Color = Theme.Colors.ElementBorderHover
	end)
	button.MouseLeave:Connect(function()
		self._circleStroke.Color = Theme.Colors.ElementBorder
	end)

	button.MouseButton1Click:Connect(function()
		self:SetValue(true, true)
	end)

	self:AddSubElement(self._circle)
	self:AddSubElement(self._label)

	-- Nếu set value ban đầu
	if data.Value then
		self:SetValue(true, false)
	end

	if data.Tooltip then
		self:SetTooltip(data.Tooltip)
	end

	return self
end

function Radio:GetValue()
	return self._value
end

function Radio:SetValue(value, doCallback)
	assert(Type.typeof(value) == "boolean", "Expected boolean for Radio value")

	if value == self._value then
		return self
	end

	-- Nếu bật lên và đang thuộc 1 group → tắt các radio khác
	if value and self._group then
		self._group:_SelectRadio(self)
	end

	self._value = value

	-- Animation: chấm giữa phóng to / thu nhỏ
	if value then
		self._dot.Visible = true
		self._dot.Size = UDim2.fromScale(0, 0)
		Util.Tween(0.18, "Back", "Out", function(alpha)
			self._dot.Size = UDim2.fromScale(0.5 * alpha, 0.5 * alpha)
		end)
	else
		Util.Tween(0.12, "Quad", "In", function(alpha)
			self._dot.Size = UDim2.fromScale(0.5 * (1 - alpha), 0.5 * (1 - alpha))
			if alpha >= 1 then
				self._dot.Visible = false
			end
		end)
	end

	if doCallback then
		self:Fire("OnChanged", value)
	end

	return self
end

function Radio:OnChanged(callback)
	return self:AddConnection("OnChanged", callback)
end

return Radio