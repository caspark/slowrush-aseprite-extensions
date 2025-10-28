-- Named Palette Plugin for Aseprite
local namedPaletteDialog = nil
local namedPaletteDialogBounds = false
local pluginPath = nil
local pluginPreferences = nil
local currentPalette = nil

------------------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------------------

-- Converts a hex color string (e.g., "ff00aa" or "#ff00aa") to an Aseprite Color object.
-- Returns nil if the hex string is invalid.
local function hexToColor(hex)
    if not hex then
        return nil
    end
    hex = hex:gsub("#", ""):lower()
    if #hex ~= 6 then
        return nil
    end
    if not hex:match("^[0-9a-f]+$") then
        return nil
    end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)

    if r and g and b then
        local created = Color {
            r = r,
            g = g,
            b = b,
            a = 255
        }
        return created
    else
        return nil
    end
end

------------------------------------------------------------------------
-- Palette Loading
------------------------------------------------------------------------

local function warnBadPaletteFile(errorMessage)
    local dialog = Dialog("Error loading palette")
    dialog:label{
        text = 'Failed to load named-palette.json:'
    }:newrow():label{
        text = errorMessage
    }:newrow():button{
        text = "Ok",
        onclick = function()
            dialog:close()
        end
    }
    dialog:show{
        wait = true,
        autoscrollbars = true
    }
end

-- Loads the palette from a specific file path.
-- Returns a Lua table containing the palette entries or nil if there is an error.
local function loadPaletteFromFile(paletteFilePath, quiet)
    if not app.fs.isFile(paletteFilePath) then
        if not quiet then
            warnBadPaletteFile("File not found: " .. paletteFilePath)
        end
        return nil
    end

    local file, err = io.open(paletteFilePath, "r")
    if not file then
        if not quiet then
            warnBadPaletteFile("Could not open file: " .. (err or "unknown error"))
        end
        return nil
    end

    local jsonString = file:read("*all")
    file:close()

    if not jsonString or #jsonString == 0 then
        if not quiet then
            warnBadPaletteFile("File is empty")
        end
        return nil
    end

    local success, decodedData = pcall(json.decode, jsonString)
    if not success then
        if not quiet then
            warnBadPaletteFile("Invalid JSON: " .. tostring(decodedData))
        end
        return nil
    end

    local paletteEntries = decodedData['palette'] or {}

    local parsed_palette = {}
    for i, entry in ipairs(paletteEntries) do
        local parsed_color = hexToColor(entry.color)
        if parsed_color then
            table.insert(parsed_palette, {
                name = entry.name,
                color = parsed_color
            })
        else
            if not quiet then
                warnBadPaletteFile('Failed to parse palette entry "' .. entry.name .. '" color: ' .. entry.color ..
                                  ' (expected hex like ffaa00)')
            end
            return nil
        end
    end

    return parsed_palette
end

-- Loads the palette from the remembered file path, or falls back to the default in the plugin directory.
-- Returns a Lua table containing the palette entries or nil if there is an error.
local function loadPalette(quiet)
    local paletteFilePath = nil

    -- Try to load from preferences first
    if pluginPreferences and pluginPreferences.paletteFilePath then
        paletteFilePath = pluginPreferences.paletteFilePath
    elseif pluginPath then
        -- Fall back to default location
        paletteFilePath = app.fs.joinPath(pluginPath, "named-palette.json")
    else
        if not quiet then
            warnBadPaletteFile("Plugin path not initialized")
        end
        return nil
    end

    return loadPaletteFromFile(paletteFilePath, quiet)
end

------------------------------------------------------------------------
-- Dialog Management
------------------------------------------------------------------------

-- Forward declarations
local openNamedPaletteDialog

-- Closes the named palette dialog, setting the global namedPaletteDialog to nil.
local function closeNamedPaletteDialog()
    if namedPaletteDialog then
        namedPaletteDialogBounds = namedPaletteDialog.bounds
        namedPaletteDialog:close()
        namedPaletteDialog = nil
    end
end

-- Loads a new palette file and updates the dialog
local function loadNewPaletteFile()
    local loadDialog = Dialog {
        title = "Load Palette File"
    }

    local defaultPath = pluginPath
    if pluginPreferences and pluginPreferences.paletteFilePath then
        defaultPath = app.fs.filePath(pluginPreferences.paletteFilePath)
    end

    loadDialog:file{
        id = "palette_file",
        label = "Palette File:",
        open = true,
        filename = "",
        filetypes = {"json"},
        basepath = defaultPath
    }:button{
        text = "Load",
        onclick = function()
            local selectedFile = loadDialog.data.palette_file
            if selectedFile and #selectedFile > 0 then
                local newPalette = loadPaletteFromFile(selectedFile, false)
                if newPalette then
                    pluginPreferences.paletteFilePath = selectedFile
                    currentPalette = newPalette
                    loadDialog:close()
                    closeNamedPaletteDialog()
                    openNamedPaletteDialog()
                end
            else
                app.alert("Please select a file")
            end
        end
    }:button{
        text = "Cancel",
        onclick = function()
            loadDialog:close()
        end
    }

    loadDialog:show{
        wait = true
    }
end

-- Creates and shows the named palette dialog.
openNamedPaletteDialog = function()
    if namedPaletteDialog then
        return nil
    end

    namedPaletteDialog = Dialog {
        title = "Named Palette",
        onclose = function()
            namedPaletteDialog = nil
        end
    }

    if not currentPalette then
        currentPalette = loadPalette(true)
    end

    if not currentPalette or #currentPalette == 0 then
        namedPaletteDialog:label{
            text = "No palette loaded."
        }:newrow():button{
            text = "Load Palette",
            onclick = function()
                loadNewPaletteFile()
            end
        }:button{
            text = "Close",
            onclick = function()
                closeNamedPaletteDialog()
            end
        }
    else
        for paletteIndex, entry in ipairs(currentPalette) do
            namedPaletteDialog:shades{
                label = entry.name,
                colors = {entry.color},
                onclick = function(ev)
                    if ev.button == MouseButton.LEFT then
                        app.fgColor = ev.color
                    elseif ev.button == MouseButton.RIGHT then
                        app.bgColor = ev.color
                    end
                end
            }:newrow()
        end

        namedPaletteDialog:button{
            text = "Load Palette",
            onclick = function()
                loadNewPaletteFile()
            end
        }
    end

    -- Show as a non-modal dialog
    namedPaletteDialog:show{
        bounds = namedPaletteDialogBounds,
        wait = false
    }
end

------------------------------------------------------------------------
-- Plugin Lifecycle Callbacks (init, exit)
------------------------------------------------------------------------

function init(plugin)
    pluginPath = plugin.path
    pluginPreferences = plugin.preferences

    plugin:newCommand{
        id = "named_palette",
        title = "Named Palette",
        group = "view_controls",
        onclick = openNamedPaletteDialog
    }

    if not namedPaletteDialogBounds then
        namedPaletteDialogBounds = Rectangle {
            x = 600,
            y = 0,
            w = 100,
            h = 150
        }
    end

    -- Load palette on startup if we have a saved path
    if pluginPreferences.paletteFilePath then
        currentPalette = loadPalette(true)
    end
end

function exit(plugin)
    if namedPaletteDialog then
        namedPaletteDialog:close()
    end
    namedPaletteDialog = nil
end
