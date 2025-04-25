---@class DamageArea
---@field health? number
---@field trigger AreaTrigger

---@class Gunship : ShapeClass
---@field sv_damageAreas DamageArea[]
---@field cl_damageAreas DamageArea[]
Gunship = class()
Gunship.maxParentCount = 0
Gunship.maxChildCount = 7
Gunship.connectionInput = sm.interactable.connectionType.none
Gunship.connectionOutput = sm.interactable.connectionType.seated
Gunship.colorNormal = colour(0xcb0a00ff)
Gunship.colorHighlight = colour(0xee0a00ff)

local maxHealth = 2000
local thrusterMaxHealth = 200
local moveSpeed = 25
local boostSpeed = 100
local fireRate = 1 / 5
local rocketRate = 1
local rocketBurst = 3
local rocketBurstTicks = 5
local aimAssistRange = 100
local autocannonVelocity = 400
local autocannonDamage = 100
local autocannonProjectile = uuid("4a33d08b-4e12-4412-abb5-7b16e1aafe1a")
local rocketVelocity = 200
local rocketDamage = 100
local turretTurnSpeed = 5
local zoomFraction = 0.4
local actions = {
    [1] = true,  --Right
    [2] = true,  --Left
    [3] = true,  --Forward
    [4] = true,  --Backward
    [5] = true,  --Rockets
    [18] = true, --Aim
    [19] = true, --Shoot
    [20] = true, --Down
    [21] = true, --Up
    [16] = true, --Boost
}
local destroyActions = {
    [5] = true,
    [18] = true,
    [19] = true,
}
local turnLimit = 0.3
local rayFilter = sm.physics.filter.default + sm.physics.filter.areaTrigger
local destructionTime = 5 * 40
local destructionResistence = {
    [1] = 0.9,
    [2] = 0.75,
    [3] = 0.5,
    [4] = 0.25,
    [5] = 0.1,
    [6] = 0,
    [7] = 0,
    [8] = 0,
    [9] = 0,
    [10] = 0
}
local engineScale = vec3(0.75, 1.5, 2.065) * 0.5
local engineOffset = 0.275

local green = colour(0, 1, 0)
local red = colour(1, 0, 0)
local white = colour(1, 1, 1)
local yellow = colour(1, 1, 0)
local black = colour(0, 0, 0)

function Gunship:server_onCreate()
    if self.shape.body:isStatic() and not self.shape.body:isOnLift() then
        local uuid, rot = self.shape.uuid, self.shape.worldRotation
        sm.shape.createPart(uuid, self.shape.worldPosition - rot * sm.item.getShapeOffset(uuid), rot, true, true)
        self.shape:destroyShape()

        return
    end

    self.sv_actions = {}

    self.sv_fireTimer = 0
    self.sv_rocketTimer = 0
    self.sv_rocketCounter = 0

    self.sv_mass = self:GetBodyMass()

    self.sv_health = maxHealth
    self:setClientData(self.sv_health, 1)

    self.sv_damageAreas = {}
    for i = 1, 4 do
        local trigger = sm.areaTrigger.createBox(engineScale, self.shape.worldPosition, nil, nil, {
            id = i,
            isCustomCollision = true,
            parent = self.shape
        })
        trigger:bindOnProjectile("sv_onDamageAreaHit")

        self.sv_damageAreas[i] = {
            health = thrusterMaxHealth,
            trigger = trigger
        }
    end

    self.sv_destroyed = false
end

function Gunship:server_onDestroy()
    for k, v in pairs(self.sv_damageAreas or {}) do
        sm.areaTrigger.destroy(v.trigger)
    end
end

function Gunship:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    local level = self:GetDestructionResistence(uuid)
    if level == 0 then return end

    self:sv_takeDamage(damage * (1 - destructionResistence[level]))
end

function Gunship:server_onMelee(position, attacker, damage, power, direction, normal)
    self:sv_takeDamage(damage)
end

function Gunship:server_onExplosion(center, destructionLevel)
    self:sv_takeDamage(destructionLevel * 10)
end

function Gunship:sv_e_onHit(args)
    local pos = args.position - args.normal * 0.15
    local x, y, z = pos.x, pos.y, pos.z
    for k, v in pairs(self.sv_damageAreas) do
        local trigger = v.trigger
        local min, max = trigger:getWorldMin(), trigger:getWorldMax()
        if x >= min.x and x <= max.x and y >= min.y and y <= max.y and z > min.z and z <= max.z then
            self:sv_onDamageAreaHit(trigger, pos, nil, -args.normal --[[@as Vec3]], nil, nil, args.damage, nil, nil, sm.uuid.getNil())
            return
        end
    end

    self:sv_takeDamage(args.damage)
end

---@param velocity Vec3
function Gunship:sv_onDamageAreaHit(trigger, hitPos, airTime, velocity, name, source, damage, data, normal, uuid)
    local effect = GetProjectileData(uuid).effect
    if effect then
        local dir = -velocity:normalize()
        sm.effect.playEffect(effect, hitPos + dir * 0.05, nil, getRotation(dir, VEC3_UP))
    end

    local level = self:GetDestructionResistence(uuid)
    if level == 0 or not sm.exists(trigger) then return true end

    local id = trigger:getUserData().id
    local area = self.sv_damageAreas[id]
    if area.health <= 0 then return true end

    local finalDamage = math.ceil(damage * (1 - destructionResistence[level]))
    area.health = area.health - finalDamage
    print(("[Gunship %s Thruster %s] Recieved %s damage (%s/%s)"):format(self.shape.id, id, finalDamage, area.health, thrusterMaxHealth))

    self:sv_takeDamage(finalDamage * 0.5)
    self:setClientData({ id = id, health = area.health }, 2)

    if area.health <= 0 then
        sm.effect.playEffect("PropaneTank - ExplosionSmall", trigger:getWorldPosition())
        sm.areaTrigger.destroy(trigger)
        self.sv_damageAreas[id] = nil
    end

    return true
end

function Gunship:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    if isAnyOf(other, self.shape.body:getCreationBodies()) then return end

    local damage = (selfPointVelocity + otherPointVelocity):length()
    if damage >= 20 then
        self:sv_takeDamage(damage)
    end
end

function Gunship:server_onFixedUpdate(dt)
    if self.sv_destructionTimer then
        self.sv_destructionTimer = self.sv_destructionTimer - 1
        if self.sv_destructionTimer <= 0 then
            print(("[Gunship %s] Exploded"):format(self.shape.id))
            sm.physics.explode(self.shape.worldPosition, 10, 10, 20, 100, "PropaneTank - ExplosionBig")
            self.shape:destroyPart()
            return
        end
    end

    local missingEngines = self:UpdateDamageAreas()

    local char = self.interactable:getSeatCharacter()
    if not char then return end

    local shape, body = self.shape, self.shape.body
    local velocity = shape.velocity
    if body:hasChanged(sm.game.getServerTick() - 1) then
        self.sv_mass = self:GetBodyMass()
    end

    if missingEngines < 4 then
        self:ApplyPhysics(char, shape, body, velocity, missingEngines, dt)
    end

    self:sv_handleAutocannon(velocity, char, dt)
    self:sv_handleRocketLaunchers(char, dt)
end

function Gunship:UpdateDamageAreas()
    local missingEngines = 0
    local damageAreas = self.sv_damageAreas or self.cl_damageAreas
    for i = 1, 4 do
        local area = damageAreas[i]
        if area then
            local name = "jnt_engine"..i
            local engineDir = self:GetLocalBoneDir(name.."_effect")
            local enginePos = self.interactable:getWorldBonePosition(name)
            local worldUp = self:TransformLocalDirection(engineDir)
            local worldRight = self:TransformLocalDirection(CalculateRightVector(engineDir))
            local trigger = area.trigger
            if i == 1 or i == 3 then
                trigger:setWorldPosition(enginePos - worldRight * engineOffset)
            else
                trigger:setWorldPosition(enginePos + worldRight * engineOffset)
            end

            trigger:setWorldRotation(quat_normalise(sm.util.axesToQuat(worldRight, worldUp)))
        else
            missingEngines = missingEngines + 1
        end
    end

    return missingEngines
end

function Gunship:ApplyPhysics(char, shape, body, velocity, missingEngines, dt)
    if self.sv_destroyed or self.cl_destroyed then return end

    local _actions = self.sv_actions or self.cl_actions
    local damageAreas = self.sv_damageAreas or self.cl_damageAreas
    local mass = self.sv_mass or self.cl_mass

    local direction = char.direction
    local force = vec3(0, 0, (pcall(sm.localPlayer.getId) and 10 or getGravity()) + 0.45) + self:GetMoveDir() * (_actions[16] and boostSpeed or moveSpeed) - velocity * 0.5
    local offset = VEC3_ZERO
    local forceMultiplier = (4 - missingEngines) / 4
    if missingEngines > 0 then
        for i = 1, 4 do
            if damageAreas[i] then
                offset = offset + self.interactable:getLocalBonePosition("jnt_engine"..i)
            end
        end

        offset = offset / (4 - missingEngines)
    end
    sm.physics.applyImpulse(self.shape, force * forceMultiplier * dt * mass, true, offset)

    local torque =
        -body.angularVelocity * 0.3 -
        self.shape.up * (BoolToNum(_actions[1]) - BoolToNum(_actions[2])) * 0.15
    if _actions[18] or (self.sv_forceStatic or self.cl_forceStatic) then
        torque = torque + CalculateRightVector(self.aimDirection):cross(shape.right)
    else
        self.aimDirection = direction

        local steer = CalculateRightVector(direction):cross(shape.right)
        local length = steer:length()
        if length > turnLimit then
            steer = steer * (turnLimit / length)
        end

        torque = torque + shape.up:cross(direction) + steer
    end
    sm.physics.applyTorque(body, torque * mass * forceMultiplier, true)
end

function Gunship:sv_handleAutocannon(velocity, char, dt)
    self.sv_fireTimer = math.max(self.sv_fireTimer - dt, 0)
    if self.sv_actions[19] and self.sv_fireTimer <= 0 then
        local firePos, fireDir = self:GetTurretFirePos() + velocity * (1 / 40), self:GetTurretDir()
        local targetPos = firePos + fireDir * aimAssistRange
        local hit, result = sm.physics.raycast(firePos, targetPos, self.shape, rayFilter)
        if hit then
            targetPos = result.pointWorld
        end

        local low, high = sm.projectile.solveBallisticArc(firePos, targetPos, autocannonVelocity, 10)
        if low and low:length2() > FLT_EPSILON then
            fireDir = low:normalize()
        end

        self.network:sendToClients("cl_shoot", 0)
        sm.projectile.projectileAttack(autocannonProjectile, autocannonDamage, firePos, fireDir * autocannonVelocity, char:getPlayer())

        self.sv_fireTimer = fireRate
    end
end

function Gunship:sv_handleRocketLaunchers(char, dt)
    self.sv_rocketTimer = math.max(self.sv_rocketTimer - dt, 0)
    if self.sv_actions[5] and self.sv_rocketTimer <= 0 then
        self.sv_rocketCounter = self.sv_rocketCounter % 2 + 1
        local player = char:getPlayer()
        self:sv_fireRocket({ delay = 0, player = player })
        for i = 1, rocketBurst - 1 do
            sm.event.sendToInteractable(self.interactable, "sv_fireRocket", {
                delay = i * rocketBurstTicks,
                player = player
            })
        end

        self.sv_rocketTimer = rocketRate
    end
end

function Gunship:sv_takeDamage(damage)
    if self.sv_health <= 0 then return end

    damage = math.ceil(damage)

    print(("[Gunship %s] Recieved %s damage (%s/%s)"):format(self.shape.id, damage, self.sv_health, maxHealth))

    self.sv_health = self.sv_health - damage
    if self.sv_health <= 0 then
        print(("[Gunship %s] Took fatal damage!"):format(self.shape.id))

        self.sv_destroyed = true
        self.sv_destructionTimer = destructionTime
        self.sv_actions = {}

        for k, v in pairs(self.sv_damageAreas) do
            sm.effect.playEffect("PropaneTank - ExplosionSmall", v.trigger:getWorldPosition())
            sm.areaTrigger.destroy(v.trigger)
        end
        self.sv_damageAreas = {}

        self:setClientData(true, 3)
    else
        self:setClientData(self.sv_health, 1)
    end
end

function Gunship:sv_updateAction(args)
    if self.sv_destroyed and not destroyActions[args[1]] then return end

    self.sv_actions[args[1]] = args[2]
    self.network:sendToClients("cl_updateAction", args)
end

function Gunship:sv_resetAction()
    for k, v in ipairs(actions) do
        self.sv_actions[k] = false
    end
    self.network:sendToClients("cl_resetAction")
end

function Gunship:sv_fireRocket(args)
    if args.delay > 0 then
        args.delay = args.delay - 1
        sm.event.sendToInteractable(self.interactable, "sv_fireRocket", args)
        return
    end

    local firePos, fireDir = self:GetRocketFireData(self.interactable:getWorldBonePosition("jnt_rocket"..self.sv_rocketCounter.."_firepos"))
    self.network:sendToClients("cl_shoot", self.sv_rocketCounter)
    sm.projectile.projectileAttack(projectile_explosivetape, rocketDamage, firePos + fireDir, fireDir * rocketVelocity, args.player)
end

function Gunship:sv_onRocketInput(data)
    sm.event.sendToInteractable(data.cannon, "sv_onRocketInput", { action = data.action, state = data.state })
end

function Gunship:sv_onRocketFire()
    self.sv_forceStatic = true
    self:setClientData(true, 4)
end

function Gunship:sv_onRocketExplode()
    self.sv_forceStatic = false
    self:setClientData(false, 4)
end

function Gunship:sv_unseat(char)
    if self.sv_destroyed then
        local pos = self:GetCameraPosition() + self.shape.at
        char:setWorldPosition(pos)
        sm.physics.applyImpulse(char, self.shape.at * char.mass * 50)

        sm.effect.playEffect("Vacuumpipe - Blowout", pos, nil, self.shape.worldRotation)
    else
        self:sv_resetAction()
    end
end



function Gunship:client_onCreate()
    self.cl_actions = {}

    local cockpit = sm.effect.createEffect("ShapeRenderable")
    cockpit:setParameter("uuid", uuid("5e7a0724-a469-468a-9138-eea1b23c2387"))
    cockpit:setParameter("color", self.shape.color)
    cockpit:setScale(vec3(0.25, 0.25, 0.25))

    self.cockpit = cockpit

    self.thrusters = {}
    for i = 1, 4 do
        local thruster = sm.effect.createEffect("Thruster - Level 5", self.interactable, "jnt_engine" .. i .. "_effect")
        thruster:setOffsetRotation(angleAxis(math.rad(90), VEC3_RIGHT))
        table.insert(self.thrusters, thruster)
    end

    local aimPoint = sm.effect.createEffect("ShapeRenderable")
    aimPoint:setParameter("uuid", obj_uishape)
    aimPoint:setParameter("color", green)
    aimPoint:setScale(vec3(0.25, 0.25, 0.25))
    self.aimPoint = aimPoint

    self.tracers = {}
    for i = 1, 2 do
        table.insert(self.tracers, Line_tracer():init(0.15, green))
    end

    self.engine = sm.effect.createEffect("GasEngine - Level 4", self.interactable, "jnt_camera")

    self.wgui = {}

    -- if not self.wgui.hotbar then
    --     self.wgui.hotbar = {
    --         items = {},
    --         start = function(_self)
    --             for k, v in ipairs(_self.items) do
    --                 for _k, _v in pairs(v) do
    --                     _v:start()
    --                 end
    --             end
    --         end,
    --         stop = function(_self)
    --             for k, v in ipairs(_self.items) do
    --                 for _k, _v in pairs(v) do
    --                     _v:stop()
    --                 end
    --             end
    --         end,
    --         destroy = function(_self)
    --             for k, v in ipairs(_self.items) do
    --                 for _k, _v in pairs(v) do
    --                     _v:destroy()
    --                 end
    --             end
    --         end
    --     }
    -- end

    local mainHealth = sm.effect.createEffect("ShapeRenderable")
    mainHealth:setParameter("uuid", obj_uishape)
    self.wgui.mainHealth = mainHealth

    self.wgui.mainHealthText = Text3D():init(4, 3)
    self.wgui.mainHealthText:update("100%")

    for i = 1, 4 do
        local bar = sm.effect.createEffect("ShapeRenderable")
        bar:setParameter("uuid", obj_uishape)
        self.wgui["engine"..i.."Health"] = bar

        local text3D = Text3D():init(4, i % 2 == 0 and 2 or 1)
        text3D:update("100%")
        self.wgui["engine"..i.."HealthText"] = text3D
    end

    self.gui = sm.gui.createSeatGui()

    self.cl_health = 0

    self.interactable:setAnimEnabled("engine1_rotate", true)
    self.interactable:setAnimEnabled("engine2_rotate", true)
    self.interactable:setAnimEnabled("engine3_rotate", true)
    self.interactable:setAnimEnabled("engine4_rotate", true)
    self.interactable:setAnimEnabled("turret_rotate_horizontal", true)
    self.interactable:setAnimEnabled("turret_rotate_vertical", true)

    self.leftThrusterAnim = 0.5
    self.rightThrusterAnim = 0.5

    self.horizontalTurretAnim = sm.quat.identity()
    self.verticalTurretAnim = 0

    self.cl_mass = self:GetBodyMass()
    self.cl_damageAreas = {}
    for i = 1, 4 do
        local trigger = sm.areaTrigger.createBox(engineScale, self.shape.worldPosition, nil, nil, {
            id = i,
            isCustomCollision = true,
            parent = self.shape
        })
        trigger:bindOnProjectile("cl_onDamageAreaHit")

        self.cl_damageAreas[i] = {
            trigger = trigger
        }
    end

    self.alarm = sm.effect.createEffect("Gunship - AlarmLight", self.interactable)
    self.alarm:setOffsetPosition(VEC3_UP * 4.5 + VEC3_FORWARD  * 0.25)

    self.cl_destroyed = false
    self.cl_forceStatic = false
end

function Gunship:client_onDestroy()
    if self.seatedTick then
        sm.camera.setCameraState(0)
    end

    self.cockpit:destroy()

    for k, v in pairs(self.thrusters) do
        v:destroy()
    end

    self.aimPoint:destroy()
    for i = 1, 2 do
        self.tracers[i]:destroy()
    end

    for k, v in pairs(self.wgui) do
        v:destroy()
    end

    self.gui:destroy()

    for k, v in pairs(self.cl_damageAreas) do
        sm.areaTrigger.destroy(v.trigger)
    end

    self.alarm:destroy()
end

function Gunship:cl_onClientDataUpdate(args)
    local data, channel = args[1], args[2]
    if channel == 1 then
        self.cl_health = data
        self:cl_updateBodyHealth(data)
    elseif channel == 2 then
        self:cl_updateThrusterHealth(data)
    elseif channel == 3 then
        self.cl_destroyed = data
        self.cl_actions = {}

        self.engine:stop()

        self:cl_updateBodyHealth(0)

        for k, v in pairs(self.cl_damageAreas) do
            self:cl_updateThrusterHealth({ id = k, health = 0 })
        end
        self.cl_damageAreas = {}

        self.cockpit:stop()
        self.alarm:start()
    elseif channel == 4 then
        self.cl_forceStatic = data
    end
end

local rocketOffset = {
    vec3(-1.0625, -4.625, 0.187502),
    vec3(1.0625, -4.625, 0.187502),
}
local turretOffset = {
    vec3(0, -3.3125, -1)
}
function Gunship:client_onUpdate(dt)
    self.cockpit:setParameter("color", self.shape.color)
    self:SetBodyVisibility(not self.seatedTick or self.controllingRocket) --or self.cl_destroyed)
    self:cl_updateThrusters(dt)

    local seatedChar = self.interactable:getSeatCharacter()
    if seatedChar and not self.cl_destroyed then
        if not self.engine:isPlaying() then
            for k, v in pairs(self.thrusters) do
                v:start()
            end
            self.engine:start()
        end

        self.engine:setParameter("gas", 1)

        local moving = self:GetMoveDir():length2()
        if self.cl_actions[16] and moving == 1 then
            self.engine:setParameter("rpm", 1)
            self.engine:setParameter("load", 0)
        else
            self.engine:setParameter("rpm", 0.33 + moving * 0.1)
            self.engine:setParameter("load", 0.5 + moving * 0.1)
        end
    elseif not seatedChar and self.engine:isPlaying() then
        for k, v in pairs(self.thrusters) do
            v:stop()
        end
        self.engine:stop()
    end

    self:cl_updateTurret(seatedChar, dt)

    if self.seatedTick and not self.controllingRocket then
        if not self.cockpit:isPlaying() then
            self.cockpit:start()
            self.aimPoint:start()

            for k, v in pairs(self.wgui) do
                v:start()
            end
        end

        self:cl_updateSeatGui()
    else
        if self.cockpit:isPlaying() then
            self.cockpit:stop()
            self.aimPoint:stop()

            for i = 1, 2 do
                self.tracers[i]:stop()
            end

            for k, v in pairs(self.wgui) do
                v:stop()
            end
        end

        return
    end

    if self.cl_destroyed then
        sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true), self.flash and "#ff0000EJECT" or "EJECT", "")
    end

    local camPos = self:GetCameraPosition(dt)
    local char = sm.localPlayer.getPlayer().character
    local charDir = char:getSmoothViewDirection()

    self:cl_updateCockpitUI(dt)

    sm.camera.setCameraState(2)
    sm.camera.setPosition(camPos)
    sm.camera.setDirection(charDir)
    -- local shapePos, shapeRot, up, at, right = self:GetAccurateTransform(dt)
    -- sm.camera.setRotation(shapeRot * angleAxis(math.rad(90), VEC3_RIGHT) * angleAxis(math.rad(180), VEC3_FORWARD))

    if self.cl_actions[18] then
        sm.camera.setFov(sm.camera.getDefaultFov() * zoomFraction)
    else
        sm.camera.setFov(sm.camera.getDefaultFov())
    end

    local targetPos, offsets
    if self.tracingTurret then
        local offset = turretOffset[1]
        local origin =
            self.shape:getInterpolatedWorldPosition() +
            self.shape:getInterpolatedAt() * offset.z -
            self.shape:getInterpolatedUp() * offset.y +
            self.shape:getInterpolatedRight() * offset.x
        local endPos = origin + self:GetTurretDir() * aimAssistRange
        local hit, result = sm.physics.raycast(origin, endPos, self.shape, rayFilter)
        targetPos = hit and result.pointWorld or endPos

        self:cl_setTracerColour(math.asin(self.shape:transformDirection(charDir).y) > 0 and red or green)

        offsets = turretOffset
    else
        _, _, targetPos = self:GetRocketFireData(camPos, dt)
        offsets = rocketOffset

        self:cl_setTracerColour(green)
    end

    self.aimPoint:setPosition(targetPos)
    if self.tracerEnabled then
        for i = 1, 2 do
            local offset = offsets[i]
            if offset then
                self.tracers[i]:update(
                    self.shape:getInterpolatedWorldPosition() +
                    self.shape:getInterpolatedAt() * offset.z -
                    self.shape:getInterpolatedUp() * offset.y +
                    self.shape:getInterpolatedRight() * offset.x +
                    self.shape.velocity * dt, targetPos
                )
            else
                self.tracers[i]:stop()
            end
        end
    elseif self.tracers[1].effect:isPlaying() then
        for i = 1, 2 do
            self.tracers[i]:stop()
        end
    end
end

function Gunship:client_onFixedUpdate(dt)
    if #self.interactable:getChildren(2 ^ 14) == 0 and self.controllingRocket then
        self.controllingRocket = false
        self.network:sendToServer("sv_onRocketExplode")
    end

    if self.shape.body:hasChanged(sm.game.getServerTick() - 1) then
        self.cl_mass = self:GetBodyMass()
    end

    local seatedChar = self.interactable:getSeatCharacter()
    local missingEngines = self:UpdateDamageAreas()
    if seatedChar and not sm.isHost and missingEngines < 4 then
        self:ApplyPhysics(seatedChar, self.shape, self.shape.body, self.shape.velocity, missingEngines, dt)
    end

    if self.seatedTick then
        if self.cl_destroyed and sm.game.getServerTick()%10 == 0 then
            self.flash = not self.flash
            sm.effect.playHostedEffect("Gunship - AlarmSound", self.interactable, nil, { offsetPosition = VEC3_UP * 4.5 + VEC3_FORWARD  * 0.25 })
        end

        if sm.game.getServerTick() - self.seatedTick > 10 and not seatedChar then
            self.seatedTick = nil
            sm.camera.setCameraState(0)
            self.gui:close()
        end
    end
end

function Gunship:client_canInteract()
    return self.interactable:getSeatCharacter() == nil and not self.cl_destroyed
end

function Gunship:client_onInteract(char, state)
    if not state then return end

    sm.localPlayer.setLockedControls(true)
    sm.localPlayer.setDirection(self.shape.up)
    sm.event.sendToInteractable(self.interactable, "cl_seat")
end

---@param velocity Vec3
function Gunship:cl_onDamageAreaHit(trigger, hitPos, airTime, velocity, name, source, damage, data, normal, uuid)
    -- local effect = GetProjectileData(uuid).effect
    -- if effect then
    --     local dir = -velocity:normalize()
    --     sm.effect.playEffect(effect, hitPos + dir * 0.05, nil, getRotation(dir, VEC3_UP))
    -- end

    return not sm.isHost
end

function Gunship:cl_seat()
    sm.localPlayer.setLockedControls(false)
    sm.camera.setCameraState(2)
    self.gui:open()
    self.interactable:setSeatCharacter(sm.localPlayer.getPlayer().character)
    self.seatedTick = sm.game.getServerTick()
end

function Gunship:cl_unseat()
    sm.camera.setCameraState(0)
    self.gui:close()
    self.interactable:setSeatCharacter(sm.localPlayer.getPlayer().character)
    self.seatedTick = nil

    if self.cl_destroyed then
        sm.gui.startFadeToBlack(0.01, 10)
        sm.event.sendToInteractable(self.interactable, "cl_delayFade", 10)
        self.network:sendToServer("sv_unseat", sm.localPlayer.getPlayer().character)
    else
        self.network:sendToServer("sv_unseat")
        self:cl_resetAction()
    end
end



function Gunship:client_onAction(action, state)
    if action == 8 and state then
        self.network:sendToServer("sv_takeDamage", maxHealth)
        return true
    end

    if self:cl_checkRocketInput(action, state) then
        return true
    end

    if actions[action] and not self.cl_destroyed or destroyActions[action] then
        self.cl_actions[action] = state
        self.network:sendToServer("sv_updateAction", { action, state })
    end

    if state then
        if action == 15 then
            self:cl_unseat()
        elseif action == 6 then
            self.tracerEnabled = not self.tracerEnabled
        elseif action == 7 then
            self.tracingTurret = not self.tracingTurret
        end
    end

    if action >= 8 and action <= 14 then
        if state then
            self.interactable:pressSeatInteractable(action - 8)
        else
            self.interactable:releaseSeatInteractable(action - 8)
        end
    end

    return true
end

local rocketIcon, tracerIcon, turretIcon =
    tostring(obj_interactive_propanetank_small),
    tostring(tool_connect),
    tostring(obj_interactive_mountablespudgun_creative)
local mountedCannonUUID = "0af5379e-29e8-4eb3-b965-6b3993c8f1df"
local MountedCannonGun = {
    ammoTypes = {
        "24d5e812-3902-4ac3-b214-a0c924a5c40f",
        -- "4c69fa44-dd0d-42ce-9892-e61d13922bd2",
        "e36b172c-ae2d-4697-af44-8041d9cbde0e",
        "242b84e4-c008-4780-a2dd-abacea821637"
    },
    overrideAmmoTypes = {
        "47b43e6e-280d-497e-9896-a3af721d89d2",
        "24001201-40dd-4950-b99f-17d878a9e07b",
        "8d3b98de-c981-4f05-abfe-d22ee4781d33",
    }
}
function Gunship:cl_updateSeatGui()
    self.gui:setGridItem("ButtonGrid", 0, {
        itemId = rocketIcon,
        active = self.cl_actions[5]
    })

    self.gui:setGridItem("ButtonGrid", 1, {
        itemId = tracerIcon,
        active = self.tracerEnabled
    })

    if self.tracingTurret then
        self.gui:setGridItem("ButtonGrid", 2, {
            itemId = turretIcon,
            active = self.cl_actions[19]
        })
    else
        self.gui:setGridItem("ButtonGrid", 2, {
            itemId = rocketIcon,
            active = self.cl_actions[5]
        })
    end

    local children = self.interactable:getChildren()
    for i = 1, self.maxChildCount do
        local int = children[i]
        if int then
            local uuid = tostring(int.shape.uuid)
            if uuid == mountedCannonUUID then
                self.gui:setGridItem("ButtonGrid", 2 + i, {
                    itemId = sm.GetTurretAmmoData(MountedCannonGun, sm.GetInteractableClientPublicData(int).ammoType),
                    active = int.active
                })
            else
                self.gui:setGridItem("ButtonGrid", 2 + i, {
                    itemId = uuid,
                    active = int.active
                })
            end
        else
            self.gui:setGridItem("ButtonGrid", 2 + i, nil)
        end
    end
end

function Gunship:cl_updateBodyHealth(health)
    local boxColour, textColour = self:GetHealthColour(health, maxHealth)
    self.wgui.mainHealth:setParameter("color", boxColour)

    self.wgui.mainHealthText:update(max(math.ceil(health / maxHealth * 100), 0).."%")
    self.wgui.mainHealthText:setColour(textColour or boxColour)
end

function Gunship:cl_updateThrusterHealth(data)
    local id, health = data.id, data.health
    local alive = health > 0
    self.interactable:setSubMeshVisible("engine"..id, alive)

    local boxColour, textColour = self:GetHealthColour(health, thrusterMaxHealth)
    local engineId = "engine"..id.."Health"

    self.wgui[engineId]:setParameter("color", boxColour)

    local text3D = self.wgui[engineId.."Text"]
    text3D:update(max(math.ceil(health / thrusterMaxHealth * 100), 0).."%")
    text3D:setColour(textColour or boxColour)

    if not alive then
        self.wgui[engineId]:setParameter("color", black)

        if self.thrusters[id] then
            self.thrusters[id]:destroy()
            self.thrusters[id] = nil
        end

        if self.cl_damageAreas[id] then
            sm.areaTrigger.destroy(self.cl_damageAreas[id].trigger)
            self.cl_damageAreas[id] = nil
        end
    end
end

-- local function GetItemScale(uuid)
-- 	local scale = 1
-- 	if uuid ~= sm.uuid.getNil() and not sm.item.isTool(uuid) then
-- 		local size = sm.item.getShapeSize( uuid )
-- 		local max = math.max( math.max( size.x, size.y ), size.z )
-- 		scale = 1 / max + ( size:length() - 1.4422496 ) * 0.015625
-- 		if scale * size:length() > 1.0 then
-- 			scale = 1 / size:length()
-- 		end
-- 	end

-- 	return scale
-- end

function Gunship:cl_updateCockpitUI(dt)
    local shapePos, shapeRot, up, at, right = self:GetAccurateTransform(dt)

    self.cockpit:setPosition(shapePos)
    self.cockpit:setRotation(shapeRot)

    -- local children = self.interactable:getChildren()
    -- local hotbarWidth = (#children - 1) * 0.03 * 0.5
    -- for i = 1, self.maxChildCount do
    --     local int = children[i]
    --     local hotbarItem = self.wgui.hotbar.items[i]
    --     if int then
    --         if not hotbarItem then
    --             hotbarItem = {}
    --             local itembg = sm.effect.createEffect( "ShapeRenderable" )
    --             itembg:setParameter("uuid", blk_plastic) --obj_uishape)
    --             itembg:setParameter("color", black)
    --             itembg:setScale(vec3(0.025, 0.025, 0))

    --             hotbarItem.bg = itembg

    --             local item = sm.effect.createEffect( "ShapeRenderable" )
    --             item:setScale(vec3(0.25, 0.25, 0.25) * 0.01)

    --             hotbarItem.item = item

    --             self.wgui.hotbar.items[i] = hotbarItem
    --         end

    --         if not hotbarItem.bg:isPlaying() then
    --             hotbarItem.bg:start()
    --             hotbarItem.item:start()
    --         end

    --         local uuid = tostring(int.shape.uuid)
    --         if uuid == mountedCannonUUID then
    --             local itemId = uuid(sm.GetTurretAmmoData(MountedCannonGun, sm.GetInteractableClientPublicData(int).ammoType))
    --             hotbarItem.item:setParameter("uuid", itemId)
    --             hotbarItem.item:setParameter("color", int.shape.color)
    --             hotbarItem.item:setScale(vec3(0.25, 0.25, 0.25) * 0.1 * GetItemScale(itemId))
    --         else
    --             hotbarItem.item:setParameter("uuid", int.shape.uuid)
    --             hotbarItem.item:setParameter("color", int.shape.color)
    --             hotbarItem.item:setScale(vec3(0.25, 0.25, 0.25) * 0.1 * GetItemScale(int.shape.uuid))
    --         end

    --         local itemPos = shapePos + up * 4.4 + right * (hotbarWidth - (i - 1) * 0.03) + at * 0.07
    --         hotbarItem.bg:setPosition(itemPos)
    --         hotbarItem.bg:setRotation(shapeRot)
    --         hotbarItem.bg:setParameter("color", int.active and white or black)

    --         hotbarItem.item:setPosition(itemPos - up * 0.005)
    --         hotbarItem.item:setRotation(shapeRot * angleAxis(-RAD90, VEC3_RIGHT))
    --     elseif hotbarItem and hotbarItem.bg:isPlaying() then
    --         hotbarItem.bg:stop()
    --         hotbarItem.item:stop()
    --     end
    -- end

    -- if sm.game.getServerTick()%40 == 0 then
    --     self.init = false
    -- end

    if not self.init then
        for i = 1, 10 do
            local bar = sm.effect.createEffect("ShapeRenderable")
            bar:setParameter("uuid", obj_uishape)
            self.wgui["bar" .. i] = bar
        end

        self.init = true
    end

    local base = shapePos + up * 4.4 + at * 0.25
    local barScale = vec3(0.03, 0.0025, 0)
    local verticalScale, horizontalScale = 0.09 - barScale.y * 0.5, 0.11 - barScale.x * 0.5
    local verticalOffset, horizontalOffset = at * verticalScale, right * horizontalScale
    self.wgui.bar1:setPosition(base + verticalOffset + horizontalOffset)
    self.wgui.bar1:setRotation(shapeRot)
    self.wgui.bar1:setScale(barScale)

    self.wgui.bar2:setPosition(base + verticalOffset - horizontalOffset)
    self.wgui.bar2:setRotation(shapeRot)
    self.wgui.bar2:setScale(barScale)

    self.wgui.bar3:setPosition(base - verticalOffset + horizontalOffset)
    self.wgui.bar3:setRotation(shapeRot)
    self.wgui.bar3:setScale(barScale)

    self.wgui.bar4:setPosition(base - verticalOffset - horizontalOffset)
    self.wgui.bar4:setRotation(shapeRot)
    self.wgui.bar4:setScale(barScale)

    local angle = math.asin(up.z) * DIVRAD90
    local degreeOffset = verticalOffset * (angle == angle and angle or 0)
    self.wgui.bar5:setPosition(base - horizontalOffset + degreeOffset)
    self.wgui.bar5:setRotation(shapeRot)
    self.wgui.bar5:setScale(barScale)

    self.wgui.bar6:setPosition(base + horizontalOffset + degreeOffset)
    self.wgui.bar6:setRotation(shapeRot)
    self.wgui.bar6:setScale(barScale)

    self.wgui.bar7:setPosition(base)
    self.wgui.bar7:setRotation(shapeRot)
    self.wgui.bar7:setScale(barScale)

    self.wgui.bar8:setPosition(base)
    self.wgui.bar8:setRotation(shapeRot)
    self.wgui.bar8:setScale(vec3(barScale.y, barScale.x, 0))

    local sidebarOffset, sideBarScale = horizontalOffset + right * (barScale.x - barScale.y) * 0.5, vec3(barScale.y, verticalScale * 2, 0)
    self.wgui.bar9:setPosition(base - sidebarOffset)
    self.wgui.bar9:setRotation(shapeRot)
    self.wgui.bar9:setScale(sideBarScale)

    self.wgui.bar10:setPosition(base + sidebarOffset)
    self.wgui.bar10:setRotation(shapeRot)
    self.wgui.bar10:setScale(sideBarScale)

    if not self.wgui.bar1:isPlaying() then
        for i = 1, 10 do
            self.wgui["bar" .. i]:start()
        end
    end

    local healthCenter = base + right * 0.32
    local healthRotation = shapeRot * angleAxis(math.rad(45), VEC3_FORWARD)
    self.wgui.mainHealth:setPosition(healthCenter)
    self.wgui.mainHealth:setRotation(healthRotation)
    self.wgui.mainHealth:setScale(vec3(0.2, 0.75, 0) * 0.1)

    self.wgui.mainHealthText:setPosition(healthCenter + healthRotation * VEC3_FORWARD * 0.044)
    self.wgui.mainHealthText:setRotation(healthRotation)
    self.wgui.mainHealthText:setScale(VEC3_ONE * 0.011)
    self.wgui.mainHealthText:render()

    local uiEngineScale = vec3(0.01, 0.02, 0)
    local uiEngineRightOffset, uiEngineUpOffset = healthRotation * VEC3_RIGHT * 0.0175, healthRotation * VEC3_FORWARD * 0.025
    self.wgui.engine1Health:setPosition(healthCenter - uiEngineRightOffset + uiEngineUpOffset)
    self.wgui.engine1Health:setRotation(healthRotation)
    self.wgui.engine1Health:setScale(uiEngineScale)

    self.wgui.engine1HealthText:setPosition(healthCenter - uiEngineRightOffset * 2.3 + uiEngineUpOffset)
    self.wgui.engine1HealthText:setRotation(healthRotation)
    self.wgui.engine1HealthText:setScale(VEC3_ONE * 0.011)
    self.wgui.engine1HealthText:render()

    self.wgui.engine2Health:setPosition(healthCenter + uiEngineRightOffset + uiEngineUpOffset)
    self.wgui.engine2Health:setRotation(healthRotation)
    self.wgui.engine2Health:setScale(uiEngineScale)

    self.wgui.engine2HealthText:setPosition(healthCenter + uiEngineRightOffset * 2.92 + uiEngineUpOffset)
    self.wgui.engine2HealthText:setRotation(healthRotation)
    self.wgui.engine2HealthText:setScale(VEC3_ONE * 0.011)
    self.wgui.engine2HealthText:render()

    self.wgui.engine3Health:setPosition(healthCenter - uiEngineRightOffset - uiEngineUpOffset)
    self.wgui.engine3Health:setRotation(healthRotation)
    self.wgui.engine3Health:setScale(uiEngineScale)

    self.wgui.engine3HealthText:setPosition(healthCenter - uiEngineRightOffset * 2.3 - uiEngineUpOffset)
    self.wgui.engine3HealthText:setRotation(healthRotation)
    self.wgui.engine3HealthText:setScale(VEC3_ONE * 0.011)
    self.wgui.engine3HealthText:render()

    self.wgui.engine4Health:setPosition(healthCenter + uiEngineRightOffset - uiEngineUpOffset)
    self.wgui.engine4Health:setRotation(healthRotation)
    self.wgui.engine4Health:setScale(uiEngineScale)

    self.wgui.engine4HealthText:setPosition(healthCenter + uiEngineRightOffset * 2.92 - uiEngineUpOffset)
    self.wgui.engine4HealthText:setRotation(healthRotation)
    self.wgui.engine4HealthText:setScale(VEC3_ONE * 0.011)
    self.wgui.engine4HealthText:render()
end

function Gunship:cl_updateThrusters(dt)
    local downwards = 0.5 + (-math.asin(self.shape.up.z) / RAD90) * 0.5
    local forwards = (BoolToNum(self.cl_actions[3]) - BoolToNum(self.cl_actions[4])) * 0.5
    local offsetMultiplier = self.cl_actions[21] and 0.35 or 1
    local baseAnim = downwards - forwards * offsetMultiplier
    local rotation = -self.shape.body.angularVelocity.z * 0.1 * offsetMultiplier

    local animSpeed = dt * 2.5
    self.leftThrusterAnim = sm.util.lerp(self.leftThrusterAnim, baseAnim - rotation, animSpeed)
    self.rightThrusterAnim = sm.util.lerp(self.rightThrusterAnim, baseAnim + rotation, animSpeed)

    self.interactable:setAnimProgress("engine1_rotate", self.rightThrusterAnim)
    self.interactable:setAnimProgress("engine2_rotate", self.leftThrusterAnim)
    self.interactable:setAnimProgress("engine3_rotate", self.rightThrusterAnim)
    self.interactable:setAnimProgress("engine4_rotate", self.leftThrusterAnim)
end

local turretHorizontalMultiplier = 1 / math.pi * 0.5
local turretVerticalMultiplier = 1 / RAD90
function Gunship:cl_updateTurret(seatedChar, dt)
    local horizontal, vertical = 0, 0
    if seatedChar then
        local dir = seatedChar.direction
        local pos = self:GetCameraPosition(dt)
        local hit, result = sm.physics.raycast(pos, pos + dir * aimAssistRange, self.shape)
        if hit then
            -- local low, high = sm.projectile.solveBallisticArc(self:GetTurretFirePos(), result.pointWorld, autocannonVelocity, 10)
            -- if low and low:length2() > FLT_EPSILON then
            --     dir = low:normalize()
            -- end
            dir = (result.pointWorld - self:GetTurretFirePos()):normalize()
        end

        dir = self.shape:transformDirection(dir)

        horizontal = math.atan2(dir.x, dir.z)
        vertical = math.max(-math.asin(dir.y), 0) * turretVerticalMultiplier
    end

    local animSpeed = dt * turretTurnSpeed
    self.horizontalTurretAnim = sm.quat.slerp(self.horizontalTurretAnim, angleAxis(horizontal, VEC3_FORWARD), animSpeed)
    self.verticalTurretAnim = sm.util.lerp(self.verticalTurretAnim, vertical, animSpeed)

    self.interactable:setAnimProgress("turret_rotate_vertical", self.verticalTurretAnim)

    local dir = self.horizontalTurretAnim * VEC3_UP
    self.interactable:setAnimProgress("turret_rotate_horizontal", 0.5 - math.atan2(dir.x, dir.z) * turretHorizontalMultiplier)
end

function Gunship:cl_updateAction(args)
    if sm.localPlayer.getPlayer().character ~= self.interactable:getSeatCharacter() then
        self.cl_actions[args[1]] = args[2]
    end
end

function Gunship:cl_setTracerColour(colour)
    for i = 1, 2 do
        self.tracers[i].effect:setParameter("color", colour)
    end
    self.aimPoint:setParameter("color", colour)
end

function Gunship:cl_checkRocketInput(action, state)
    local cannon = self.interactable:getChildren(2 ^ 14)[1]
    if cannon and sm.GetInteractableClientPublicData(cannon --[[@as Interactable]]).hasRocket then
        self.network:sendToServer("sv_onRocketInput", { cannon = cannon, action = action, state = state })

        if state then
            return true
        end
    end

    return false
end

function Gunship:cl_onRocketFire()
    self.controllingRocket = true
    self.network:sendToServer("sv_onRocketFire")
    self.gui:close()
end

function Gunship:cl_onRocketExplode()
    self.controllingRocket = false
    self.network:sendToServer("sv_onRocketExplode")

    self.gui:open()
    sm.localPlayer.setLockedControls(true)
    sm.localPlayer.setDirection(self.shape.up)
    sm.event.sendToInteractable(self.interactable, "cl_onRocketExplodeEnd")
end

function Gunship:cl_onRocketExplodeEnd()
    sm.localPlayer.setLockedControls(false)
end

local shootEffects = {
    [0] = {
        "jnt_turret_firepos",
        "GunshipTurret - Shoot"
    },
    [1] = {
        "jnt_rocket1_firepos",
        "GunshipRockets - Shoot"
    },
    [2] = {
        "jnt_rocket2_firepos",
        "GunshipRockets - Shoot"
    }
}
function Gunship:cl_shoot(id)
    local effect = shootEffects[id]
    sm.effect.playHostedEffect(effect[2], self.interactable, effect[1], {
        offsetRotation = angleAxis(math.rad(-90), VEC3_RIGHT)
    })
end

function Gunship:cl_resetAction()
    for k, v in ipairs(actions) do
        self.cl_actions[k] = false
    end
end

function Gunship:cl_delayFade(delay)
    if delay > 0 then
        delay = delay - 1
        sm.event.sendToInteractable(self.interactable, "cl_delayFade", delay)
        return
    end

    sm.gui.endFadeToBlack(2)
end



function Gunship:GetCameraPosition(dt)
    -- return self.interactable:getWorldBonePosition("jnt_camera")
    -- return self.shape:getInterpolatedWorldPosition() + self.shape.velocity * (dt or (1/40)) - self.shape:getInterpolatedUp() * 10 + self.shape:getInterpolatedAt() * 2
    return
        self.shape:getInterpolatedWorldPosition() +
        self.shape.velocity * (dt or (1 / 40)) +
        self.shape:getInterpolatedUp() * 4 +
        self.shape:getInterpolatedAt() * 0.25
end

function Gunship:GetRocketFireData(start, dt)
    local firePos = start + self.shape.velocity * (dt or (1 / 40))
    local camPos = self:GetCameraPosition()
    local targetPos = camPos + self.shape:getInterpolatedUp() * aimAssistRange
    local hit, result = sm.physics.spherecast(camPos, targetPos, 0.15, self.shape, rayFilter)
    if hit then
        targetPos = result.pointWorld
    end

    local low, high = sm.projectile.solveBallisticArc(firePos, targetPos, rocketVelocity, 10)
    local fireDir
    if low and low:length2() > FLT_EPSILON then
        fireDir = low:normalize()
    else
        fireDir = self.shape:getInterpolatedUp()
    end

    return firePos, fireDir, targetPos
end

function Gunship:GetMoveDir()
    if self.sv_destroyed or self.cl_destroyed then
        return VEC3_ZERO
    end

    local _actions = self.sv_actions or self.cl_actions
    local at, up, right = self.shape.at, self.shape.up, self.shape.right
    return (
        at * (BoolToNum(_actions[21]) - BoolToNum(_actions[20])) +
        up * (BoolToNum(_actions[3]) - BoolToNum(_actions[4])) +
        right * (BoolToNum(_actions[1]) - BoolToNum(_actions[2]))
    ):safeNormalize(VEC3_ZERO)
end

function Gunship:GetBodyMass()
    local mass = 0
    for k, v in pairs(self.shape.body:getCreationBodies()) do
        mass = mass + v.mass
    end

    return mass
end

function Gunship:GetAccurateTransform(dt)
    dt = dt or (1 / 40)

    local angvel = self.shape.body.angularVelocity
    local interpolatedRot = sm.util.axesToQuat(self.shape:getInterpolatedRight(), self.shape:getInterpolatedUp())
    local angle = angvel:length() * dt * dt
    local axis = angvel:safeNormalize(VEC3_ZERO)
    local deltaRot = angleAxis(angle, axis)
    local shapeRot = deltaRot * interpolatedRot

    return
        self.shape:getInterpolatedWorldPosition() + self.shape.velocity * dt,
        shapeRot,
        shapeRot * VEC3_UP,
        shapeRot * VEC3_FORWARD,
        shapeRot * VEC3_RIGHT
end

function Gunship:SetBodyVisibility(state)
    self.interactable:setSubMeshVisible("Glass", state)
    -- self.interactable:setSubMeshVisible("Base", state)
    -- for i = 1, 4 do
    --     self.interactable:setSubMeshVisible("engine"..i, state)
    -- end
end

function Gunship:GetTurretDir()
    return (self.interactable:getWorldBonePosition("jnt_turret_firepos_end") - self:GetTurretFirePos()):normalize()
end

function Gunship:GetTurretFirePos()
    return self.interactable:getWorldBonePosition("jnt_turret_firepos")
end

function Gunship:GetLocalBoneDir(bone)
    return (self.interactable:getLocalBonePosition(bone.."_end") - self.interactable:getLocalBonePosition(bone)):normalize()
end

function Gunship:TransformLocalDirection(dir)
    return (self.shape:transformLocalPoint(dir) - self.shape.worldPosition):normalize()
end

function Gunship:GetDestructionResistence(uuid)
    if uuid == sm.uuid.getNil() then
        return 10
    end

    local destruction = GetProjectileData(uuid).destruction
    for k, v in reverse_ipairs(destruction) do
        if v > 0 then
            return k
        end
    end

    return 0
end

function Gunship:GetHealthColour(health, _maxHealth)
    if health > _maxHealth * 0.75 then
        return white
    elseif health > _maxHealth * 0.25 then
        return yellow
    elseif health > 0 then
        return red
    end

    return black, red
end

function Gunship:setClientData(data, channel)
    self.network:sendToClients("cl_onClientDataUpdate", { data, channel })
end