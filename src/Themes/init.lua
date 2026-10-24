local Themes = {
    Names = {},
}

-- Duyệt qua tất cả các con của script
for _, Child in ipairs(script:GetChildren()) do
    -- 1. Chỉ xử lý nếu đó là ModuleScript (Dùng IsA trên Instance)
    if Child:IsA("ModuleScript") then
        -- 2. Dùng pcall để bắt lỗi nếu file theme bị lỗi cú pháp
        local success, result = pcall(require, Child)
        
        -- 3. Kiểm tra kết quả trả về có phải là table và có trường Name không
        if success and type(result) == "table" and result.Name then
            Themes[result.Name] = result
            table.insert(Themes.Names, result.Name)
        else
            warn("[Themes] Không thể tải theme: " .. Child.Name)
        end
    end
end

-- Sắp xếp danh sách tên cho gọn gàng
table.sort(Themes.Names)

return Themes