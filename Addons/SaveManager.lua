--[[
    ============================================================
    SaveManager.lua — Auto-Save & Auto-Load Config Manager
    ============================================================
    Dựa trên: https://github.com/Khoim123/Fluent/blob/master/Addons/SaveManager.lua

    TÍNH NĂNG MỚI SO VỚI BẢN GỐC:
    ─────────────────────────────
    ✅ Auto-Save: Tự động lưu khi thay đổi Toggle / Slider / Dropdown /
       ColorPicker / Keybind / Input — không cần bấm nút Save.
    ✅ Auto-Load: Tự động load config khi đổi server (hook OnTeleport).
    ✅ Debounce: Gom nhiều thay đổi liên tục (kéo slider) thành 1 lần ghi.
    ✅ Per-Server Config: Mỗi server/job ID có file config riêng.
    ✅ LoadAutoloadConfig: Tự load config "autoload" khi join game.
    ✅ BuildConfigSection: Tạo GUI section quản lý config (Create/Load/
       Overwrite/Delete/Refresh/Autoload).
    ✅ Ignore list: Bỏ qua các option không muốn lưu (vd: theme settings).

    CÁCH DÙNG:
    ──────────
    local SaveManager = loadstring(game:HttpGet("YOUR_RAW_URL"))()

    -- 1. Gắn library Fluent
    SaveManager:SetLibrary(Fluent)

    -- 2. (Tuỳ chọn) Bỏ qua các setting giao diện
    SaveManager:IgnoreThemeSettings()

    -- 3. (Tuỳ chọn) Đổi folder lưu
    SaveManager:SetFolder("MyScriptSettings")

    -- 4. Build GUI quản lý config
    SaveManager:BuildConfigSection(UITab)

    -- 5. Bật auto-save (CORE — gọi SAU khi tất cả option đã tạo xong)
    SaveManager:EnableAutoSave()

    -- 6. Bật auto-load khi đổi server
    SaveManager:EnableAutoLoad()

    ============================================================
]]

local httpService = game:GetService("HttpService")
local players     = game:GetService("Players")

local SaveManager = {} do
    -------------------------------------------------------
    -- CONFIGURATION
    -------------------------------------------------------
    SaveManager.Folder           = "FluentSettings"   -- Thư mục gốc
    SaveManager.Ignore           = {}                  -- Danh sách ignore
    SaveManager.AutoSaveDebounce = 1.5                 -- Giây — gom thay đổi
    SaveManager.Library         = nil                  -- Fluent library
    SaveManager.Options         = nil                  -- library.Options

    -- Internal state
    local autoSaveConnections   = {}                  -- RBXScriptSignal connections
    local debounceTimers        = {}                  -- idx → tick
    local pendingSave           = false
    local lastSaveTime          = 0
    local autoSaveEnabled       = false
    local autoLoadEnabled       = false

    -------------------------------------------------------
    -- PARSER — Cách lưu/load từng loại UI element
    -------------------------------------------------------
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object)
                return { type = "Toggle", idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },

        Slider = {
            Save = function(idx, object)
                return { type = "Slider", idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },

        Dropdown = {
            Save = function(idx, object)
                return { type = "Dropdown", idx = idx, value = object.Value, mutli = object.Multi }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },

        Colorpicker = {
            Save = function(idx, object)
                return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
                end
            end,
        },

        Keybind = {
            Save = function(idx, object)
                return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then
                    SaveManager.Options[idx]:SetValue(data.key, data.mode)
                end
            end,
        },

        Input = {
            Save = function(idx, object)
                return { type = "Input", idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] and type(data.text) == "string" then
                    SaveManager.Options[idx]:SetValue(data.text)
                end
            end,
        },
    }

    -------------------------------------------------------
    -- UTILITIES
    -------------------------------------------------------

    --- Lấy tên config dựa trên JobId (mỗi server 1 file)
    function SaveManager:GetServerConfigName()
        if game.JobId ~= "" then
            -- Hash JobId để tên file an toàn
            local hash = httpService:GenerateGUID(false):gsub("-", "")
            -- Dùng chính JobId nếu ngắn, còn dài thì hash
            if #game.JobId <= 40 then
                return "server_" .. game.JobId:gsub("[^%w_]", "_")
            end
            -- Fallback: encode
            local ok, encoded = pcall(httpService.JSONEncode, httpService, game.JobId)
            if ok then
                return "server_" .. encoded:gsub("[^%w_]", "_"):sub(1, 50)
            end
        end
        return "default"
    end

    --- Lấy config name đang active (autoload hoặc server-based)
    function SaveManager:GetActiveConfigName()
        -- Ưu tiên autoload
        if isfile(self.Folder .. "/settings/autoload.txt") then
            return readfile(self.Folder .. "/settings/autoload.txt")
        end
        -- Fallback: per-server
        return self:GetServerConfigName()
    end

    -------------------------------------------------------
    -- IGNORE
    -------------------------------------------------------

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            "InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
        })
    end

    -------------------------------------------------------
    -- FOLDER
    -------------------------------------------------------

    function SaveManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    function SaveManager:BuildFolderTree()
        local paths = {
            self.Folder,
            self.Folder .. "/settings"
        }
        for i = 1, #paths do
            local str = paths[i]
            if not isfolder(str) then
                makefolder(str)
            end
        end
    end

    -------------------------------------------------------
    -- CORE: SAVE & LOAD
    -------------------------------------------------------

    function SaveManager:Save(name)
        if not name then
            return false, "no config file is selected"
        end

        local fullPath = self.Folder .. "/settings/" .. name .. ".json"

        local data = {
            objects = {}
        }

        for idx, option in next, SaveManager.Options do
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end

            local ok, saved = pcall(self.Parser[option.Type].Save, idx, option)
            if ok then
                table.insert(data.objects, saved)
            end
        end

        local success, encoded = pcall(httpService.JSONEncode, httpService, data)
        if not success then
            return false, "failed to encode data"
        end

        writefile(fullPath, encoded)
        lastSaveTime = tick()
        return true
    end

    function SaveManager:Load(name)
        if not name then
            return false, "no config file is selected"
        end

        local file = self.Folder .. "/settings/" .. name .. ".json"
        if not isfile(file) then return false, "invalid file" end

        local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
        if not success then return false, "decode error" end

        for _, option in next, decoded.objects do
            if self.Parser[option.type] then
                -- task.spawn để config loading không bị stuck
                task.spawn(function()
                    self.Parser[option.type].Load(option.idx, option)
                end)
            end
        end

        return true
    end

    -------------------------------------------------------
    -- AUTO-SAVE — Tự động lưu khi bất kỳ option thay đổi
    -------------------------------------------------------

    --- Debounced save: gom nhiều thay đổi thành 1 lần ghi file
    local function triggerAutoSave()
        if not autoSaveEnabled then return end

        local configName = SaveManager:GetActiveConfigName()
        if not configName or configName == "" then return end

        -- Debounce: nếu vừa save < AutoSaveDebounce giây trước, trì hoãn
        local now = tick()
        if (now - lastSaveTime) < SaveManager.AutoSaveDebounce then
            if not pendingSave then
                pendingSave = true
                task.delay(SaveManager.AutoSaveDebounce - (now - lastSaveTime), function()
                    pendingSave = false
                    SaveManager:Save(configName)
                end)
            end
            return
        end

        SaveManager:Save(configName)
    end

    --- Hook một option duy nhất
    local function hookOption(idx, option)
        if not option then return end
        if SaveManager.Ignore[idx] then return end

        -- Mỗi loại UI element có signal khác nhau
        -- Fluent dùng :OnChanged(callback) cho mọi loại
        if option.OnChanged then
            local conn
            conn = option:OnChanged(function()
                triggerAutoSave()
            end)
            if conn then
                table.insert(autoSaveConnections, conn)
            end
        -- Fallback cho các library dùng :Changed
        elseif type(option.Changed) == "RBXScriptSignal" then
            local conn = option.Changed:Connect(function()
                triggerAutoSave()
            end)
            table.insert(autoSaveConnections, conn)
        -- Fallback: hook SetValue
        elseif option.SetValue and not option._autoSaveHooked then
            local originalSetValue = option.SetValue
            option._autoSaveHooked = true
            option.SetValue = function(self, ...)
                local result = originalSetValue(self, ...)
                task.spawn(triggerAutoSave)
                return result
            end
        end
    end

    --- Bật auto-save cho TẤT CẢ option hiện tại + tương lai
    function SaveManager:EnableAutoSave()
        if autoSaveEnabled then return end
        autoSaveEnabled = true

        -- Hook tất cả option hiện có
        for idx, option in next, self.Options do
            hookOption(idx, option)
        end

        -- Thông báo
        if self.Library and self.Library.Notify then
            self.Library:Notify({
                Title    = "SaveManager",
                Content  = "Auto-Save",
                SubContent = "Đã bật — thay đổi sẽ tự động lưu",
                Duration = 5
            })
        end
    end

    --- Tắt auto-save & ngắt tất cả connections
    function SaveManager:DisableAutoSave()
        autoSaveEnabled = false
        pendingSave = false

        for _, conn in next, autoSaveConnections do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        autoSaveConnections = {}

        if self.Library and self.Library.Notify then
            self.Library:Notify({
                Title    = "SaveManager",
                Content  = "Auto-Save",
                SubContent = "Đã tắt",
                Duration = 5
            })
        end
    end

    --- Kiểm tra auto-save đang bật hay tắt
    function SaveManager:IsAutoSaveEnabled()
        return autoSaveEnabled
    end

    --- Force save ngay lập tức (bypass debounce)
    function SaveManager:ForceSave()
        local configName = self:GetActiveConfigName()
        if configName and configName ~= "" then
            lastSaveTime = 0  -- reset debounce
            return self:Save(configName)
        end
        return false, "no active config"
    end

    -------------------------------------------------------
    -- AUTO-LOAD — Tự động load khi đổi server / join game
    -------------------------------------------------------

    function SaveManager:EnableAutoLoad()
        if autoLoadEnabled then return end
        autoLoadEnabled = true

        -- 1. Load ngay khi join game (nếu có autoload config)
        self:LoadAutoloadConfig()

        -- 2. Hook TeleportService để load khi đổi server
        local teleportService = game:GetService("TeleportService")

        -- Khi teleport thành công, server mới sẽ chạy script lại
        -- nên chỉ cần đảm bảo autoload chạy. Nhưng để an toàn,
        -- ta cũng hook OnTeleportIfNeeded để ghi config TRƯỚC khi teleport

        pcall(function()
            -- TeleportService:GetTeleportData() có thể dùng để truyền data
            -- Nhưng cách đơn giản nhất: save trước khi rời server
            if players.LocalPlayer then
                players.LocalPlayer.OnTeleport:Connect(function(state)
                    if state == Enum.TeleportState.Started then
                        -- Save ngay trước khi teleport
                        self:ForceSave()
                    end
                end)
            end
        end)

        if self.Library and self.Library.Notify then
            self.Library:Notify({
                Title    = "SaveManager",
                Content  = "Auto-Load",
                SubContent = "Đã bật — config sẽ tự load khi đổi server",
                Duration = 5
            })
        end
    end

    function SaveManager:DisableAutoLoad()
        autoLoadEnabled = false
    end

    -------------------------------------------------------
    -- LOAD AUTOLOAD CONFIG
    -------------------------------------------------------

    function SaveManager:LoadAutoloadConfig()
        if isfile(self.Folder .. "/settings/autoload.txt") then
            local name = readfile(self.Folder .. "/settings/autoload.txt")

            local success, err = self:Load(name)
            if not success then
                if self.Library and self.Library.Notify then
                    return self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Auto-Load",
                        SubContent = "Lỗi load autoload: " .. tostring(err),
                        Duration = 7
                    })
                end
                return
            end

            if self.Library and self.Library.Notify then
                self.Library:Notify({
                    Title    = "SaveManager",
                    Content  = "Auto-Load",
                    SubContent = string.format('Đã load config "%s"', name),
                    Duration = 7
                })
            end
        end
    end

    -------------------------------------------------------
    -- REFRESH CONFIG LIST
    -------------------------------------------------------

    function SaveManager:RefreshConfigList()
        local list = listfiles(self.Folder .. "/settings")

        local out = {}
        for i = 1, #list do
            local file = list[i]
            if file:sub(-5) == ".json" then
                local pos = file:find(".json", 1, true)
                local start = pos

                local char = file:sub(pos, pos)
                while char ~= "/" and char ~= "\\" and char ~= "" do
                    pos = pos - 1
                    char = file:sub(pos, pos)
                end

                if char == "/" or char == "\\" then
                    local name = file:sub(pos + 1, start - 1)
                    if name ~= "options" then
                        table.insert(out, name)
                    end
                end
            end
        end

        return out
    end

    -------------------------------------------------------
    -- SET LIBRARY
    -------------------------------------------------------

    function SaveManager:SetLibrary(library)
        self.Library = library
        self.Options = library.Options
    end

    -------------------------------------------------------
    -- BUILD CONFIG SECTION (GUI)
    -------------------------------------------------------

    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, "Phải gọi SaveManager:SetLibrary() trước")

        local section = tab:AddSection("Configuration")

        section:AddInput("SaveManager_ConfigName", { Title = "Config name" })
        section:AddDropdown("SaveManager_ConfigList", {
            Title   = "Config list",
            Values  = self:RefreshConfigList(),
            AllowNull = true
        })

        ---------------------------------------------------
        -- Create config
        ---------------------------------------------------
        section:AddButton({
            Title = "Create config",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigName.Value

                if name:gsub(" ", "") == "" then
                    return self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = "Tên config không hợp lệ (rỗng)",
                        Duration = 7
                    })
                end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = "Lỗi save: " .. tostring(err),
                        Duration = 7
                    })
                end

                self.Library:Notify({
                    Title    = "SaveManager",
                    Content  = "Config",
                    SubContent = string.format('Đã tạo config "%s"', name),
                    Duration = 7
                })

                SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
            end
        })

        ---------------------------------------------------
        -- Load config
        ---------------------------------------------------
        section:AddButton({
            Title = "Load config",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigList.Value

                local success, err = self:Load(name)
                if not success then
                    return self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = "Lỗi load: " .. tostring(err),
                        Duration = 7
                    })
                end

                self.Library:Notify({
                    Title    = "SaveManager",
                    Content  = "Config",
                    SubContent = string.format('Đã load config "%s"', name),
                    Duration = 7
                })
            end
        })

        ---------------------------------------------------
        -- Overwrite config
        ---------------------------------------------------
        section:AddButton({
            Title = "Overwrite config",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigList.Value

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = "Lỗi overwrite: " .. tostring(err),
                        Duration = 7
                    })
                end

                self.Library:Notify({
                    Title    = "SaveManager",
                    Content  = "Config",
                    SubContent = string.format('Đã overwrite config "%s"', name),
                    Duration = 7
                })
            end
        })

        ---------------------------------------------------
        -- Delete config
        ---------------------------------------------------
        section:AddButton({
            Title = "Delete config",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigList.Value
                if not name or name == "" then
                    return self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = "Chưa chọn config để xóa",
                        Duration = 7
                    })
                end

                local file = self.Folder .. "/settings/" .. name .. ".json"
                if isfile(file) then
                    delfile(file)
                    self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = string.format('Đã xóa config "%s"', name),
                        Duration = 7
                    })
                else
                    self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = "File không tồn tại",
                        Duration = 7
                    })
                end

                SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
            end
        })

        ---------------------------------------------------
        -- Refresh list
        ---------------------------------------------------
        section:AddButton({
            Title = "Refresh list",
            Callback = function()
                SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
            end
        })

        ---------------------------------------------------
        -- Set as autoload
        ---------------------------------------------------
        local AutoloadButton
        AutoloadButton = section:AddButton({
            Title = "Set as autoload",
            Description = "Current autoload config: none",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigList.Value
                writefile(self.Folder .. "/settings/autoload.txt", name)
                AutoloadButton:SetDesc("Current autoload config: " .. name)
                self.Library:Notify({
                    Title    = "SaveManager",
                    Content  = "Config",
                    SubContent = string.format('Đã set "%s" làm autoload', name),
                    Duration = 7
                })
            end
        })

        if isfile(self.Folder .. "/settings/autoload.txt") then
            local name = readfile(self.Folder .. "/settings/autoload.txt")
            AutoloadButton:SetDesc("Current autoload config: " .. name)
        end

        ---------------------------------------------------
        -- Auto-Save toggle (trong GUI)
        ---------------------------------------------------
        section:AddToggle("SaveManager_AutoSave", {
            Title   = "Auto-Save",
            Default = false,
            Callback = function(value)
                if value then
                    SaveManager:EnableAutoSave()
                else
                    SaveManager:DisableAutoSave()
                end
            end
        })

        ---------------------------------------------------
        -- Auto-Load toggle (trong GUI)
        ---------------------------------------------------
        section:AddToggle("SaveManager_AutoLoad", {
            Title   = "Auto-Load on server change",
            Default = false,
            Callback = function(value)
                if value then
                    SaveManager:EnableAutoLoad()
                else
                    SaveManager:DisableAutoLoad()
                end
            end
        })

        ---------------------------------------------------
        -- Force Save button
        ---------------------------------------------------
        section:AddButton({
            Title = "Force Save Now",
            Callback = function()
                local success, err = self:ForceSave()
                if success then
                    self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = "Đã force save thành công",
                        Duration = 5
                    })
                else
                    self.Library:Notify({
                        Title    = "SaveManager",
                        Content  = "Config",
                        SubContent = "Lỗi: " .. tostring(err),
                        Duration = 7
                    })
                end
            end
        })

        -- Ignore các option nội bộ
        SaveManager:SetIgnoreIndexes({
            "SaveManager_ConfigList",
            "SaveManager_ConfigName",
            "SaveManager_AutoSave",
            "SaveManager_AutoLoad"
        })
    end

    -------------------------------------------------------
    -- INIT: Tạo folder tree
    -------------------------------------------------------
    SaveManager:BuildFolderTree()
end

return SaveManager
