local Themes = {
    Names = {
        "Dark",
        "Darker",
        "Light",
        "Aqua",
        "Amethyst",
        "Rose",
        "Emerald",
    },
}

for _, Theme in next, script:GetChildren() do
    if Theme:IsA("ModuleScript") then
        Themes[Theme.Name] = require(Theme)
    end
end

return Themes
