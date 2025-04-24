vec3 = sm.vec3.new
getRotation = sm.vec3.getRotation
getGravity = sm.physics.getGravity
angleAxis = sm.quat.angleAxis

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
    return sm.quat.new(l * a.x, l * a.y, l * a.z, l * a.w);
end

oldQuatSLerp = oldQuatSLerp or sm.quat.slerp
---@diagnostic disable-next-line:duplicate-set-field
function sm.quat.slerp(q1, q2, t)
    return quat_normalise(oldQuatSLerp(q1, q2, t))
end

VEC3_RIGHT = vec3(1, 0, 0)
VEC3_FORWARD = vec3(0, 1, 0)
VEC3_UP = vec3(0, 0, 1)
VEC3_ZERO = sm.vec3.zero()
RAD90 = math.pi * 0.5
DIVRAD90 = 1 / RAD90



Line_tracer = class()
function Line_tracer:init(thickness, colour)
    self.effect = sm.effect.createEffect("ShapeRenderable")
    self.effect:setParameter("uuid", sm.uuid.new("7030b7b1-f0a1-4b24-bd0d-11d0a42185e6"))
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