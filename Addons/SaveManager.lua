local httpService = game:GetService("HttpService")

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	SaveManager.Version = 2 -- Schema version for migration support
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
				-- Store as number directly instead of tostring to preserve precision
				return { type = "Slider", idx = idx, value = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					local numValue = tonumber(data.value)
					if numValue then
						SaveManager.Options[idx]:SetValue(tostring(numValue))
					end
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = "Dropdown", idx = idx, value = object.Value, multi = object.Multi }
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

	-- ============================================================
	--  Utility: Validate config name (filesystem-safe, non-empty)
	-- ============================================================
	local INVALID_NAME_PATTERN = "[\\/:%*%?\"<>|]"

	function SaveManager:IsNameValid(name)
		if type(name) ~= "string" then
			return false, "config name must be text"
		end
		if name:gsub(" ", "") == "" then
			return false, "invalid config name (empty)"
		end
		if name:find(INVALID_NAME_PATTERN) then
			return false, "config name contains invalid characters"
		end
		if name == "options" or name == "autoload" then
			return false, "config name is reserved"
		end
		return true
	end

	-- ============================================================
	--  Utility: Validate that decoded JSON has expected structure
	-- ============================================================
	local function isValidConfigData(decoded)
		if type(decoded) ~= "table" then return false end
		if type(decoded.objects) ~= "table" then return false end
		return true
	end

	-- ============================================================
	--  Migrations: Upgrade old config schemas to current version
	-- ============================================================
	SaveManager.Migrations = {
		-- Migration from v1 (no version field) to v2
		[1] = function(data)
			-- v1 Slider values were stored as strings via tostring()
			-- Convert them to numbers for v2
			for _, obj in next, data.objects do
				if obj.type == "Slider" and type(obj.value) == "string" then
					obj.value = tonumber(obj.value) or 0
				end
			end
			return data
		end,
	}

	local function migrateConfig(data)
		local version = data.version or 1

		while version < SaveManager.Version do
			local migrator = SaveManager.Migrations[version]
			if migrator then
				data = migrator(data)
			end
			version = version + 1
		end

		data.version = SaveManager.Version
		return data
	end

	-- ============================================================
	--  Core API
	-- ============================================================

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:RemoveIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = nil
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	-- ----------------------------------------------------------
	--  Save: Validated name + atomic write with backup
	-- ----------------------------------------------------------
	function SaveManager:Save(name)
		local valid, err = self:IsNameValid(name)
		if not valid then
			return false, err
		end

		local fullPath = self.Folder .. "/settings/" .. name .. ".json"
		local tempPath = fullPath .. ".tmp"

		local data = {
			version = self.Version,
			objects = {}
		}

		for idx, option in next, SaveManager.Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "failed to encode data"
		end

		-- Step 1: Write to temp file first (atomic write pattern)
		local writeOk, writeErr = pcall(writefile, tempPath, encoded)
		if not writeOk then
			return false, "failed to write temp file: " .. tostring(writeErr)
		end

		-- Step 2: If original exists, create a backup before replacing
		if isfile(fullPath) then
			pcall(function()
				local existing = readfile(fullPath)
				writefile(fullPath .. ".bak", existing)
			end)
		end

		-- Step 3: Write the actual file
		local finalOk, finalErr = pcall(writefile, fullPath, encoded)
		if not finalOk then
			-- Attempt to restore from backup if write failed
			if isfile(fullPath .. ".bak") then
				pcall(function()
					local backup = readfile(fullPath .. ".bak")
					writefile(fullPath, backup)
				end)
			end
			pcall(delfile, tempPath)
			return false, "failed to write config: " .. tostring(finalErr)
		end

		-- Step 4: Clean up temp file
		pcall(delfile, tempPath)

		return true
	end

	-- ----------------------------------------------------------
	--  Load: Validate + migrate + safe per-option loading
	-- ----------------------------------------------------------
	function SaveManager:Load(name)
		if not name or name:gsub(" ", "") == "" then
			return false, "no config file is selected"
		end

		local file = self.Folder .. "/settings/" .. name .. ".json"
		if not isfile(file) then
			return false, "invalid file"
		end

		local readOk, raw = pcall(readfile, file)
		if not readOk then
			return false, "failed to read file"
		end

		local success, decoded = pcall(httpService.JSONDecode, httpService, raw)
		if not success then
			return false, "decode error"
		end

		if not isValidConfigData(decoded) then
			return false, "invalid data structure"
		end

		-- Migrate old config to current version
		decoded = migrateConfig(decoded)

		local loadErrors = {}
		local pending = 0

		for _, option in next, decoded.objects do
			if type(option) ~= "table" then continue end
			if not option.type or not option.idx then continue end
			if not self.Parser[option.type] then continue end

			pending = pending + 1
			task.spawn(function()
				local ok, err = pcall(self.Parser[option.type].Load, option.idx, option)
				if not ok then
					table.insert(loadErrors, string.format("%s (%s): %s", tostring(option.idx), tostring(option.type), tostring(err)))
				end
				pending = pending - 1
			end)
		end

		-- Give spawned loads a few frames to finish (bounded so it can't hang)
		local framesWaited = 0
		while pending > 0 and framesWaited < 10 do
			task.wait()
			framesWaited = framesWaited + 1
		end

		if #loadErrors > 0 then
			warn("[SaveManager] Partial load errors:", table.concat(loadErrors, "; "))
		end

		return true
	end

	-- ----------------------------------------------------------
	--  Delete: Remove a config file (and its backup/temp files)
	-- ----------------------------------------------------------
	function SaveManager:Delete(name)
		if not name or name:gsub(" ", "") == "" then
			return false, "no config file is selected"
		end

		local fullPath = self.Folder .. "/settings/" .. name .. ".json"
		if not isfile(fullPath) then
			return false, "config file does not exist"
		end

		local ok, err = pcall(delfile, fullPath)
		if not ok then
			return false, "failed to delete: " .. tostring(err)
		end

		if isfile(fullPath .. ".bak") then
			pcall(delfile, fullPath .. ".bak")
		end
		if isfile(fullPath .. ".tmp") then
			pcall(delfile, fullPath .. ".tmp")
		end

		return true
	end

	-- ----------------------------------------------------------
	--  ClearAutoload: Remove autoload setting
	-- ----------------------------------------------------------
	function SaveManager:ClearAutoload()
		local path = self.Folder .. "/settings/autoload.txt"
		if isfile(path) then
			pcall(delfile, path)
		end
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			"InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
		})
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

	-- ----------------------------------------------------------
	--  RefreshConfigList: Pattern-matched, ignores .bak/.tmp
	-- ----------------------------------------------------------
	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. "/settings")

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local name = file:match("([^/\\]+)%.json$")
				if name and name ~= "options" then
					table.insert(out, name)
				end
			end
		end

		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Options = library.Options
	end

	function SaveManager:LoadAutoloadConfig()
		local autoloadPath = self.Folder .. "/settings/autoload.txt"

		if not isfile(autoloadPath) then return end

		local readOk, name = pcall(readfile, autoloadPath)
		if not readOk or not name or name:gsub(" ", "") == "" then
			pcall(delfile, autoloadPath)
			return
		end

		local success, err = self:Load(name)
		if not success then
			-- If the config file was deleted but autoload.txt still references it,
			-- clean up autoload.txt automatically
			if err == "invalid file" then
				pcall(delfile, autoloadPath)
			end

			return self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = "Failed to load autoload config: " .. err,
				Duration = 7
			})
		end

		self.Library:Notify({
			Title = "Interface",
			Content = "Config loader",
			SubContent = string.format("Auto loaded config %q", name),
			Duration = 7
		})
	end

	-- ----------------------------------------------------------
	--  BuildConfigSection: Full UI with Delete & Clear Autoload
	-- ----------------------------------------------------------
	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Must set SaveManager.Library")

		local AutoloadButton -- declared up front so every callback can safely reference it

		local section = tab:AddSection("Configuration")

		section:AddInput("SaveManager_ConfigName", { Title = "Config name" })
		section:AddDropdown("SaveManager_ConfigList", { Title = "Config list", Values = self:RefreshConfigList(), AllowNull = true })

		local function notify(subContent)
			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = subContent,
				Duration = 7
			})
		end

		local function refreshDropdown()
			SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
		end

		section:AddButton({
			Title = "Create config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigName.Value

				local valid, err = self:IsNameValid(name)
				if not valid then
					return notify(err)
				end

				local success, saveErr = self:Save(name)
				if not success then
					return notify("Failed to save config: " .. saveErr)
				end

				notify(string.format("Created config %q", name))
				refreshDropdown()
			end
		})

		section:AddButton({
			Title = "Load config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value

				if not name then
					return notify("No config selected")
				end

				local success, err = self:Load(name)
				if not success then
					return notify("Failed to load config: " .. err)
				end

				notify(string.format("Loaded config %q", name))
			end
		})

		section:AddButton({
			Title = "Overwrite config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value

				if not name then
					return notify("No config selected")
				end

				local success, err = self:Save(name)
				if not success then
					return notify("Failed to overwrite config: " .. err)
				end

				notify(string.format("Overwrote config %q (backup saved)", name))
			end
		})

		section:AddButton({
			Title = "Delete config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value

				if not name then
					return notify("No config selected to delete")
				end

				local success, err = self:Delete(name)
				if not success then
					return notify("Failed to delete config: " .. err)
				end

				-- If the deleted config was the autoload, clean up autoload.txt
				local autoloadPath = self.Folder .. "/settings/autoload.txt"
				if isfile(autoloadPath) then
					local ok, current = pcall(readfile, autoloadPath)
					if ok and current == name then
						pcall(delfile, autoloadPath)
						AutoloadButton:SetDesc("Current autoload config: none")
					end
				end

				notify(string.format("Deleted config %q", name))
				refreshDropdown()
			end
		})

		section:AddButton({
			Title = "Refresh list",
			Callback = function()
				refreshDropdown()
			end
		})

		AutoloadButton = section:AddButton({
			Title = "Set as autoload",
			Description = "Current autoload config: none",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value

				if not name then
					return notify("No config selected for autoload")
				end

				local writeOk, writeErr = pcall(writefile, self.Folder .. "/settings/autoload.txt", name)
				if not writeOk then
					return notify("Failed to set autoload: " .. tostring(writeErr))
				end

				AutoloadButton:SetDesc("Current autoload config: " .. name)
				notify(string.format("Set %q to auto load", name))
			end
		})

		section:AddButton({
			Title = "Clear autoload",
			Callback = function()
				self:ClearAutoload()
				AutoloadButton:SetDesc("Current autoload config: none")
				notify("Cleared autoload config")
			end
		})

		-- Initialize autoload button description
		local autoloadPath = self.Folder .. "/settings/autoload.txt"
		if isfile(autoloadPath) then
			local ok, name = pcall(readfile, autoloadPath)
			if ok and name and name:gsub(" ", "") ~= "" then
				AutoloadButton:SetDesc("Current autoload config: " .. name)
			else
				pcall(delfile, autoloadPath)
			end
		end

		SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
