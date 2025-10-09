---@diagnostic disable:lowercase-global

if not g_font then
    g_font = Font():init()
end

vec3 = sm.vec3.new
quat = sm.quat.new
uuid = sm.uuid.new
colour = sm.color.new
getRotation = sm.vec3.getRotation
getGravity = sm.physics.getGravity
angleAxis = sm.quat.angleAxis
axesToQuat = sm.util.axesToQuat
clamp = sm.util.clamp
lerp = sm.util.lerp
isServer = sm.isServerMode
random = math.random
serverTick = sm.game.getServerTick
applyImpulse = sm.physics.applyImpulse
applyTorque = sm.physics.applyTorque

function CalculateRightVector(vector)
    local yaw = math.atan2(vector.y, vector.x) - math.pi / 2
    return vec3(math.cos(yaw), math.sin(yaw), 0)
end

function BoolToNum(bool)
    return bool and 1 or 0
end

function quat_dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
end

function quat_normalise(a)
    local l = 1.0 / math.sqrt(quat_dot(a, a));
    return quat(l * a.x, l * a.y, l * a.z, l * a.w);
end

oldQuatSLerp = oldQuatSLerp or sm.quat.slerp
---@diagnostic disable-next-line:duplicate-set-field
function sm.quat.slerp(q1, q2, t)
    return quat_normalise(oldQuatSLerp(q1, q2, t))
end

function Count(table)
    local count = 0
    for k, v in pairs(table) do
        count = count + 1
    end

    return count
end

VEC3_RIGHT = vec3(1, 0, 0)
VEC3_FORWARD = vec3(0, 1, 0)
VEC3_UP = vec3(0, 0, 1)
VEC3_ZERO = sm.vec3.zero()
VEC3_ONE = sm.vec3.one()
VEC3_TENTH = VEC3_ONE * 0.1
RAD90 = math.pi * 0.5
RAD75 = math.rad(75)
RAD45 = math.pi * 0.25
RAD30 = math.pi / 6
DIVRAD90 = 1 / RAD90
ROT_UP180 = angleAxis(math.pi, VEC3_UP)

obj_marker = uuid("7030b7b1-f0a1-4b24-bd0d-11d0a42185e6")
obj_marker_border = uuid("37e13ac0-76f7-438c-b7fe-2149ffa19eb5")
obj_marker_dot = uuid("9162cf1b-b7c9-44d4-a1fb-092b4819fce0")
obj_marker_circle = uuid("eff6f314-1202-4f93-aeae-4a577a142ba3")
uuid_nil = sm.uuid.getNil()

Line_tracer = class()
function Line_tracer:init(thickness, colour)
    self.effect = sm.effect.createEffect("ShapeRenderable")
    self.effect:setParameter("uuid", uuid("7030b7b1-f0a1-4b24-bd0d-11d0a42185e6"))
    self.effect:setParameter("color", colour)
    self.effect:setScale(sm.vec3.one() * thickness)

    self.thickness = thickness

    return self
end

---@param startPos Vec3
---@param endPos Vec3
function Line_tracer:update(startPos, endPos)
    local delta = endPos - startPos
    local length = delta:length()

    if length < 0.0001 then
        --sm.log.warning("Line_tracer:update() | Length of 'endPos - startPos' must be longer than 0.")
        return
    end

    self.effect:setPosition(startPos + delta * 0.5)
    self.effect:setScale(vec3(self.thickness, self.thickness, length))
    self.effect:setRotation(getRotation(VEC3_UP, delta))

    if not self.effect:isPlaying() then
        self.effect:start()
    end
end

function Line_tracer:stop()
    if self.effect:isPlaying() then
        self.effect:stop()
    end
end

function Line_tracer:destroy()
    self.effect:destroy()
end



---@class Text3D
---@field effects Effect[]
---@field text string
Text3D = class()

local letterOffset = VEC3_UP * 0.1 + VEC3_RIGHT * 0.05
local defaultFontSize = 20

---@param length number
---@return Text3D
function Text3D:init(length, align)
    self.fontsize = defaultFontSize
    self.effects = {}
    for i = 1, length do
        -- local effect = sm.effect.createEffect("ShapeRenderable")
        -- effect:setParameter("uuid", obj_marker)
        local effect = sm.effect.createEffect("Text")
        effect:setParameter("FontName", "SM_Header")
        effect:setParameter("FontSize", self.fontsize)
        effect:setParameter("TextMaterial", "DifAsgNoShadow")
        effect:setParameter("Color", colour(1,1,1,1))

        self.effects[i] = effect
    end

    self.text = ""

    self.position = VEC3_ZERO
    self.rotation = sm.quat.identity()
    self.scale = VEC3_ONE
    self.align = align

    return self
end

---@return boolean
function Text3D:isPlaying()
    for k, v in pairs(self.effects) do
        if v:isPlaying() then
            return true
        end
    end

    return false
end

function Text3D:start()
    if self:isPlaying() then return end

    local length = #self.text
    for k, v in pairs(self.effects) do
        if k <= length then
            v:start()
        end
    end
end

function Text3D:stop()
    for k, v in pairs(self.effects) do
        v:stop()
    end
end

function Text3D:destroy()
    for k, v in pairs(self.effects) do
        v:destroy()
    end
end

---@param text string
function Text3D:update(text)
    local playing = self:isPlaying()
    self:stop()

    if #self.text == 0 then
        for i = 1, #self.effects do
            local current = text:sub(i, i)
            if current ~= "" then
                -- self.effects[i]:setParameter("uuid", uuid(g_font.Char2uuid[current]))
                self.effects[i]:setParameter("TextContent", current)
            end
        end
    else
        for i = 1, #self.effects do
            local current = text:sub(i, i)
            if current ~= "" and current ~= self.text:sub(i, i) then
                -- self.effects[i]:setParameter("uuid", uuid(g_font.Char2uuid[current]))
                self.effects[i]:setParameter("TextContent", current)
            end
        end
    end

    self.text = text

    if playing then
        self:start()
    end
end

function Text3D:setPosition(position)
    self.position = position
end

function Text3D:setRotation(rotation)
    self.rotation = rotation
end

function Text3D:setScale(scale)
    self.scale = scale

    for k, v in pairs(self.effects) do
        v:setScale(scale)
    end
end

function Text3D:setColour(colour)
    for k, v in pairs(self.effects) do
        v:setParameter("Color", colour)
    end
end

function Text3D:render()
    local position, rotation, scale = self.position, self.rotation, self.scale
    local fontRatio = self.fontsize/defaultFontSize
    position = position + rotation * letterOffset * scale * fontRatio

    local textLength = #self.text
    local dir = rotation * VEC3_RIGHT * max(scale:length(), 0.022) * 0.1 * fontRatio
    local half = 1
    if self.align == 2 then
        half = textLength
    elseif self.align == 3 then
        half = textLength * 0.5 + 0.5
    end

    for k, v in ipairs(self.effects) do
        if k <= textLength then
            v:setPosition(position - dir * (k - half) * 0.5)
            v:setRotation(rotation * ROT_UP180)
            v:setScale(scale)
        end
    end
end