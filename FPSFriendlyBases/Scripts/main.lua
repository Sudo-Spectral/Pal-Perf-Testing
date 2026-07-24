-- FPSFriendlyBases
-- UE4SS Lua mod for Palworld
-- Throttles base-camp AI and map-object ticks by distance for FPS.
-- Installation path:
-- Palworld\Pal\Binaries\Win64\ue4ss\Mods\FPSFriendlyBases\Scripts\main.lua

local MOD_NAME = "FPSFriendlyBases"
local MOD_VERSION = "1.2.0"

local function log(message)
    print(string.format("[%s v%s] %s\n", MOD_NAME, MOD_VERSION, tostring(message)))
end

local function is_valid_object(object)
    if object == nil then
        return false
    end

    local success, is_valid = pcall(function()
        return object:IsValid()
    end)

    return success and is_valid
end

local function get_mod_directory()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end

    local scripts_dir = source:match("^(.*)[/\\]")
    if not scripts_dir then
        return nil
    end

    return scripts_dir:match("^(.*)[/\\]")
end

local MOD_DIR = get_mod_directory()
local CONFIG_PATH = MOD_DIR and (MOD_DIR .. "\\config.ini") or "config.ini"

-- Defaults: maximum-harsh performance preset.
local DEFAULT_CONFIG = {
    BaseCampTickInvokeMaxNumInOneTick = 1,
    BaseCampBands = {
        {
            DistanceInRangeFromPlayer = -1.0,
            TickInterval = 30.0,
            bMergeDropItems = true,
            bUpdateSimple = true,
        },
        {
            DistanceInRangeFromPlayer = 100.0,
            TickInterval = 45.0,
            bMergeDropItems = true,
            bUpdateSimple = true,
        },
        {
            DistanceInRangeFromPlayer = 500.0,
            TickInterval = 60.0,
            bMergeDropItems = true,
            bUpdateSimple = true,
        },
        {
            DistanceInRangeFromPlayer = 1500.0,
            TickInterval = 90.0,
            bMergeDropItems = true,
            bUpdateSimple = true,
        },
        {
            DistanceInRangeFromPlayer = 3000.0,
            TickInterval = 120.0,
            bMergeDropItems = true,
            bUpdateSimple = true,
        },
    },
    MapObjectBands = {
        {
            DistanceInRangeFromPlayer = -1.0,
            TickInterval = 15.0,
            bBuildObjectVisible = true,
            bInvalidTickForSkeletalMeshComponent = true,
        },
        {
            DistanceInRangeFromPlayer = 100.0,
            TickInterval = 30.0,
            bBuildObjectVisible = false,
            bInvalidTickForSkeletalMeshComponent = true,
        },
        {
            DistanceInRangeFromPlayer = 500.0,
            TickInterval = 60.0,
            bBuildObjectVisible = false,
            bInvalidTickForSkeletalMeshComponent = true,
        },
        {
            DistanceInRangeFromPlayer = 1500.0,
            TickInterval = 90.0,
            bBuildObjectVisible = false,
            bInvalidTickForSkeletalMeshComponent = true,
        },
        {
            DistanceInRangeFromPlayer = 3000.0,
            TickInterval = 120.0,
            bBuildObjectVisible = false,
            bInvalidTickForSkeletalMeshComponent = true,
        },
    },
}

local function bool_to_ini(value)
    if value then
        return "true"
    end
    return "false"
end

local function build_default_config_text()
    local lines = {
        "; FPS Friendly Bases config",
        "; Generated automatically if missing. Edit values, then restart Palworld.",
        "; Higher TickInterval = more FPS, but pals/buildings update less often.",
        "",
        "[General]",
        "; How many base camps may fully tick in one frame.",
        "; Lower = smoother FPS spikes. Higher = camps catch up faster after travel.",
        "BaseCampTickInvokeMaxNumInOneTick=" .. tostring(DEFAULT_CONFIG.BaseCampTickInvokeMaxNumInOneTick),
        "",
    }

    for index, band in ipairs(DEFAULT_CONFIG.BaseCampBands) do
        lines[#lines + 1] = string.format("[BaseCamp.Band%d]", index)
        lines[#lines + 1] = "; Player distance threshold for this band (-1 = nearest / closest tier)."
        lines[#lines + 1] = "DistanceInRangeFromPlayer=" .. tostring(band.DistanceInRangeFromPlayer)
        lines[#lines + 1] = "; Seconds between base AI updates. Higher = more FPS, pals look less lively."
        lines[#lines + 1] = "TickInterval=" .. tostring(band.TickInterval)
        lines[#lines + 1] = "; Merge ground loot piles. true = less item-clutter CPU cost."
        lines[#lines + 1] = "bMergeDropItems=" .. bool_to_ini(band.bMergeDropItems)
        lines[#lines + 1] = "; Use simplified base updates. true = more FPS; pals may look idle while working."
        lines[#lines + 1] = "bUpdateSimple=" .. bool_to_ini(band.bUpdateSimple)
        lines[#lines + 1] = ""
    end

    for index, band in ipairs(DEFAULT_CONFIG.MapObjectBands) do
        lines[#lines + 1] = string.format("[MapObject.Band%d]", index)
        lines[#lines + 1] = "; Player distance threshold for this building/map-object band (-1 = nearest)."
        lines[#lines + 1] = "DistanceInRangeFromPlayer=" .. tostring(band.DistanceInRangeFromPlayer)
        lines[#lines + 1] = "; Seconds between map-object ticks. Higher = more FPS around dense bases."
        lines[#lines + 1] = "TickInterval=" .. tostring(band.TickInterval)
        lines[#lines + 1] = "; Keep build objects visible in this band. false saves FPS when far away."
        lines[#lines + 1] = "bBuildObjectVisible=" .. bool_to_ini(band.bBuildObjectVisible)
        lines[#lines + 1] = "; Skip skeletal-mesh ticks. true = more FPS; animated buildings update less."
        lines[#lines + 1] = "bInvalidTickForSkeletalMeshComponent=" .. bool_to_ini(band.bInvalidTickForSkeletalMeshComponent)
        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

local function ensure_config_file()
    local file = io.open(CONFIG_PATH, "r")
    if file then
        file:close()
        return false
    end

    local out = io.open(CONFIG_PATH, "w")
    if not out then
        log("Could not create config.ini at: " .. tostring(CONFIG_PATH))
        return false
    end

    out:write(build_default_config_text())
    out:close()
    log("Generated config.ini with defaults at: " .. tostring(CONFIG_PATH))
    return true
end

local function trim(text)
    return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_bool(text, default_value)
    text = string.lower(trim(text))
    if text == "true" or text == "1" or text == "yes" or text == "on" then
        return true
    end
    if text == "false" or text == "0" or text == "no" or text == "off" then
        return false
    end
    return default_value
end

local function parse_number(text, default_value)
    local value = tonumber(trim(text))
    if value == nil then
        return default_value
    end
    return value
end

local function deep_copy_bands(bands)
    local copy = {}
    for index, band in ipairs(bands) do
        copy[index] = {}
        for key, value in pairs(band) do
            copy[index][key] = value
        end
    end
    return copy
end

local function load_config()
    ensure_config_file()

    local config = {
        BaseCampTickInvokeMaxNumInOneTick = DEFAULT_CONFIG.BaseCampTickInvokeMaxNumInOneTick,
        BaseCampBands = deep_copy_bands(DEFAULT_CONFIG.BaseCampBands),
        MapObjectBands = deep_copy_bands(DEFAULT_CONFIG.MapObjectBands),
    }

    local file = io.open(CONFIG_PATH, "r")
    if not file then
        log("Using built-in defaults (config.ini unreadable).")
        return config
    end

    local section = nil
    for raw_line in file:lines() do
        local line = trim(raw_line)
        if line ~= "" and not line:match("^;") and not line:match("^#") then
            local section_name = line:match("^%[(.-)%]$")
            if section_name then
                section = section_name
            else
                local key, value = line:match("^([^=]+)=(.*)$")
                if key and value and section then
                    key = trim(key)
                    value = trim(value)

                    if section == "General" and key == "BaseCampTickInvokeMaxNumInOneTick" then
                        config.BaseCampTickInvokeMaxNumInOneTick = math.floor(
                            parse_number(value, config.BaseCampTickInvokeMaxNumInOneTick) + 0.5
                        )
                    else
                        local camp_index = section:match("^BaseCamp%.Band(%d+)$")
                        local map_index = section:match("^MapObject%.Band(%d+)$")
                        local band = nil

                        if camp_index then
                            camp_index = tonumber(camp_index)
                            config.BaseCampBands[camp_index] = config.BaseCampBands[camp_index] or {
                                DistanceInRangeFromPlayer = -1.0,
                                TickInterval = 5.0,
                                bMergeDropItems = true,
                                bUpdateSimple = true,
                            }
                            band = config.BaseCampBands[camp_index]
                        elseif map_index then
                            map_index = tonumber(map_index)
                            config.MapObjectBands[map_index] = config.MapObjectBands[map_index] or {
                                DistanceInRangeFromPlayer = -1.0,
                                TickInterval = 1.0,
                                bBuildObjectVisible = true,
                                bInvalidTickForSkeletalMeshComponent = false,
                            }
                            band = config.MapObjectBands[map_index]
                        end

                        if band then
                            if key == "DistanceInRangeFromPlayer" or key == "TickInterval" then
                                band[key] = parse_number(value, band[key])
                            elseif key == "bMergeDropItems"
                                or key == "bUpdateSimple"
                                or key == "bBuildObjectVisible"
                                or key == "bInvalidTickForSkeletalMeshComponent" then
                                band[key] = parse_bool(value, band[key])
                            end
                        end
                    end
                end
            end
        end
    end

    file:close()
    log("Loaded config.ini")
    return config
end

local Config = load_config()

local function find_first_of_names(names)
    for _, name in ipairs(names) do
        local success, result = pcall(function()
            return FindFirstOf(name)
        end)

        if success and is_valid_object(result) then
            return result, name
        end
    end

    return nil, nil
end

local function get_array_num(array)
    local success, num = pcall(function()
        if array.GetArrayNum ~= nil then
            return array:GetArrayNum()
        end
        return #array
    end)

    if success and type(num) == "number" then
        return num
    end

    return 0
end

local function get_array_element(array, zero_based_index)
    local success, element = pcall(function()
        return array[zero_based_index]
    end)

    if success and element ~= nil then
        return element
    end

    success, element = pcall(function()
        return array[zero_based_index + 1]
    end)

    if success and element ~= nil then
        return element
    end

    return nil
end

local function set_field(target, field_name, value)
    local success, err = pcall(function()
        target[field_name] = value
    end)

    if not success then
        log(string.format("Failed to set %s: %s", field_name, tostring(err)))
        return false
    end

    return true
end

local function apply_band_fields(element, fields)
    local changed = 0

    for field_name, value in pairs(fields) do
        if set_field(element, field_name, value) then
            changed = changed + 1
        end
    end

    return changed
end

local function apply_significance_bands(owner, property_name, bands, field_names)
    if not is_valid_object(owner) then
        return 0
    end

    local success, array = pcall(function()
        return owner[property_name]
    end)

    if not success or array == nil then
        log(string.format("Missing property %s", property_name))
        return 0
    end

    local count = get_array_num(array)
    if count <= 0 then
        log(string.format("%s is empty; cannot patch bands yet.", property_name))
        return 0
    end

    local changed = 0
    local limit = math.min(count, #bands)

    for index = 1, limit do
        local element = get_array_element(array, index - 1)
        if element ~= nil then
            local fields = {}
            for _, field_name in ipairs(field_names) do
                fields[field_name] = bands[index][field_name]
            end
            changed = changed + apply_band_fields(element, fields)
        end
    end

    if #bands ~= count then
        log(string.format(
            "%s band count mismatch (config=%d, game=%d). Patched overlapping bands only.",
            property_name,
            #bands,
            count
        ))
    end

    return changed
end

local function apply_base_camp_settings(manager)
    if not is_valid_object(manager) then
        return false
    end

    local changed = apply_significance_bands(
        manager,
        "BaseCampSignificanceInfoList",
        Config.BaseCampBands,
        {
            "DistanceInRangeFromPlayer",
            "TickInterval",
            "bMergeDropItems",
            "bUpdateSimple",
        }
    )

    if set_field(manager, "BaseCampTickInvokeMaxNumInOneTick", Config.BaseCampTickInvokeMaxNumInOneTick) then
        changed = changed + 1
    end

    if changed > 0 then
        log(string.format("Applied base-camp settings (%d field writes).", changed))
        return true
    end

    return false
end

local function apply_map_object_settings(manager)
    if not is_valid_object(manager) then
        return false
    end

    local changed = apply_significance_bands(
        manager,
        "SignificanceInfoList",
        Config.MapObjectBands,
        {
            "DistanceInRangeFromPlayer",
            "TickInterval",
            "bBuildObjectVisible",
            "bInvalidTickForSkeletalMeshComponent",
        }
    )

    if changed > 0 then
        log(string.format("Applied map-object settings (%d field writes).", changed))
        return true
    end

    return false
end

local function find_and_apply_all()
    local base_camp, base_name = find_first_of_names({
        "BP_PalBaseCampManager_C",
        "PalBaseCampManager",
    })

    if is_valid_object(base_camp) then
        log("Using base-camp manager: " .. tostring(base_name))
        apply_base_camp_settings(base_camp)
    else
        log("Base-camp manager not available yet.")
    end

    local map_object, map_name = find_first_of_names({
        "BP_PalMapObjectManager_C",
        "PalMapObjectManager",
    })

    if is_valid_object(map_object) then
        log("Using map-object manager: " .. tostring(map_name))
        apply_map_object_settings(map_object)
    else
        log("Map-object manager not available yet.")
    end
end

local function run_on_game_thread(callback)
    if ExecuteInGameThread ~= nil then
        ExecuteInGameThread(callback)
    else
        callback()
    end
end

local function run_delayed(delay_ms, callback)
    if ExecuteInGameThreadWithDelay ~= nil then
        ExecuteInGameThreadWithDelay(delay_ms, callback)
        return
    end

    if ExecuteWithDelay ~= nil then
        ExecuteWithDelay(delay_ms, function()
            run_on_game_thread(callback)
        end)
        return
    end

    run_on_game_thread(callback)
end

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    log("ClientRestart detected. Reapplying settings.")
    run_delayed(0, find_and_apply_all)
    run_delayed(1000, find_and_apply_all)
    run_delayed(5000, find_and_apply_all)
    run_delayed(15000, find_and_apply_all)
end)

local notify_base_ok, notify_base_err = pcall(function()
    NotifyOnNewObject("/Script/Pal.PalBaseCampManager", function(manager)
        log("New PalBaseCampManager detected.")
        apply_base_camp_settings(manager)
    end)
end)

if not notify_base_ok then
    log("Failed to register PalBaseCampManager notify: " .. tostring(notify_base_err))
end

local notify_map_ok, notify_map_err = pcall(function()
    NotifyOnNewObject("/Script/Pal.PalMapObjectManager", function(manager)
        log("New PalMapObjectManager detected.")
        apply_map_object_settings(manager)
    end)
end)

if not notify_map_ok then
    log("Failed to register PalMapObjectManager notify: " .. tostring(notify_map_err))
end

run_delayed(3000, find_and_apply_all)
run_delayed(10000, find_and_apply_all)

log("Mod loaded. Config: " .. tostring(CONFIG_PATH))
