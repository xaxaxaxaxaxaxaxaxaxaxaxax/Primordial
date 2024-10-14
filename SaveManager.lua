local httpService = game:GetService('HttpService')

local SaveManager = {} do
    SaveManager.Folder = 'Primordial'
    SaveManager.Ignore = {}
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object) 
                return { type = 'Toggle', idx = idx, value = object.Value } 
            end,
            Load = function(idx, data)
                if Flags[idx] then 
                    Flags[idx](data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = 'Slider', idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                if Flags[idx] then 
                    Flags[idx](tonumber(data.value))
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
            end,
            Load = function(idx, data)
                if Flags[idx] then 
                    Flags[idx]:Set(data.value)
                end
            end,
        },
        ColorPicker = {
            Save = function(idx, object)
                return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if Flags[idx] then 
                    Flags[idx]:Set(Color3.fromHex(data.value))
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, object)
                return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
            end,
            Load = function(idx, data)
                if Flags[idx] then 
                    Flags[idx]:Set({ data.key, data.mode })
                end
            end,
        },
    }
    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end
    function SaveManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree()
    end
    function SaveManager:Save(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        local fullPath = self.Folder .. '/configs/' .. name .. '.json'
        local data = {
            objects = {}
        }
        for idx, flag in next, Flags do
            if self.Ignore[idx] then continue end
            local flagInfo = Library.Flags[idx]
            if flagInfo then
                table.insert(data.objects, self.Parser[flagInfo.Type].Save(idx, flagInfo))
            end
        end	
        local success, encoded = pcall(httpService.JSONEncode, httpService, data)
        if not success then
            return false, 'failed to encode data'
        end
        writefile(fullPath, encoded)
        return true
    end
    function SaveManager:Load(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        local file = self.Folder .. '/configs/' .. name .. '.json'
        if not isfile(file) then return false, 'invalid file' end
        local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
        if not success then return false, 'decode error' end
        for _, option in next, decoded.objects do
            if self.Parser[option.type] then
                self.Parser[option.type].Load(option.idx, option)
            end
        end
        return true
    end
    function SaveManager:BuildFolderTree()
        local paths = {
            self.Folder,
            self.Folder .. '/configs'
        }
        for i = 1, #paths do
            local str = paths[i]
            if not isfolder(str) then
                makefolder(str)
            end
        end
    end
    function SaveManager:RefreshConfigList()
        local list = listfiles(self.Folder .. '/configs')
        local out = {}
        for i = 1, #list do
            local file = list[i]
            if file:sub(-5) == '.json' then
                local pos = file:find('.json', 1, true)
                local start = pos
                local char = file:sub(pos, pos)
                while char ~= '/' and char ~= '\\' and char ~= '' do
                    pos = pos - 1
                    char = file:sub(pos, pos)
                end
                if char == '/' or char == '\\' then
                    table.insert(out, file:sub(pos + 1, start - 1))
                end
            end
        end
        return out
    end
    function SaveManager:SetLibrary(library)
        self.Library = library
    end
    function SaveManager:LoadAutoloadConfig()
        if isfile(self.Folder .. '/configs/autoload.txt') then
            local name = readfile(self.Folder .. '/configs/autoload.txt')
            local success, err = self:Load(name)
            if not success then
                return self.Library:Notify('Failed to load autoload config: ' .. err, 3)
            end
            self.Library:Notify(string.format('Auto loaded config %q', name), 3)
        end
    end
    function SaveManager:BuildConfigSection(tab)
    assert(self.Library, 'Must set SaveManager.Library')

    local section = tab:Section({Name = "Configuration", Side = "Right"})

    section:Textbox({
        Name = "Config Name",
        Flag = "SaveManager_ConfigName",
        Default = "",
        Callback = function() end
    })

    local configList = section:List({
        Name = "Config List",
        Flag = "SaveManager_ConfigList",
        Options = self:RefreshConfigList(),
        Callback = function() end
    })

    section:Button({
        Name = "Create config", 
        Callback = function()
            local name = self.Library.Flags["SaveManager_ConfigName"]
            if name:gsub(' ', '') == '' then 
                return self.Library:Notify('Invalid config name (empty)', 3)
            end

            local success, err = self:Save(name)
            if not success then
                return self.Library:Notify('Failed to save config: ' .. err, 3)
            end

            self.Library:Notify(string.format('Created config %q', name), 3)
            configList:Refresh(self:RefreshConfigList())
        end
    })

    section:Button({
        Name = "Load config", 
        Callback = function()
            local name = self.Library.Flags["SaveManager_ConfigList"]
            local success, err = self:Load(name)
            if not success then
                return self.Library:Notify('Failed to load config: ' .. err, 3)
            end

            self.Library:Notify(string.format('Loaded config %q', name), 3)
        end
    })

    section:Button({
        Name = "Overwrite config", 
        Callback = function()
            local name = self.Library.Flags["SaveManager_ConfigList"]
            local success, err = self:Save(name)
            if not success then
                return self.Library:Notify('Failed to overwrite config: ' .. err, 3)
            end

            self.Library:Notify(string.format('Overwrote config %q', name), 3)
        end
    })

    section:Button({
        Name = "Refresh list", 
        Callback = function()
            configList:Refresh(self:RefreshConfigList())
        end
    })

    section:Button({
        Name = "Set as autoload", 
        Callback = function()
            local name = self.Library.Flags["SaveManager_ConfigList"]
            if name then
                self:SetAutoloadConfig(name)
                self.Library:Notify(string.format('Set %q to auto load', name), 3)
            end
        end
    })

    SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
    end
    SaveManager:BuildFolderTree()
end

SaveManager:SetFolder('Primordial')
SaveManager:SetLibrary(Library)
