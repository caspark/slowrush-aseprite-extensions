-- Hotspot Manager Plugin for Aseprite
-- Global references to keep track of state
local hotspotPaletteDialog = nil
local hotspotPaletteSprite = nil
local hotspotPaletteDialogBounds = false
local hotspotSiteChangeListener = nil

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
        return nil -- Should not happen with validation, but safe practice
    end
end

-- Converts an Aseprite Color object to a lowercase hex string without '#'.
local function colorToHex(color)
    if not color then
        return "ffffff"
    end -- Default to white if color is nil
    return string.format("%02x%02x%02x", color.red, color.green, color.blue)
end

------------------------------------------------------------------------
-- Dialog Management
------------------------------------------------------------------------

local function warnBadUserdata(userdata)
    local dialog = Dialog("Error parsing userdata")
    dialog:label{
        text = 'The userdata for this sprite is not valid JSON:'
    }:newrow():label{
        text = userdata
    }:newrow():label{
        text = 'Please correct or clear the sprite\'s userdata and try again.'
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

-- Loads the hotspots from the active sprite's userdata.
-- Returns a Lua table containing the hotspots or nil if there is an error.
local function loadHotspots(quiet)
    local sprite = app.sprite
    if not sprite then
        -- no active sprite so nothing to do
        return {}
    end

    local jsonString = sprite.data
    if not jsonString or #jsonString == 0 then
        -- no userdata so we know there are no hotspots
        return {}
    end

    local success, decodedData = pcall(json.decode, jsonString)
    if not success then
        if not quiet then
            warnBadUserdata(jsonString)
        end
        return nil
    end

    local hotspots = decodedData['hotspots'] or {}

    --- it seems we can't mutate the table returned from json.decode so have to create a new table
    local parsed_hotspots = {}
    for i, hotspot in ipairs(hotspots) do
        local parsed_color = hexToColor(hotspot.color)
        if parsed_color then
            table.insert(parsed_hotspots, {
                name = hotspot.name,
                color = parsed_color
            })
        else
            error('Failed to parse hotspot "' .. hotspot.name .. '" color: ' .. hotspot.color ..
                      ' (expected hex like ffaa00)')
        end
    end

    return parsed_hotspots
end

-- Saves the provided Lua table of hotspots to the active sprite's userdata.
-- Always returns nil, but pops a dialog if there is an error.
local function saveHotspots(hotspots)
    -- iterate through hotspots and convert the color to a hex string
    for i, hotspot in ipairs(hotspots) do
        hotspot.color = colorToHex(hotspot.color)
    end

    local sprite = app.sprite
    if not sprite then
        -- no active sprite so nothing to do
        return
    end

    local jsonString = sprite.data
    if not jsonString or #jsonString == 0 then
        jsonString = "{}"
    end

    local success, decodedData = pcall(json.decode, jsonString)
    if not success then
        warnBadUserdata(jsonString)
        return
    end

    decodedData['hotspots'] = hotspots

    local jsonString = json.encode(decodedData)
    sprite.data = jsonString
end

local function editHotspotPalette()
    local editHotspotsDialog = Dialog {
        title = "Edit Hotspot Palette"
    }

    local hotspots = loadHotspots(false)
    for i = 1, 10 do
        local hotspot = hotspots[i] or {
            name = "",
            color = Color {
                r = 255,
                g = 255,
                b = 255,
                a = 255
            }
        }
        editHotspotsDialog:entry{
            id = "hotspot_" .. i .. "_name",
            label = "Hotspot " .. i,
            text = hotspot.name
        }:color{
            id = "hotspot_" .. i .. "_color",
            color = hotspot.color
        }
    end

    editHotspotsDialog:button{
        text = "Defaults",
        onclick = function()
            local hotspots = {{
                name = "eye",
                color = Color {
                    -- cyan
                    r = 0,
                    g = 255,
                    b = 255
                }
            }, {
                name = "attack",
                color = Color {
                    -- pink
                    r = 255,
                    g = 0,
                    b = 255
                }
            }, {
                name = "collider",
                color = Color {
                    -- yellow
                    r = 255,
                    g = 255,
                    b = 0
                }
            }, {
                name = "pivot",
                color = Color {
                    -- green
                    r = 0,
                    g = 255,
                    b = 0
                }
            }, {
                name = "left",
                color = Color {
                    -- orange
                    r = 255,
                    g = 165,
                    b = 0
                }
            }, {
                name = "right",
                color = Color {
                    -- purple
                    r = 128,
                    g = 0,
                    b = 128
                }
            }}
            saveHotspots(hotspots)

            if app.sprite then
                local hotspotLayer = nil
                for i, layer in ipairs(app.sprite.layers) do
                    if layer.name == "hotspots" then
                        hotspotLayer = layer
                    end
                end

                if hotspotLayer == nil then
                    hotspotLayer = app.sprite:newLayer()
                    hotspotLayer.name = "hotspots"
                end
            end

            editHotspotsDialog:close()
            editHotspotPalette()
        end
    }:button{
        text = "Save",
        onclick = function()
            local hotspots = {}
            for i = 1, 10 do
                local hotspot_name = editHotspotsDialog.data["hotspot_" .. i .. "_name"]
                local hotspot_color = editHotspotsDialog.data["hotspot_" .. i .. "_color"]
                if #hotspot_name > 0 then
                    table.insert(hotspots, {
                        name = hotspot_name,
                        color = hotspot_color
                    })
                end
            end
            saveHotspots(hotspots)
            editHotspotsDialog:close()
        end
    }

    editHotspotsDialog:show{
        wait = true
    }
end

-- Closes the hotspot manager dialog, setting the global hotspotDialog to nil.
local function closeHotspotPaletteDialog()
    if hotspotPaletteDialog then
        hotspotPaletteDialogBounds = hotspotPaletteDialog.bounds
        hotspotPaletteDialog:close()
        hotspotPaletteDialog = nil
    end
end

-- Creates and shows the main hotspot management dialog, assigning it to the global hotspotDialog
-- variable.
local function openHotspotPaletteDialog()
    if hotspotPaletteDialog then
        return nil
    end

    hotspotPaletteDialog = Dialog {
        title = "Hotspots",
        onclose = function()
            hotspotPaletteDialog = nil
            focus = false
        end
    }

    if app.sprite then
        local hotspots = loadHotspots(false)
        for hotspotIndex, hotspot in ipairs(hotspots) do
            hotspotPaletteDialog:shades{
                label = hotspot.name,
                colors = {hotspot.color},
                onclick = function(ev)
                    if ev.button == MouseButton.LEFT then
                        app.fgColor = ev.color
                    elseif ev.button == MouseButton.RIGHT then
                        app.bgColor = ev.color
                    end
                end
            }:newrow()
        end

        hotspotPaletteDialog:button{
            text = "Edit",
            onclick = function()
                closeHotspotPaletteDialog()
                editHotspotPalette()
                openHotspotPaletteDialog()
            end
        }
    else
        -- no sprite so nothing to do
        hotspotPaletteDialog:label{
            text = "No sprite open. Open a sprite to manage its hotspots."
        }
        return
    end

    -- Show as a non-modal dialog
    hotspotPaletteDialog:show{
        bounds = hotspotPaletteDialogBounds,
        wait = false
    }

end

------------------------------------------------------------------------
-- Plugin Lifecycle Callbacks (init, exit)
------------------------------------------------------------------------

function init(plugin)
    plugin:newCommand{
        id = "hotspot_palette",
        title = "Hotspot Palette",
        group = "sprite_properties",
        onclick = openHotspotPaletteDialog
    }

    if not hotspotPaletteDialogBounds then
        hotspotPaletteDialogBounds = Rectangle {
            x = 600,
            y = 0,
            w = 100,
            h = 150
        }
    end

    -- Listen for site changes to update the dialog if the sprite changes
    hotspotSiteChangeListener = app.events:on('sitechange', function()
        if app.sprite == hotspotPaletteSprite then
            -- sprite hasn't changed - ignore this event
            return
        end
        hotspotPaletteSprite = app.sprite

        -- Check if our dialog is open
        if hotspotPaletteDialog then
            closeHotspotPaletteDialog()
        end
        local hotspots = loadHotspots(true)
        if hotspots and #hotspots > 0 then
            -- reopen the dialog to reflect the new sprite's hotspots
            openHotspotPaletteDialog()
        end
    end)
end

function exit(plugin)
    if hotspotPaletteDialog then
        hotspotPaletteDialog:close()
    end
    hotspotPaletteDialog = nil
    app.events:off(hotspotSiteChangeListener)
end
