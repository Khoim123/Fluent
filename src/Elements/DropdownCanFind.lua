local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Mouse = game:GetService("Players").LocalPlayer:GetMouse()
local Camera = game:GetService("Workspace").CurrentCamera

local Root = script.Parent.Parent
local Creator = require(Root.Creator)
local Flipper = require(Root.Packages.Flipper)

local New = Creator.New
local Components = Root.Components

local Element = {}
Element.__index = Element
Element.__type = "DropdownCanFind"

function Element:New(Idx, Config)
    local Library = self.Library

    local Dropdown = {
        Values = Config.Values,
        Value = Config.Multi and (type(Config.Default) == "table" and Config.Default or {}) or Config.Default,
        Multi = Config.Multi,
        Buttons = {},
        Opened = false,
        Type = "Dropdown",
        Callback = Config.Callback or function() end,
        -- [OPT] Cache để tránh rebuild + tra cứu O(1)
        _buttonByValue = {},
        _cachedValues = nil,
    }

    local DropdownFrame = require(Components.Element)(Config.Title, Config.Description, self.Container, false)
    DropdownFrame.DescLabel.Size = UDim2.new(1, -170, 0, 14)
    Dropdown.SetTitle = DropdownFrame.SetTitle
    Dropdown.SetDesc = DropdownFrame.SetDesc

    local DropdownDisplay = New("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
        Text = "Value",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -30, 0, 14),
        Position = UDim2.new(0, 8, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ThemeTag = { TextColor3 = "Text" },
    })

    local DropdownIco = New("ImageLabel", {
        Image = "rbxassetid://10709790948",
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        BackgroundTransparency = 1,
        ThemeTag = { ImageColor3 = "SubText" },
    })

    local DropdownInner = New("TextButton", {
        Size = UDim2.fromOffset(160, 30),
        Position = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 0.9,
        Parent = DropdownFrame.Frame,
        ThemeTag = { BackgroundColor3 = "DropdownFrame" },
    }, {
        New("UICorner", { CornerRadius = UDim.new(0, 5) }),
        New("UIStroke", {
            Transparency = 0.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            ThemeTag = { Color = "InElementBorder" },
        }),
        DropdownIco,
        DropdownDisplay,
    })

    local DropdownListLayout = New("UIListLayout", { Padding = UDim.new(0, 3) })

    local DropdownScrollFrame = New("ScrollingFrame", {
        Size = UDim2.new(1, -10, 1, -50),
        Position = UDim2.fromOffset(5, 40),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        BottomImage = "rbxassetid://6889812791",
        MidImage = "rbxassetid://6889812721",
        TopImage = "rbxassetid://6276641225",
        ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
        ScrollBarImageTransparency = 0.95,
        ScrollBarThickness = 4,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromScale(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, { DropdownListLayout })

    local SearchInputRef = New("TextBox", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
        Text = "",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 13,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        PlaceholderText = "Search...",
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.fromOffset(5, 0),
        Name = "SearchInput",
        ThemeTag = { TextColor3 = "Text" },
    })

    local SearchBarFrame = New("Frame", {
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Size = UDim2.new(1, -10, 0, 26),
        Position = UDim2.fromOffset(5, 5),
    }, {
        New("UIStroke", {
            Transparency = 0.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            ThemeTag = { Color = "InElementBorder" },
        }),
        New("UICorner", { CornerRadius = UDim.new(0, 5) }),
        SearchInputRef,
    })

    local DropdownHolderFrame = New("Frame", {
        Size = UDim2.fromScale(1, 0.6),
        ClipsDescendants = true,
        ThemeTag = { BackgroundColor3 = "DropdownHolder" },
    }, {
        SearchBarFrame,
        DropdownScrollFrame,
        New("UICorner", { CornerRadius = UDim.new(0, 7) }),
        New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            ThemeTag = { Color = "DropdownBorder" },
        }),
        New("ImageLabel", {
            BackgroundTransparency = 1,
            Image = "http://www.roblox.com/asset/?id=5554236805",
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(23, 23, 277, 277),
            Size = UDim2.fromScale(1, 1) + UDim2.fromOffset(30, 30),
            Position = UDim2.fromOffset(-15, -15),
            ImageColor3 = Color3.fromRGB(0, 0, 0),
            ImageTransparency = 0.1,
        }),
    })

    local DropdownHolderCanvas = New("Frame", {
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Size = UDim2.fromOffset(170, 300),
        Parent = self.Library.GUI,
        Visible = false,
    }, {
        DropdownHolderFrame,
        New("UISizeConstraint", { MinSize = Vector2.new(170, 0) }),
    })
    table.insert(Library.OpenFrames, DropdownHolderCanvas)

    local ListSizeX = 0

    -- [OPT #5] Debounce recalc để tránh fire O(N) lần khi build
    local _recalcPending = false
    local function ScheduleRecalc()
        if _recalcPending then return end
        _recalcPending = true
        task.defer(function()
            _recalcPending = false
            DropdownScrollFrame.CanvasSize =
                UDim2.fromOffset(0, DropdownListLayout.AbsoluteContentSize.Y)
            local contentHeight = DropdownListLayout.AbsoluteContentSize.Y
            local finalHeight = math.clamp(contentHeight + 50, 70, 392)
            DropdownHolderCanvas.Size = UDim2.fromOffset(ListSizeX, finalHeight)
        end)
    end

    local function RecalculateListPosition()
        local Add = 0
        if Camera.ViewportSize.Y - DropdownInner.AbsolutePosition.Y < DropdownHolderCanvas.AbsoluteSize.Y - 5 then
            Add = DropdownHolderCanvas.AbsoluteSize.Y
                - 5
                - (Camera.ViewportSize.Y - DropdownInner.AbsolutePosition.Y)
                + 40
        end
        DropdownHolderCanvas.Position =
            UDim2.fromOffset(DropdownInner.AbsolutePosition.X - 1, DropdownInner.AbsolutePosition.Y - 5 - Add)
    end

    -- [OPT] Chỉ 1 signal duy nhất, debounce bên trong
    Creator.AddSignal(
        DropdownListLayout:GetPropertyChangedSignal("AbsoluteContentSize"),
        ScheduleRecalc
    )

    RecalculateListPosition()
    ScheduleRecalc()

    Creator.AddSignal(DropdownInner:GetPropertyChangedSignal("AbsolutePosition"), RecalculateListPosition)

    Creator.AddSignal(DropdownInner.MouseButton1Click, function()
        if Dropdown.Opened then Dropdown:Close() else Dropdown:Open() end
    end)

    Creator.AddSignal(UserInputService.InputBegan, function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1
            or Input.UserInputType == Enum.UserInputType.Touch
        then
            if not Dropdown.Opened then return end

            local InnerPos = DropdownInner.AbsolutePosition
            local InnerSize = DropdownInner.AbsoluteSize
            if Mouse.X >= InnerPos.X and Mouse.X <= InnerPos.X + InnerSize.X
                and Mouse.Y >= InnerPos.Y and Mouse.Y <= InnerPos.Y + InnerSize.Y
            then
                return
            end

            local AbsPos, AbsSize = DropdownHolderFrame.AbsolutePosition, DropdownHolderFrame.AbsoluteSize
            if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y
            then
                Dropdown:Close()
            end
        end
    end)

    local ScrollFrame = self.ScrollFrame

    function Dropdown:Open()
        Dropdown.Opened = true
        ScrollFrame.ScrollingEnabled = false
        DropdownHolderCanvas.Visible = true
        local tw = TweenService:Create(
            DropdownHolderFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Size = UDim2.fromScale(1, 1) }
        )
        tw:Play()
        tw.Completed:Connect(ScheduleRecalc)
    end

    function Dropdown:Close()
        Dropdown.Opened = false
        ScrollFrame.ScrollingEnabled = true
        local CloseTween = TweenService:Create(
            DropdownHolderFrame,
            TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Size = UDim2.fromScale(1, 0.6) }
        )
        CloseTween:Play()
        CloseTween.Completed:Connect(function()
            DropdownHolderCanvas.Visible = false
            -- [OPT #5] Reset search, không rebuild
            SearchInputRef.Text = ""
            Dropdown:ApplySearchFilter()
        end)
    end

    function Dropdown:Display()
        -- [OPT] table.concat thay vì nối chuỗi O(N²)
        if Config.Multi then
            local parts = {}
            for _, Value in next, Dropdown.Values do
                if Dropdown.Value[Value] then
                    parts[#parts + 1] = Value
                end
            end
            DropdownDisplay.Text = #parts > 0 and table.concat(parts, ", ") or "--"
        else
            DropdownDisplay.Text = Dropdown.Value or "--"
        end
    end

    function Dropdown:GetActiveValues()
        if Config.Multi then
            local T = {}
            for Value in next, Dropdown.Value do table.insert(T, Value) end
            return T
        else
            return Dropdown.Value and 1 or 0
        end
    end

    -- [OPT] Chỉ ẩn/hiện button theo search, KHÔNG destroy/tạo lại
    function Dropdown:ApplySearchFilter()
        local searchText = string.lower(SearchInputRef.Text)
        local byValue = Dropdown._buttonByValue
        if not byValue then return end

        if searchText == "" then
            for _, Table in next, byValue do
                Table.Button.Visible = true
            end
        else
            for Value, Table in next, byValue do
                Table.Button.Visible =
                    string.find(string.lower(tostring(Value)), searchText, 1, true) ~= nil
            end
        end
        ScheduleRecalc()
    end

    SearchInputRef:GetPropertyChangedSignal("Text"):Connect(function()
        if Dropdown.Opened then
            Dropdown:ApplySearchFilter()
        end
    end)

    function Dropdown:BuildDropdownList()
        local Values = Dropdown.Values
        local Buttons = {}
        local buttonByValue = {}

        for _, Child in next, DropdownScrollFrame:GetChildren() do
            if not Child:IsA("UIListLayout") then
                Child:Destroy()
            end
        end

        for Idx, Value in next, Values do
            local Table = {}

            local ButtonSelector = New("Frame", {
                Size = UDim2.fromOffset(4, 14),
                BackgroundColor3 = Color3.fromRGB(76, 194, 255),
                Position = UDim2.fromOffset(-1, 16),
                AnchorPoint = Vector2.new(0, 0.5),
                ThemeTag = { BackgroundColor3 = "Accent" },
            }, {
                New("UICorner", { CornerRadius = UDim.new(0, 2) }),
            })

            local ButtonLabel = New("TextLabel", {
                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                Text = Value,
                TextColor3 = Color3.fromRGB(200, 200, 200),
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -20, 1, 0),
                Position = UDim2.fromOffset(10, 0),
                Name = "ButtonLabel",
                ThemeTag = { TextColor3 = "Text" },
            })

            local Button = New("TextButton", {
                Size = UDim2.new(1, -5, 0, 32),
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                ZIndex = 23,
                Text = "",
                Parent = DropdownScrollFrame,
                ThemeTag = { BackgroundColor3 = "DropdownOption" },
            }, {
                ButtonSelector,
                ButtonLabel,
                New("UICorner", { CornerRadius = UDim.new(0, 6) }),
            })

            local Selected
            if Config.Multi then
                Selected = Dropdown.Value[Value]
            else
                Selected = Dropdown.Value == Value
            end

            local BackMotor, SetBackTransparency = Creator.SpringMotor(1, Button, "BackgroundTransparency")
            local SelMotor, SetSelTransparency = Creator.SpringMotor(1, ButtonSelector, "BackgroundTransparency")
            local SelectorSizeMotor = Flipper.SingleMotor.new(6)
            SelectorSizeMotor:onStep(function(value)
                ButtonSelector.Size = UDim2.new(0, 4, 0, value)
            end)

            Creator.AddSignal(Button.MouseEnter, function()
                SetBackTransparency(Selected and 0.85 or 0.89)
            end)
            Creator.AddSignal(Button.MouseLeave, function()
                SetBackTransparency(Selected and 0.89 or 1)
            end)
            Creator.AddSignal(Button.MouseButton1Down, function()
                SetBackTransparency(0.92)
            end)
            Creator.AddSignal(Button.MouseButton1Up, function()
                SetBackTransparency(Selected and 0.85 or 0.89)
            end)

            function Table:UpdateButton()
                if Config.Multi then
                    Selected = Dropdown.Value[Value]
                else
                    Selected = Dropdown.Value == Value
                end
                SetBackTransparency(Selected and 0.89 or 1)
                SelectorSizeMotor:setGoal(Flipper.Spring.new(Selected and 14 or 6, { frequency = 6 }))
                SetSelTransparency(Selected and 0 or 1)
            end

            ButtonLabel.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1
                    or Input.UserInputType == Enum.UserInputType.Touch
                then
                    local Try = not Selected
                    if Dropdown:GetActiveValues() == 1 and not Try and not Config.AllowNull then
                        return
                    end

                    if Config.Multi then
                        Selected = Try
                        Dropdown.Value[Value] = Selected and true or nil
                        Table:UpdateButton()
                    else
                        -- [OPT #3] Chỉ update button cũ + mới, KHÔNG loop N
                        local oldValue = Dropdown.Value
                        Selected = Try
                        Dropdown.Value = Selected and Value or nil

                        if oldValue and oldValue ~= Value
                            and Dropdown._buttonByValue[oldValue]
                        then
                            Dropdown._buttonByValue[oldValue]:UpdateButton()
                        end
                        Table:UpdateButton()
                    end

                    Dropdown:Display()
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                    Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
                end
            end)

            Table.Button = Button
            Table.Value = Value

            Buttons[Button] = Table
            buttonByValue[Value] = Table
        end

        Dropdown.Buttons = Buttons
        Dropdown._buttonByValue = buttonByValue

        -- [OPT #1] Update tất cả MỘT LẦN, không gọi Display trong loop
        for _, Table in next, Buttons do
            Table:UpdateButton()
        end
        Dropdown:Display()

        -- Tính ListSizeX (giữ nguyên logic cũ)
        ListSizeX = 0
        for _, Table in next, Buttons do
            local bounds = Table.Button.ButtonLabel.TextBounds
            if bounds.X > ListSizeX then ListSizeX = bounds.X end
        end
        ListSizeX = ListSizeX + 30

        -- Áp search filter hiện tại
        Dropdown:ApplySearchFilter()
        ScheduleRecalc()
    end

    function Dropdown:SetValues(NewValues)
        if NewValues then Dropdown.Values = NewValues end
        Dropdown:BuildDropdownList()
    end

    function Dropdown:OnChanged(Func)
        Dropdown.Changed = Func
        Func(Dropdown.Value)
    end

    function Dropdown:SetValue(Val)
        local oldValue = Dropdown.Value

        if Dropdown.Multi then
            local nTable = {}
            for Value in next, Val do
                if table.find(Dropdown.Values, Value) then
                    nTable[Value] = true
                end
            end
            Dropdown.Value = nTable
            -- Update tất cả button vì có thể nhiều cái thay đổi
            for _, Table in next, Dropdown.Buttons do
                Table:UpdateButton()
            end
        else
            if not Val then
                Dropdown.Value = nil
            elseif table.find(Dropdown.Values, Val) then
                Dropdown.Value = Val
            end
            -- [OPT] Chỉ update 2 button
            if oldValue and Dropdown._buttonByValue[oldValue] then
                Dropdown._buttonByValue[oldValue]:UpdateButton()
            end
            if Val and Dropdown._buttonByValue[Val] then
                Dropdown._buttonByValue[Val]:UpdateButton()
            end
        end

        Dropdown:Display()
        Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
        Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
    end

    function Dropdown:Destroy()
        DropdownFrame:Destroy()
        Library.Options[Idx] = nil
    end

    Dropdown:BuildDropdownList()

    local Defaults = {}
    if type(Config.Default) == "string" then
        local di = table.find(Dropdown.Values, Config.Default)
        if di then table.insert(Defaults, di) end
    elseif type(Config.Default) == "table" then
        for _, Value in next, Config.Default do
            local di = table.find(Dropdown.Values, Value)
            if di then table.insert(Defaults, di) end
        end
    elseif type(Config.Default) == "number" and Dropdown.Values[Config.Default] ~= nil then
        table.insert(Defaults, Config.Default)
    end

    if next(Defaults) then
        for i = 1, #Defaults do
            local Index = Defaults[i]
            if Config.Multi then
                Dropdown.Value[Dropdown.Values[Index]] = true
            else
                Dropdown.Value = Dropdown.Values[Index]
                break
            end
        end
        -- Update lại button đã chọn
        for _, Table in next, Dropdown.Buttons do
            Table:UpdateButton()
        end
        Dropdown:Display()
    end

    Library.Options[Idx] = Dropdown
    return Dropdown
end

return Element