local Root = script.Parent.Parent
local Element = require(Root.Element)
local Theme = require(Root.Theme)
local Radio = require(script.Parent.Radio)
local Type = require(Root.Type)

local RadioGroup = Element.new()
RadioGroup.__index = RadioGroup
RadioGroup.ClassName = "RadioGroup"

function RadioGroup.new(data)
	local self = setmetatable(Element.new(), RadioGroup)

	self._radios = {}
	self._selected = nil

	self:AddSignal("OnChanged")

	self._instance = Instance.new("Frame")
	self._instance.Name = "RadioGroup"
	self._instance.BackgroundTransparency = 1
	self._instance.Size = UDim2.new(1, 0, 0, 0)
	self._instance.AutomaticSize = Enum.AutomaticSize.Y

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self._instance

	-- Thêm các option ban đầu nếu có
	if data.Options then
		for _, opt in ipairs(data.Options) do
			self:AddRadio(opt)
		end
	end

	-- Set giá trị mặc định
	if data.Value then
		self:SetValue(data.Value, false)
	end

	return self
end

-- Thêm 1 radio vào group
-- opt có thể là string (title) hoặc table { Title = "...", Value = "..." }
function RadioGroup:AddRadio(opt)
	if Type.typeof(opt) == "string" then
		opt = { Title = opt }
	end

	local radio = Radio.new({
		Title = opt.Title or "Option",
		Value = false,
		Group = self,
		Height = opt.Height,
		Tooltip = opt.Tooltip,
	})

	radio._radioValue = opt.Value or opt.Title  -- giá trị đại diện khi selected
	radio.LayoutOrder = #self._radios + 1

	radio:OnChanged(function(state)
		if state then
			self._selected = radio._radioValue
			self:Fire("OnChanged", radio._radioValue)
		end
	end)

	radio:SetParent(self._instance)
	table.insert(self._radios, radio)

	return radio
end

-- Nội bộ: được Radio gọi khi 1 radio được chọn
function RadioGroup:_SelectRadio(target)
	for _, r in ipairs(self._radios) do
		if r ~= target and r:GetValue() then
			r:SetValue(false, false)
		end
	end
	self._selected = target._radioValue
end

function RadioGroup:GetValue()
	return self._selected
end

function RadioGroup:SetValue(value, doCallback)
	for _, r in ipairs(self._radios) do
		if r._radioValue == value then
			r:SetValue(true, false)
			self._selected = value
			if doCallback then
				self:Fire("OnChanged", value)
			end
			return self
		end
	end
	-- Không tìm thấy → bỏ chọn tất cả
	for _, r in ipairs(self._radios) do
		r:SetValue(false, false)
	end
	self._selected = nil
	return self
end

function RadioGroup:OnChanged(callback)
	return self:AddConnection("OnChanged", callback)
end

return RadioGroup