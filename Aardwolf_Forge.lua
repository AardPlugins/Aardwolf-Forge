dofile(GetInfo(60) .. "aardwolf_colors.lua")

require "aardwolf_colors"

--
-- Variables
--

-- Plugin state
processing_state = "idle" -- idle, forging_all, reverting_all
processing_queue = {}
current_weapon = nil
current_operation = nil -- "hammerforge" or "reforge"

-- Progress tracking
total_weapons = 0
processed_weapons = 0
successful_conversions = 0
failed_conversions = 0
skipped_weapons = 0

-- Debug mode
debug_mode_var_name = "hforge_var_debug_mode"
debug_mode = tonumber(GetVariable(debug_mode_var_name)) or 0

-- Inventory plugin ID
inventory_plugin_id = "88c86ea252fc1918556df9fe"

--
-- Plugin Methods
--

function OnPluginInstall()
    init_plugin()
end

function OnPluginConnect()
    init_plugin()
end

function OnPluginEnable()
    init_plugin()
end

function init_plugin()
    if not IsConnected() then
        return
    end

    EnableTimer("timer_init_plugin", false)
    Message("Hammerforge Plugin Enabled")
end

--
-- Inventory Plugin Integration
--

function get_weapon_list(search_query)
    local rc, result = CallPlugin(inventory_plugin_id, "SearchAndReturn", search_query)
    if rc == error_code.eOK then
        Debug("CallPlugin result: " .. result)
        local weapon_data = loadstring(string.format("return %s", result))()
        return weapon_data
    else
        Error("Failed to call inventory plugin")
        return nil
    end
end

function get_all_weapons()
    return get_weapon_list("type weapon")
end

function get_hammer_weapons()
    return get_weapon_list("type weapon weapontype hammer")
end

function get_non_hammer_weapons()
    return get_weapon_list("type weapon ~weapontype hammer")
end

--
-- Weapon Location Handling
--

function prepare_weapon_for_processing(weapon)
    local location = weapon.objectLocation
    
    if location == "inventory" then
        -- Weapon is already in inventory, ready to process
        return true
    elseif location == "wielded" then
        -- Remove from wielded position
        SendNoEcho("remove wielded")
        return true
    elseif location == "second" then
        -- Remove from second position
        SendNoEcho("remove second")
        return true
    elseif location == "keyring" then
        -- Weapon is in keyring, get it
        SendNoEcho("keyring get " .. weapon.objid)
        return true
    elseif tonumber(location) then
        -- Weapon is in a bag, get it
        SendNoEcho("get " .. weapon.objid .. " " .. location)
        return true
    else
        Error("Unknown weapon location: " .. tostring(location))
        return false
    end
end

function restore_weapon_location(weapon)
    local location = weapon.objectLocation
    
    if location == "inventory" then
        -- Weapon stays in inventory
        return
    elseif location == "wielded" then
        -- Restore to wielded position
        SendNoEcho("wear " .. weapon.objid .. " wielded")
    elseif location == "second" then
        -- Restore to second position
        SendNoEcho("wear " .. weapon.objid .. " second")
    elseif location == "keyring" then
        -- Put weapon back in keyring
        SendNoEcho("keyring put " .. weapon.objid)
    elseif tonumber(location) then
        -- Put weapon back in bag
        SendNoEcho("put " .. weapon.objid .. " " .. location)
    end
end

--
-- Sequential Processing Engine
--

function start_processing(operation_type, weapon_list)
    if processing_state ~= "idle" then
        Error("Already processing weapons. Use 'hforge abort' to stop.")
        return false
    end
    
    if not weapon_list or #weapon_list.items == 0 then
        Message("No weapons found to process.")
        return false
    end
    
    processing_state = operation_type
    processing_queue = {}
    
    -- Copy weapons to processing queue
    for i, weapon in ipairs(weapon_list.items) do
        table.insert(processing_queue, weapon)
    end
    
    total_weapons = #processing_queue
    processed_weapons = 0
    successful_conversions = 0
    failed_conversions = 0
    skipped_weapons = 0
    
    Message(string.format("Starting %s operation on %d weapons...", operation_type, total_weapons))
    
    process_next_weapon()
    return true
end

function process_next_weapon()
    if #processing_queue == 0 then
        finish_processing()
        return
    end
    
    current_weapon = table.remove(processing_queue, 1)
    processed_weapons = processed_weapons + 1
    
    local weapon_name = current_weapon.stats.name or "Unknown Weapon"
    Message(string.format("Processing weapon %d/%d: %s", processed_weapons, total_weapons, weapon_name))
    
    -- Prepare weapon for processing
    if not prepare_weapon_for_processing(current_weapon) then
        Error("Failed to prepare weapon for processing")
        failed_conversions = failed_conversions + 1
        process_next_weapon()
        return
    end
    
    -- Determine operation and execute command
    if processing_state == "forging_all" then
        current_operation = "hammerforge"
        SendNoEcho("hammerforge " .. current_weapon.objid)
    elseif processing_state == "reverting_all" then
        current_operation = "reforge"
        SendNoEcho("reforge " .. current_weapon.objid .. " confirm")
    end
end

function finish_processing()
    local operation_name = processing_state == "forging_all" and "hammerforge" or "reforge"
    
    AnsiNote("\n")
    Message(string.format("%s operation completed!", string.upper(operation_name)))
    Message(string.format("Total weapons: %d", total_weapons))
    Message(string.format("Successfully converted: %d", successful_conversions))
    Message(string.format("Failed conversions: %d", failed_conversions))
    Message(string.format("Skipped weapons: %d", skipped_weapons))
    AnsiNote("\n")
    
    -- Reset state
    processing_state = "idle"
    processing_queue = {}
    current_weapon = nil
    current_operation = nil
    
    -- Refresh inventory
    Message("Refreshing inventory...")
    Execute("dinv refresh")
end

function abort_processing()
    if processing_state == "idle" then
        Message("No operation currently in progress.")
        return
    end
    
    Message("Aborting current operation...")
    
    -- Restore current weapon location if needed
    if current_weapon then
        restore_weapon_location(current_weapon)
    end
    
    -- Reset state
    processing_state = "idle"
    processing_queue = {}
    current_weapon = nil
    current_operation = nil
    
    Message("Operation aborted.")
end

--
-- Trigger Handlers
--

function trigger_forge_start(name, line, wildcards, style)
    Debug("Forge start detected: " .. line)
end

function trigger_forge_success(name, line, wildcards, style)
    Debug("Forge success detected: " .. line)
    successful_conversions = successful_conversions + 1
    
    -- Restore weapon location
    if current_weapon then
        restore_weapon_location(current_weapon)
    end
    
    -- Process next weapon
    process_next_weapon()
end

function trigger_already_hammer(name, line, wildcards, style)
    Debug("Already hammer detected: " .. line)
    skipped_weapons = skipped_weapons + 1
    
    -- Restore weapon location
    if current_weapon then
        restore_weapon_location(current_weapon)
    end
    
    -- Process next weapon
    process_next_weapon()
end

function trigger_not_hammer(name, line, wildcards, style)
    Debug("Not hammer detected: " .. line)
    skipped_weapons = skipped_weapons + 1
    
    -- Restore weapon location
    if current_weapon then
        restore_weapon_location(current_weapon)
    end
    
    -- Process next weapon
    process_next_weapon()
end

function trigger_not_metal(name, line, wildcards, style)
    Debug("Not metal weapon detected: " .. line)
    skipped_weapons = skipped_weapons + 1
    
    -- Restore weapon location
    if current_weapon then
        restore_weapon_location(current_weapon)
    end
    
    -- Process next weapon
    process_next_weapon()
end

function trigger_level_too_low(name, line, wildcards, style)
    Debug("Level too low detected: " .. line)
    skipped_weapons = skipped_weapons + 1
    
    -- Restore weapon location
    if current_weapon then
        restore_weapon_location(current_weapon)
    end
    
    -- Process next weapon
    process_next_weapon()
end

function trigger_not_at_forge(name, line, wildcards, style)
    Error("You must be at a forge to use hammerforge/reforge abilities!")
    Error("Operation aborted. Please go to a forge and try again.")
    
    -- Restore current weapon location
    if current_weapon then
        restore_weapon_location(current_weapon)
    end
    
    -- Abort processing
    processing_state = "idle"
    processing_queue = {}
    current_weapon = nil
    current_operation = nil
end

--
-- Alias Handlers
--

function alias_hforge_convert(name, line, wildcards)
    local weapon_list = get_non_hammer_weapons()
    if weapon_list then
        start_processing("forging_all", weapon_list)
    end
end

function alias_hforge_revert(name, line, wildcards)
    local weapon_list = get_hammer_weapons()
    if weapon_list then
        start_processing("reverting_all", weapon_list)
    end
end

function alias_hforge_status(name, line, wildcards)
    -- Determine filter type
    local filter = wildcards.filter
    local weapon_list
    
    if filter == "hammer" then
        weapon_list = get_hammer_weapons()
    elseif filter == "nothammer" then
        weapon_list = get_non_hammer_weapons()
    else
        weapon_list = get_all_weapons()
    end
    
    if not weapon_list or #weapon_list.items == 0 then
        local filter_text = ""
        if filter == "hammer" then
            filter_text = " (hammers only)"
        elseif filter == "nothammer" then
            filter_text = " (non-hammers only)"
        end
        Message(string.format("No weapons found%s.", filter_text))
        return
    end
    
    -- Create title with filter indication
    local title = "Weapon Status Report"
    if filter == "hammer" then
        title = title .. " - Hammers Only"
    elseif filter == "nothammer" then
        title = title .. " - Non-Hammers Only"
    end
    
    Message(string.format("%s (%d weapons):", title, #weapon_list.items))
    TableNote("=" .. string.rep("=", 100))
    
    -- Table header
    TableNote(string.format("@W%-12s | %-40s | %-10s | %-5s | %-10s@w", "Location", "Name", "Type", "Level", "DamType"))
    TableNote("-" .. string.rep("-", 100))
    
    local hammer_count = 0
    local other_count = 0
    
    for i, weapon in ipairs(weapon_list.items) do
        local weapon_name = weapon.colorName or weapon.stats.name or "Unknown Weapon"
        local weapon_type = weapon.stats.weapontype or "unknown"
        local location = weapon.objectLocation
        
        if weapon_type == "hammer" then
            hammer_count = hammer_count + 1
        else
            other_count = other_count + 1
        end
        
        local location_str = ""
        if location == "inventory" then
            location_str = "@g[inventory]@w"
        elseif location == "wielded" then
            location_str = "@Y[wielded]@w"
        elseif location == "second" then
            location_str = "@Y[second]@w"
        elseif location == "keyring" then
            location_str = "@M[keyring]@w"
        elseif tonumber(location) then
            location_str = "@C[bag]@w"
        else
            location_str = "@R[unknown]@w"
        end
        
        -- Get weapon level and damtype
        local weapon_level = weapon.stats.level or 0
        local weapon_damtype = weapon.stats.damtype or "unknown"
        
        -- Strip color codes from weapon name for length calculation
        local plain_name = strip_colours(weapon_name) or weapon_name
        local name_length = string.len(plain_name)
        
        -- Truncate name if too long (limit to 40 characters), keeping color codes
        local display_name = weapon_name
        if name_length > 40 then
            display_name = truncate_colored_string(weapon_name, 37) .. "@w..."
            name_length = 40  -- Set to max length for spacing calculation
        end
        
        -- Calculate proper spacing for location (accounting for color codes)
        local plain_location = ""
        if location == "inventory" then
            plain_location = "[inventory]"
        elseif location == "wielded" then
            plain_location = "[wielded]"
        elseif location == "second" then
            plain_location = "[second]"
        elseif location == "keyring" then
            plain_location = "[keyring]"
        elseif tonumber(location) then
            plain_location = "[bag]"
        else
            plain_location = "[unknown]"
        end
        
        local location_padding = string.rep(" ", math.max(0, 12 - string.len(plain_location)))
        local name_padding = string.rep(" ", math.max(0, 40 - name_length))
        
        -- Color code weapon type: white for hammers, yellow for non-hammers
        local type_color = weapon_type == "hammer" and "@w" or "@Y"
        
        -- Format the row with proper spacing
        local formatted_line = string.format("%s%s | %s%s | %s%-10s@w | @C%-5d@w | @M%-10s@w", 
            location_str,
            location_padding,
            display_name,
            name_padding,
            type_color,
            weapon_type,
            weapon_level,
            weapon_damtype)
        
        TableNote(formatted_line)
    end
    
    TableNote("=" .. string.rep("=", 100))
    Message(string.format("Summary: @Y%d@w hammers, @Y%d@w other weapons", hammer_count, other_count))
end

-- Helper function to print table rows without [HForge] prefix
function TableNote(str)
    AnsiNote(stylesToANSI(ColoursToStyles(str)))
end

-- Helper function to truncate colored strings properly
function truncate_colored_string(colored_string, max_length)
    local result = ""
    local plain_length = 0
    local i = 1
    
    while i <= string.len(colored_string) and plain_length < max_length do
        local char = string.sub(colored_string, i, i)
        if char == "@" and i < string.len(colored_string) then
            -- Color code, include both @ and the next character
            result = result .. char .. string.sub(colored_string, i + 1, i + 1)
            i = i + 2
        else
            -- Regular character
            result = result .. char
            plain_length = plain_length + 1
            i = i + 1
        end
    end
    
    return result
end

function alias_hforge_abort(name, line, wildcards)
    abort_processing()
end

function alias_hforge_help(name, line, wildcards)
    Message([[@WCommands:@w

  @Whforge help                @w- Print out this help message
  @Whforge convert             @w- Convert all non-hammer weapons to hammers
  @Whforge revert              @w- Convert all hammer weapons back to original types
  @Whforge status              @w- List all weapons with current weapon types
  @Whforge status hammer       @w- List only hammer weapons
  @Whforge status nothammer    @w- List only non-hammer weapons
  @Whforge abort               @w- Stop current processing operation
  @Whforge update              @w- Updates to the latest version of the plugin
  @Whforge reload              @w- Reloads the plugin

@WDescription:@w
This plugin automatically converts weapons using hammerforge and reforge abilities.
It processes weapons one at a time and handles different weapon locations (inventory,
wielded, second weapon, bags). You must be at a forge to use these abilities.
]])
end

--
-- Print methods
--

function Message(str)
    AnsiNote(stylesToANSI(ColoursToStyles(string.format("@C[@GHForge@C] %s@w", str))))
end

function Debug(str)
    if debug_mode == 1 then
        Message(string.format("@gDEBUG@w %s", str))
    end
end

function Error(str)
    Message(string.format("@RERROR@w %s", str))
end

--
-- Update code
--

async = require "async"

local version_url = "https://raw.githubusercontent.com/AardPlugins/Aardwolf-Forge/refs/heads/main/VERSION"
local plugin_base_url = "https://raw.githubusercontent.com/AardPlugins/Aardwolf-Forge/refs"
local plugin_files = {
    {
        remote_file = "Aardwolf_Forge.xml",
        local_file =  GetPluginInfo(GetPluginID(), 6),
        update_page= ""
    },
    {
        remote_file = "Aardwolf_Forge.lua",
        local_file =  GetPluginInfo(GetPluginID(), 20) .. "Aardwolf_Forge.lua",
        update_page= ""
    }
}
local download_file_index = 0
local download_file_branch = ""
local plugin_version = GetPluginInfo(GetPluginID(), 19)

function download_file(url, callback)
    Debug("Starting download of " .. url)
    -- Add timestamp as a query parameter to bust cache
    url = url .. "?t=" .. GetInfo(304)
    async.doAsyncRemoteRequest(url, callback, "HTTPS")
end

function alias_reload_plugin(name, line, wildcards)
    Message("Reloading plugin")
    reload_plugin()
end

function alias_update_plugin(name, line, wildcards)
    Debug("Checking version to see if there is an update")
    download_file(version_url, check_version_callback)
end

function check_version_callback(retval, page, status, headers, full_status, request_url)
    if status ~= 200 then
        Error("Error while fetching latest version number")
        return
    end

    local upstream_version = Trim(page)
    if upstream_version == tostring(plugin_version) then
        Message("@WNo new updates available")
        return
    end

    Message("@WUpdating to version " .. upstream_version)

    local branch = "tags/v" .. upstream_version
    download_plugin(branch)
end

function alias_force_update_plugin(name, line, wildcards)
    local branch = "main"

    if wildcards.branch and wildcards.branch ~= "" then
        branch = wildcards.branch
    end

    Message("@WForcing updating to branch " .. branch)

    branch = "heads/" .. branch
    download_plugin(branch)
end

function download_plugin(branch)
    Debug("Downloading plugin branch " .. branch)
    download_file_index = 0
    download_file_branch = branch

    download_next_file()
end

function download_next_file()
    download_file_index = download_file_index + 1

    if download_file_index > #plugin_files then
        Debug("All plugin files downloaded")
        finish_update()
        return
    end

    local url = string.format("%s/%s/%s", plugin_base_url, download_file_branch, plugin_files[download_file_index].remote_file)
    download_file(url, download_file_callback)
end

function download_file_callback(retval, page, status, headers, full_status, request_url)
    if status ~= 200 then
        Error("Error while fetching the plugin")
        return
    end

    plugin_files[download_file_index].update_page = page

    download_next_file()
end

function finish_update()
    Message("@WUpdating plugin. Do not touch anything!")

    -- Write all downloaded files to disk
    for i, plugin_file in ipairs(plugin_files) do
        local file = io.open(plugin_file.local_file, "w")
        file:write(plugin_file.update_page)
        file:close()
    end

    reload_plugin()

    Message("@WUpdate complete!")
end

function reload_plugin()
    if GetAlphaOption("script_prefix") == "" then
        SetAlphaOption("script_prefix", "\\\\\\")
    end
    Execute(
        GetAlphaOption("script_prefix") .. 'DoAfterSpecial(0.5, "ReloadPlugin(\'' .. GetPluginID() .. '\')", sendto.script)'
    )
end