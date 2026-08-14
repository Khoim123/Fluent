-- src/Components/FloatingButton.lua
local Root = script.Parent.Parent
local Creator = require(Root.Creator)
local New = Creator.New
local UserInputService = game:GetService("UserInputService")

local FloatingButton = {}
FloatingButton.__index = FloatingButton

function FloatingButton.new(Config)
    local self = setmetatable({}, FloatingButton)
    self.TargetWindow = Config.Window -- Cửa sổ cần điều khiển
    self.Parent = Config.Parent or game:GetService("CoreGui") -- Hoặc PlayerGui

    -- Tạo nút
    self.Root = New("ImageButton", {
        Size = UDim2.fromOffset(50, 50),
        Position = UDim2.fromOffset(10, 100), -- Vị trí mặc định
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        Image = "rbxassetid://YOUR_ICON_ID", -- Thay bằng icon của bạn
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        Parent = self.Parent,
        AutoButtonColor = false,
        ClipsDescendants = true,
        ZIndex = 10, -- Luôn hiển thị trên cùng
    }, {
        New("UICorner", { CornerRadius = UDim.new(1, 0) }), -- Bo tròn hoàn toàn
        New("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.5 })
    })

    -- Xử lý sự kiện chạm để Toggle
    Creator.AddSignal(self.Root.MouseButton1Click, function()
        if self.TargetWindow then
            self.TargetWindow.Root.Visible = not self.TargetWindow.Root.Visible
        end
    end)

    -- Xử lý kéo thả cho mobile (Touch)
    self:_enableDragging()

    return self
end

-- Hàm xử lý kéo thả (Tham khảo từ Window.lua)
function FloatingButton:_enableDragging()
    local dragData = {
        dragging = false,
        startPos = nil,
        mousePos = nil,
        dragInput = nil
    }

    self.Root.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragData.dragging = true
            dragData.startPos = self.Root.Position
            dragData.mousePos = input.Position
        end
    end)

    self.Root.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragData.dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragData.dragInput and dragData.dragging then
            local delta = input.Position - dragData.mousePos
            self.Root.Position = UDim2.fromOffset(
                dragData.startPos.X.Offset + delta.X,
                dragData.startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragData.dragging = false
        end
    end)
end

return FloatingButton