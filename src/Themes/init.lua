local Themes = {}

-- Lặp qua children, chỉ require ModuleScript, có pcall + validate
for _, Child in ipairs(script:GetChildren()) do
        if not Child:IsA("ModuleScript") then
                continue
        end

        local ok, Result = pcall(require, Child)
        if not ok then
                warn(("[Themes] Lỗi load '%s': %s"):format(Child.Name, tostring(Result)))
                continue
        end

        if type(Result) ~= "table" or type(Result.Name) ~= "string" then
                warn(("[Themes] '%s' thiếu field Name hoặc không phải table"):format(Child.Name))
                continue
        end

        if Themes[Result.Name] then
                warn(("[Themes] Trùng tên theme: '%s' (file %s)"):format(Result.Name, Child.Name))
                continue
        end

        Themes[Result.Name] = Result
end

-- Tự build Names từ theme đã load thành công + sort alphabet
local Names = {}
for Name in next, Themes do
        table.insert(Names, Name)
end
table.sort(Names)
Themes.Names = Names

return Themes