local Themes = {
    Names = {},
}

-- Duyệt qua tất cả các con của script
for _, Theme in ipairs(script:GetChildren()) do
    -- 1. Chỉ xử lý nếu đó là ModuleScript (dùng IsA trên Instance)
    if Theme:IsA("ModuleScript") then
        -- 2. Dùng pcall để bắt lỗi nếu file theme bị lỗi cú pháp
        local success, result = pcall(require, Theme)
        
        if success and type(result) == "table" and result.Name then
            -- 3. Lưu theme vào bảng với key là tên của nó
            Themes[result.Name] = result
            table.insert(Themes.Names, result.Name)
        else
            warn("[Themes] Không thể tải theme: " .. Theme.Name)
        end
    end
end

-- Sắp xếp danh sách tên cho gọn gàng
table.sort(Themes.Names)

return Themes