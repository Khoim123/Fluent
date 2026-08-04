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

-- [FIX] Bản bundle (Main.lua) dùng virtual script KHÔNG hỗ trợ :IsA(),
-- nên duyệt theo danh sách Names thay vì GetChildren() + IsA()
for _, Name in next, Themes.Names do
	local ok, ThemeModule = pcall(function()
		return require(script[Name])
	end)
	if ok then
		Themes[Name] = ThemeModule
	end
end

return Themes
