---@diagnostic disable:duplicate-set-field

dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "ProjectileLibrary.lua"
dofile "util.lua"

---@class GameHook : ToolClass
GameHook = class()

local collisionFilter = sm.physics.filter.default + sm.physics.filter.areaTrigger
local function CheckCustomCollision(hit, result)
    if not hit or result.type ~= "areaTrigger" then return false, result end

    local trigger = result:getAreaTrigger()
    if not sm.exists(trigger) then return false, result end

    local userdata = trigger:getUserData()
    if not userdata or not userdata.isCustomCollision then return false, result end

    return true, {
        directionWorld = result.directionWorld,
        fraction = result.fraction,
        normalLocal = result.normalLocal,
        normalWorld = result.normalWorld,
        originWorld = result.originWorld,
        pointLocal = result.pointLocal,
        pointWorld = result.pointWorld,
        type = "body",
        valid = result.valid,
        getAreaTrigger = function() return nil end,
        getBody = function()
            return userdata.parent.body
        end,
        getCharacter = function() return nil end,
        getHarvestable = function() return nil end,
        getJoint = function() return nil end,
        getLiftData = function() return nil end,
        getShape = function()
            return userdata.parent
        end,
    }
end


oldRaycast = oldRaycast or sm.physics.raycast
function sm.physics.raycast(startPos, endPos, ignoredObject, mask)
    local hit, result = oldRaycast(startPos, endPos, ignoredObject, collisionFilter)
    local cHit, cResult = CheckCustomCollision(hit, result)
    if cHit then
        return true, cResult
    end

    return oldRaycast(startPos, endPos, ignoredObject, mask)
end

oldSpherecast = oldSpherecast or sm.physics.spherecast
function sm.physics.spherecast(startPos, endPos, radius, object, mask)
    local hit, result = oldSpherecast(startPos, endPos, radius, object, collisionFilter)
    local cHit, cResult = CheckCustomCollision(hit, result)
    if cHit then
        return true, cResult
    end

    return oldSpherecast(startPos, endPos, radius, object, mask)
end