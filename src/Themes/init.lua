local Themes = {
    Names = {
        "Dark",
        "Darker",
        "Deep Sapphire",
        "Light",
        "Aqua",
        "Amethyst",
        "Rose",
        "Emerald",
    },
}

-- Bundle (Main.lua) dùng virtual script KHÔNG hỗ trợ :IsA(),
-- nên duyệt theo danh sách Names thay vì GetChildren() + IsA()
for i = 1, #Themes.Names do
    local Name = Themes.Names[i]
    local Child = script:FindFirstChild(Name)

    if not Child then
        warn(("[Themes] Không tìm thấy module '%s' trong script"):format(Name))
        continue
    end

    local ok, ThemeModule = pcall(require, Child)
    if not ok then
        warn(("[Themes] Load '%s' thất bại: %s"):format(Name, tostring(ThemeModule)))
        continue
    end

    -- [VALIDATE] Bắt buộc có tối thiểu các field theme cần dùng
    if type(ThemeModule) ~= "table"
        or type(ThemeModule.Accent) ~= "Color3"
        or type(ThemeModule.Text) ~= "Color3"
        or type(ThemeModule.AcrylicMain) ~= "Color3"
    then
        warn(("[Themes] '%s' trả về dữ liệu không hợp lệ (thiếu Accent/Text/AcrylicMain)"):format(Name))
        continue
    end

    Themes[Name] = ThemeModule
end

-- [FALLBACK] Đảm bảo luôn có "Dark" để UI không vỡ nếu module lỗi
if not Themes.Dark then
    warn("[Themes] 'Dark' không load được — dùng palette mặc định fallback")
    Themes.Dark = {
        Name = "Dark",
        Accent = Color3.fromRGB(96, 205, 255),
        AcrylicMain = Color3.fromRGB(60, 60, 60),
        AcrylicBorder = Color3.fromRGB(90, 90, 90),
        AcrylicGradient = ColorSequence.new(Color3.fromRGB(40, 40, 40), Color3.fromRGB(40, 40, 40)),
        AcrylicNoise = 0.9,
        TitleBarLine = Color3.fromRGB(75, 75, 75),
        Tab = Color3.fromRGB(120, 120, 120),
        Element = Color3.fromRGB(120, 120, 120),
        ElementBorder = Color3.fromRGB(35, 35, 35),
        InElementBorder = Color3.fromRGB(90, 90, 90),
        ElementTransparency = 0.87,
        ToggleSlider = Color3.fromRGB(120, 120, 120),
        ToggleToggled = Color3.fromRGB(0, 0, 0),
        SliderRail = Color3.fromRGB(120, 120, 120),
        DropdownFrame = Color3.fromRGB(160, 160, 160),
        DropdownHolder = Color3.fromRGB(45, 45, 45),
        DropdownBorder = Color3.fromRGB(35, 35, 35),
        DropdownOption = Color3.fromRGB(120, 120, 120),
        Keybind = Color3.fromRGB(120, 120, 120),
        Input = Color3.fromRGB(160, 160, 160),
        InputFocused = Color3.fromRGB(10, 10, 10),
        InputIndicator = Color3.fromRGB(150, 150, 150),
        Dialog = Color3.fromRGB(45, 45, 45),
        DialogHolder = Color3.fromRGB(35, 35, 35),
        DialogHolderLine = Color3.fromRGB(30, 30, 30),
        DialogButton = Color3.fromRGB(45, 45, 45),
        DialogButtonBorder = Color3.fromRGB(80, 80, 80),
        DialogBorder = Color3.fromRGB(70, 70, 70),
        DialogInput = Color3.fromRGB(55, 55, 55),
        DialogInputLine = Color3.fromRGB(160, 160, 160),
        Text = Color3.fromRGB(240, 240, 240),
        SubText = Color3.fromRGB(170, 170, 170),
        Hover = Color3.fromRGB(120, 120, 120),
        HoverChange = 0.07,
    }
end

return Themes