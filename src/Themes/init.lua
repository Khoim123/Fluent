local Themes = {
	Names = {
		"Dark",
		"Darker",
		"Light",
		"Aqua",
		"Amethyst",
		"Rose",
		"Crimson",
		"Cyberpunk",
		"Deep Sapphire",
		"Emerald",
		"Monokai",
		"Nord",
	},
}

for _, Theme in next, script:GetChildren() do
	local Required = require(Theme)
	Themes[Required.Name] = Required
end

return Themes
