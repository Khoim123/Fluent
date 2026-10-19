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

for _, Theme in next, script:GetChildren() do
        local Required = require(Theme)
        Themes[Required.Name] = Required
end

return Themes