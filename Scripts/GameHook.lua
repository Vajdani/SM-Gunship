---@diagnostic disable:duplicate-set-field

dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "font.lua"
dofile "util.lua"

---@class GameHook : ToolClass
GameHook = class()

function GameHook:client_onCreate()
    if g_gameHook then return end

    dofile "$CONTENT_DATA/Scripts/ProjectileLibrary.lua"

    g_gameHook = self.tool
end

function GameHook:cl_delayFade(delay)
    if delay > 0 then
        delay = delay - 1
        sm.event.sendToTool(self.tool, "cl_delayFade", delay)
        return
    end

    sm.gui.endFadeToBlack(2)
end

-- function GameHook:sv_explosionDelay(args)
--     local id = tostring(args.position)
--     local trigger = g_explosionTriggers[id]
--     if not sm.exists(trigger) then
--         print("delay")
--         sm.event.sendToTool(g_gameHook, "sv_explosionDelay", args)
--         return
--     end

--     print(trigger, trigger:getContents())

--     sm.areaTrigger.destroy(trigger)
--     g_explosionTriggers[id] = nil

--     oldExplode(
--         args.position,
--         args.level,
--         args.destructionRadius,
--         args.impulseRadius,
--         args.magnitude,
--         args.effectName,
--         args.ignoreShape,
--         args.parameters
--     )
-- end



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
    local hit, result
    if sm.exists(ignoredObject) then
        hit, result = oldRaycast(startPos, endPos, ignoredObject, collisionFilter)
    else
        hit, result = oldRaycast(startPos, endPos, nil, collisionFilter)
    end

    local cHit, cResult = CheckCustomCollision(hit, result)
    if cHit then
        return true, cResult
    end

    return oldRaycast(startPos, endPos, ignoredObject, mask)
end

oldSpherecast = oldSpherecast or sm.physics.spherecast
function sm.physics.spherecast(startPos, endPos, radius, object, mask)
    local hit, result
    if sm.exists(object) then
        hit, result = oldSpherecast(startPos, endPos, object, collisionFilter)
    else
        hit, result = oldSpherecast(startPos, endPos, nil, collisionFilter)
    end

    local cHit, cResult = CheckCustomCollision(hit, result)
    if cHit then
        return true, cResult
    end

    return oldSpherecast(startPos, endPos, radius, object, mask)
end

g_explosionTriggers = g_explosionTriggers or {}

oldExplode = oldExplode or sm.physics.explode
function sm.physics.explode(position, level, destructionRadius, impulseRadius, magnitude, effectName, ignoreShape, parameters)
    local args = {
        position = position,
        level = level,
        radius = destructionRadius
    }
    local contacts = sm.physics.getSphereContacts(position, destructionRadius)
    for k, v in pairs(contacts.bodies) do
        for _k, _v in pairs(v:getInteractables()) do
            if _v.type == "scripted" then
                sm.event.sendToInteractable(_v, "sv_e_onExplode", args)
            end
        end
    end

    for k, v in pairs(contacts.characters) do
        sm.event.sendToCharacter(v, "sv_e_onExplode", args)
    end

    for k, v in pairs(contacts.harvestables) do
        sm.event.sendToHarvestable(v, "sv_e_onExplode", args)
    end

    local hit, result = sm.physics.spherecast(position, position - VEC3_UP * 0.1, destructionRadius, nil, sm.physics.filter.all)
    if result.type == "body" then
        local int = result:getShape().interactable
        if int and int.type == "scripted" then
            sm.event.sendToInteractable(int, "sv_e_onExplode", args)
        end
    end

    -- g_explosionTriggers[tostring(position)] = sm.areaTrigger.createSphere(destructionRadius, position, nil, sm.areaTrigger.filter.all)

    -- sm.event.sendToTool(g_gameHook, "sv_explosionDelay", {
    --     position = position,
    --     level = level,
    --     destructionRadius = destructionRadius,
    --     impulseRadius = impulseRadius,
    --     magnitude = magnitude,
    --     effectName = effectName,
    --     ignoreShape = ignoreShape,
    --     parameters = parameters
    -- })

    oldExplode(position, level, destructionRadius, impulseRadius, magnitude, effectName, ignoreShape, parameters)
end