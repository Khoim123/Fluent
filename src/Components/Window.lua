-- Window.lua
-- Refactored: rõ ràng theo kiểu OOP, tách state khỏi closure, giữ nguyên hành vi gốc
-- (drag, resize, minimize, maximize, tab selector animation, dialog, tab management)

local UserInputService = game:GetService("UserInputService")
local Mouse = game:GetService("Players").LocalPlayer:GetMouse()
local Camera = game:GetService("Workspace").CurrentCamera

local Root = script.Parent.Parent
local Flipper = require(Root.Packages.Flipper)
local Creator = require(Root.Creator)
local Acrylic = require(Root.Acrylic)
local Assets = require(script.Parent.Assets)
local Components = script.Parent

local Spring = Flipper.Spring.new
local Instant = Flipper.Instant.new
local New = Creator.New

-- Resize/window constraints
local MIN_SIZE = Vector2.new(470, 380)
local MAX_SIZE = Vector2.new(2048, 2048)
local RESIZE_HANDLE_SIZE = 20

--======================================================================
-- Window class
--======================================================================
local Window = {}
Window.__index = Window

function Window.new(Config)
	local self = setmetatable({}, Window)

	self.Library = require(Root)

	-- Public state
	self.Minimized = false
	self.Maximized = false
	self.Size = Config.Size
	self.TabWidth = Config.TabWidth
	self.Position = UDim2.fromOffset(
		Camera.ViewportSize.X / 2 - Config.Size.X.Offset / 2,
		Camera.ViewportSize.Y / 2 - Config.Size.Y.Offset / 2
	)

	-- Internal drag/resize state
	self._dragging = false
	self._dragInput = nil
	self._mousePos = nil
	self._startPos = nil

	self._resizing = false
	self._resizePos = nil

	self._minimizeNotifShown = false

	self._oldSizeX = nil
	self._oldSizeY = nil

	-- Selector-follow animation bookkeeping
	self._selectorLastValue = 0
	self._selectorLastTime = 0

	self:_buildUI(Config)
	self:_buildMotors()
	self:_bindMotorSteps()
	self:_bindInputHandlers()
	self:_bindTabHolderEvents()
	self:_initSubComponents()

	return self
end

--======================================================================
-- UI construction
--======================================================================
function Window:_buildUI(Config)
	self.AcrylicPaint = Acrylic.AcrylicPaint()

	self.Selector = New("Frame", {
		Size = UDim2.fromOffset(4, 0),
		BackgroundColor3 = Color3.fromRGB(76, 194, 255),
		Position = UDim2.fromOffset(0, 17),
		AnchorPoint = Vector2.new(0, 0.5),
		ThemeTag = { BackgroundColor3 = "Accent" },
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 2) }),
	})

	self.ResizeStartFrame = New("Frame", {
		Size = UDim2.fromOffset(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -RESIZE_HANDLE_SIZE, 1, -RESIZE_HANDLE_SIZE),
	})

	self.TabHolder = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarImageTransparency = 1,
		ScrollBarThickness = 0,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, {
		New("UIListLayout", { Padding = UDim.new(0, 4) }),
	})

	local tabFrame = New("Frame", {
		Size = UDim2.new(0, self.TabWidth, 1, -66),
		Position = UDim2.new(0, 12, 0, 54),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, {
		self.TabHolder,
		self.Selector,
	})

	self.TabDisplay = New("TextLabel", {
		RichText = true,
		Text = "Tab",
		TextTransparency = 0,
		FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
		TextSize = 28,
		TextXAlignment = "Left",
		TextYAlignment = "Center",
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(self.TabWidth + 26, 56),
		BackgroundTransparency = 1,
		ThemeTag = { TextColor3 = "Text" },
	})

	self.ContainerHolder = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	self.ContainerAnim = New("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	self.ContainerCanvas = New("Frame", {
		Size = UDim2.new(1, -self.TabWidth - 32, 1, -102),
		Position = UDim2.fromOffset(self.TabWidth + 26, 90),
		BackgroundTransparency = 1,
	}, {
		self.ContainerAnim,
		self.ContainerHolder,
	})

	self.Root = New("Frame", {
		BackgroundTransparency = 1,
		Size = self.Size,
		Position = self.Position,
		Parent = Config.Parent,
	}, {
		self.AcrylicPaint.Frame,
		self.TabDisplay,
		self.ContainerCanvas,
		tabFrame,
		self.ResizeStartFrame,
	})

	self.TitleBar = require(script.Parent.TitleBar)({
		Title = Config.Title,
		SubTitle = Config.SubTitle,
		Parent = self.Root,
		Window = self,
	})

	if self.Library.UseAcrylic then
		self.AcrylicPaint.AddParent(self.Root)
	end
end

--======================================================================
-- Motors (Flipper) setup
--======================================================================
function Window:_buildMotors()
	self.SizeMotor = Flipper.GroupMotor.new({
		X = self.Size.X.Offset,
		Y = self.Size.Y.Offset,
	})

	self.PosMotor = Flipper.GroupMotor.new({
		X = self.Position.X.Offset,
		Y = self.Position.Y.Offset,
	})

	self.SelectorPosMotor = Flipper.SingleMotor.new(17)
	self.SelectorSizeMotor = Flipper.SingleMotor.new(0)
	self.ContainerBackMotor = Flipper.SingleMotor.new(0)
	self.ContainerPosMotor = Flipper.SingleMotor.new(94)
end

function Window:_bindMotorSteps()
	self.SizeMotor:onStep(function(values)
		self.Root.Size = UDim2.new(0, values.X, 0, values.Y)
	end)

	self.PosMotor:onStep(function(values)
		self.Root.Position = UDim2.new(0, values.X, 0, values.Y)
	end)

	self.SelectorPosMotor:onStep(function(value)
		self.Selector.Position = UDim2.new(0, 0, 0, value + 17)

		local now = tick()
		local deltaTime = now - self._selectorLastTime

		if self._selectorLastValue ~= nil then
			local speed = math.abs(value - self._selectorLastValue) / (deltaTime * 60)
			self.SelectorSizeMotor:setGoal(Spring(speed + 16))
			self._selectorLastValue = value
		end
		self._selectorLastTime = now
	end)

	self.SelectorSizeMotor:onStep(function(value)
		self.Selector.Size = UDim2.new(0, 4, 0, value)
	end)

	self.ContainerBackMotor:onStep(function(value)
		self.ContainerAnim.GroupTransparency = value
	end)

	self.ContainerPosMotor:onStep(function(value)
		self.ContainerAnim.Position = UDim2.fromOffset(0, value)
	end)
end

--======================================================================
-- Maximize / Restore
--======================================================================
function Window:Maximize(value, noPos, instant)
	self.Maximized = value
	self.TitleBar.MaxButton.Frame.Icon.Image = value and Assets.Restore or Assets.Max

	if value then
		self._oldSizeX = self.Size.X.Offset
		self._oldSizeY = self.Size.Y.Offset
	end

	local sizeX = value and Camera.ViewportSize.X or self._oldSizeX
	local sizeY = value and Camera.ViewportSize.Y or self._oldSizeY
	local motorClass = instant and Flipper.Instant or Flipper.Spring

	self.SizeMotor:setGoal({
		X = motorClass.new(sizeX, { frequency = 6 }),
		Y = motorClass.new(sizeY, { frequency = 6 }),
	})
	self.Size = UDim2.fromOffset(sizeX, sizeY)

	if not noPos then
		self.PosMotor:setGoal({
			X = Spring(value and 0 or self.Position.X.Offset, { frequency = 6 }),
			Y = Spring(value and 0 or self.Position.Y.Offset, { frequency = 6 }),
		})
	end
end

--======================================================================
-- Input handling: drag, resize, minimize keybind
--======================================================================
function Window:_bindInputHandlers()
	Creator.AddSignal(self.TitleBar.Frame.InputBegan, function(input)
		self:_onTitleBarInputBegan(input)
	end)

	Creator.AddSignal(self.TitleBar.Frame.InputChanged, function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self._dragInput = input
		end
	end)

	Creator.AddSignal(self.ResizeStartFrame.InputBegan, function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self._resizing = true
			self._resizePos = input.Position
		end
	end)

	Creator.AddSignal(UserInputService.InputChanged, function(input)
		self:_onGlobalInputChanged(input)
	end)

	Creator.AddSignal(UserInputService.InputEnded, function(input)
		if self._resizing or input.UserInputType == Enum.UserInputType.Touch then
			self._resizing = false
			local size = self.SizeMotor:getValue()
			self.Size = UDim2.fromOffset(size.X, size.Y)
		end
	end)

	Creator.AddSignal(UserInputService.InputBegan, function(input)
		self:_onGlobalInputBegan(input)
	end)
end

function Window:_onTitleBarInputBegan(input)
	if
		input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end

	self._dragging = true
	self._mousePos = input.Position
	self._startPos = self.Root.Position

	if self.Maximized then
		self._startPos = UDim2.fromOffset(
			Mouse.X - (Mouse.X * ((self._oldSizeX - 100) / self.Root.AbsoluteSize.X)),
			Mouse.Y - (Mouse.Y * (self._oldSizeY / self.Root.AbsoluteSize.Y))
		)
	end

	input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			self._dragging = false
		end
	end)
end

function Window:_onGlobalInputChanged(input)
	if input == self._dragInput and self._dragging then
		local delta = input.Position - self._mousePos
		self.Position = UDim2.fromOffset(
			self._startPos.X.Offset + delta.X,
			self._startPos.Y.Offset + delta.Y
		)
		self.PosMotor:setGoal({
			X = Instant(self.Position.X.Offset),
			Y = Instant(self.Position.Y.Offset),
		})

		if self.Maximized then
			self:Maximize(false, true, true)
		end
	end

	local isPointerMove = input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch

	if isPointerMove and self._resizing then
		local delta = input.Position - self._resizePos
		local startSize = self.Size

		local targetSize = Vector3.new(startSize.X.Offset, startSize.Y.Offset, 0) + Vector3.new(1, 1, 0) * delta
		local clampedX = math.clamp(targetSize.X, MIN_SIZE.X, MAX_SIZE.X)
		local clampedY = math.clamp(targetSize.Y, MIN_SIZE.Y, MAX_SIZE.Y)

		self.SizeMotor:setGoal({
			X = Instant(clampedX),
			Y = Instant(clampedY),
		})
	end
end

function Window:_onGlobalInputBegan(input)
	if UserInputService:GetFocusedTextBox() then
		return
	end

	local minimizeKeybind = self.Library.MinimizeKeybind
	if type(minimizeKeybind) == "table" and minimizeKeybind.Type == "Keybind" then
		if input.KeyCode.Name == minimizeKeybind.Value then
			self:Minimize()
		end
	elseif input.KeyCode == self.Library.MinimizeKey then
		self:Minimize()
	end
end

--======================================================================
-- Minimize / Destroy
--======================================================================
function Window:Minimize()
	self.Minimized = not self.Minimized
	self.Root.Visible = not self.Minimized

	if not self._minimizeNotifShown then
		self._minimizeNotifShown = true
		local key = self.Library.MinimizeKeybind and self.Library.MinimizeKeybind.Value
			or self.Library.MinimizeKey.Name

		self.Library:Notify({
			Title = "Interface",
			Content = "Press " .. key .. " to toggle the interface.",
			Duration = 6,
		})
	end
end

function Window:Destroy()
	if self.Library.UseAcrylic then
		self.AcrylicPaint.Model:Destroy()
	end
	self.Root:Destroy()
end

--======================================================================
-- Sub-components: Dialog, Tab
--======================================================================
function Window:_initSubComponents()
	self._dialogModule = require(Components.Dialog):Init(self)
	self._tabModule = require(Components.Tab):Init(self)
end

function Window:Dialog(Config)
	local dialog = self._dialogModule:Create()
	dialog.Title.Text = Config.Title

	local content = New("TextLabel", {
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
		Text = Config.Content,
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.fromOffset(20, 60),
		BackgroundTransparency = 1,
		Parent = dialog.Root,
		ClipsDescendants = false,
		ThemeTag = { TextColor3 = "Text" },
	})

	New("UISizeConstraint", {
		MinSize = Vector2.new(300, 165),
		MaxSize = Vector2.new(620, math.huge),
		Parent = dialog.Root,
	})

	dialog.Root.Size = UDim2.fromOffset(content.TextBounds.X + 40, 165)
	if content.TextBounds.X + 40 > self.Size.X.Offset - 120 then
		dialog.Root.Size = UDim2.fromOffset(self.Size.X.Offset - 120, 165)
		content.TextWrapped = true
		dialog.Root.Size = UDim2.fromOffset(self.Size.X.Offset - 120, content.TextBounds.Y + 150)
	end

	for _, button in next, Config.Buttons do
		dialog:Button(button.Title, button.Callback)
	end

	dialog:Open()
end

--======================================================================
-- Tabs
--======================================================================
function Window:_bindTabHolderEvents()
	Creator.AddSignal(self.TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		self.TabHolder.CanvasSize = UDim2.new(0, 0, 0, self.TabHolder.UIListLayout.AbsoluteContentSize.Y)
	end)

	Creator.AddSignal(self.TabHolder:GetPropertyChangedSignal("CanvasPosition"), function()
		self._selectorLastValue = self._tabModule:GetCurrentTabPos() + 16
		self._selectorLastTime = 0
		self.SelectorPosMotor:setGoal(Instant(self._tabModule:GetCurrentTabPos()))
	end)
end

function Window:AddTab(TabConfig)
	return self._tabModule:New(TabConfig.Title, TabConfig.Icon, self.TabHolder)
end

function Window:SelectTab(_Tab)
	self._tabModule:SelectTab(1)
end

--======================================================================
-- Module entry point (giữ nguyên interface gốc: return function(Config))
--======================================================================
return function(Config)
	local window = Window.new(Config)
	return window
end