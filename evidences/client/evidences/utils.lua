-- client/evidences/utils.lua
-- Full replacement: compact, defensive helpers for evidence systems (vehicle door math, relative coords, street names).
-- Drop-in replacement: preserves function names expected by other modules.

local utils = {}

local vehicleCache = {}

local bones = {
    [0] = "door_dside_f",
    [1] = "door_pside_f",
    [2] = "door_dside_r",
    [3] = "door_pside_r"
}

-- small vector factories (use FiveM vector objects if available)
local function vec2_new(x, y)
    if vector2 then return vector2(x or 0.0, y or 0.0) end
    return { x = x or 0.0, y = y or 0.0 }
end

local function vec3_new(x, y, z)
    if vector3 then return vector3(x or 0.0, y or 0.0, z or 0.0) end
    return { x = x or 0.0, y = y or 0.0, z = z or 0.0 }
end

local function dist3(a, b)
    local ax, ay, az = (a.x or a[1] or 0), (a.y or a[2] or 0), (a.z or a[3] or 0)
    local bx, by, bz = (b.x or b[1] or 0), (b.y or b[2] or 0), (b.z or b[3] or 0)
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Safe wrapper for GetOffsetFromEntityGivenWorldCoords
local function safe_offset(entity, wx, wy, wz)
    if not DoesEntityExist(entity) then
        return { x = 0.0, y = 0.0, z = 0.0 }
    end
    local ok, res = pcall(function()
        return GetOffsetFromEntityGivenWorldCoords(entity, wx, wy, wz)
    end)
    if not ok or not res then
        return { x = 0.0, y = 0.0, z = 0.0 }
    end
    return { x = res.x or res[1] or 0.0, y = res.y or res[2] or 0.0, z = res.z or res[3] or 0.0 }
end

-- Safe wrapper for GetWorldPositionOfEntityBone
local function safe_bone_world_pos(entity, boneIndex)
    if not DoesEntityExist(entity) or not boneIndex then return nil end
    local ok, res = pcall(function()
        return GetWorldPositionOfEntityBone(entity, boneIndex)
    end)
    if not ok or not res then return nil end
    return { x = res.x or res[1] or 0.0, y = res.y or res[2] or 0.0, z = res.z or res[3] or 0.0 }
end

-- Safe wrapper for GetEntityBoneIndexByName
local function safe_bone_index(entity, boneName)
    if not DoesEntityExist(entity) or not boneName then return -1 end
    local ok, idx = pcall(function()
        return GetEntityBoneIndexByName(entity, boneName)
    end)
    if not ok or (not idx) then return -1 end
    return idx
end

-- Public: 2D relative offset (vector2 or table)
function utils.getRelative2d(entity, worldCoords)
    if not entity or not worldCoords then return vec2_new(0, 0) end
    local off = safe_offset(entity, worldCoords.x, worldCoords.y, worldCoords.z)
    return vec2_new(off.x, off.y)
end

-- Public: 3D relative offset (vector3 or table)
function utils.getRelative3d(entity, worldCoords)
    if not entity or not worldCoords then return vec3_new(0, 0, 0) end
    local off = safe_offset(entity, worldCoords.x, worldCoords.y, worldCoords.z)
    return vec3_new(off.x, off.y, off.z)
end

-- Public: return entity-relative offset to a door bone (or nil)
function utils.getRelativeDoorCoords(entity, doorId)
    if not entity or not doorId then return nil end
    local boneName = bones[doorId]
    if not boneName then return nil end
    local boneIndex = safe_bone_index(entity, boneName)
    if not boneIndex or boneIndex < 0 then return nil end
    local worldPos = safe_bone_world_pos(entity, boneIndex)
    if not worldPos then return nil end
    local off = safe_offset(entity, worldPos.x, worldPos.y, worldPos.z)
    return vec3_new(off.x, off.y, off.z)
end

-- Public: heuristic for door presence
function utils.hasDoor(entity, doorId)
    if not entity or not doorId then return false end
    local boneName = bones[doorId]
    if not boneName then return false end
    local boneIndex = safe_bone_index(entity, boneName)
    if not boneIndex or boneIndex < 0 then return false end
    local ok, damaged = pcall(function() return IsVehicleDoorDamaged(entity, doorId) end)
    if ok and damaged then return false end
    return true
end

-- Public: determine targeted door id (0..3) or nil
function utils.getTargetedVehicleDoorId(entity, coords)
    if not DoesEntityExist(entity) or not coords then return nil end

    local model = GetEntityModel(entity)
    if not model then return nil end

    if not vehicleCache[model] then
        local okDoors, doors = pcall(function() return GetNumberOfVehicleDoors(entity) end)
        local okSeats, seats = pcall(function() return GetVehicleModelNumberOfSeats(model) end)
        vehicleCache[model] = {
            doors = (okDoors and doors) and doors or 0,
            seats = (okSeats and seats) and seats or 0
        }
    end

    local meta = vehicleCache[model]
    if not meta or meta.doors < 2 or (meta.seats and tonumber(meta.seats) > 4) then
        return nil
    end

    local relative = safe_offset(entity, coords.x, coords.y, coords.z)
    local relativeY = math.floor((relative.y or 0) * 100) / 100

    local isPassengerSide = (relative.x or 0) > 0
    local frontDoorId = isPassengerSide and 1 or 0
    local rearDoorId  = isPassengerSide and 3 or 2

    local frontBonePos = utils.hasDoor(entity, frontDoorId) and utils.getRelativeDoorCoords(entity, frontDoorId) or nil
    local rearBonePos  = utils.hasDoor(entity, rearDoorId) and utils.getRelativeDoorCoords(entity, rearDoorId) or nil

    if rearBonePos then
        if relativeY <= (rearBonePos.y or 0) then
            if dist3(relative, rearBonePos) < 2.5 then
                return rearDoorId
            end
        end
    end

    if frontBonePos then
        local passesRearCheck = true
        if rearBonePos then
            passesRearCheck = (relativeY > (rearBonePos.y or -999))
        end
        if relativeY <= (frontBonePos.y or 0) and passesRearCheck then
            if dist3(relative, frontBonePos) < 2.5 then
                return frontDoorId
            end
        end
    end

    return nil
end

-- Public: street name helper
function utils.getStreetName(location)
    if not location or not location.x then return "" end
    local ok, streetHash, crossingHash = pcall(function()
        return GetStreetNameAtCoord(location.x, location.y, location.z)
    end)
    if not ok or (not streetHash) then return "" end
    local name = GetStreetNameFromHashKey(streetHash) or ""
    local cross = ""
    if crossingHash then
        cross = GetStreetNameFromHashKey(crossingHash) or ""
    end
    if cross ~= "" then
        return name .. " – " .. cross
    end
    return name
end

return utils
