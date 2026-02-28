---@class MeleeCollision
---@field type 0|1
---@field size number|{ height: number, width: number }

---@class MeleeData
---@field collision number MeleeCollision
---@field destruction number[]
---@field effect string|EffectName

---@type MeleeData[]
MeleeLibrary = {}
local checkedMeeleSets = {}

local function ParseList(list)
    if not list then return end

    for i, attack in pairs(list) do
		if type(attack) ~= "table" then
			sm.log.error("MELEESET CONTAINS INCORRECT INFORMATION")
			break
		end

		local destruction = {
			[1] = 0, [2] = 0,
			[3] = 0, [4] = 0,
			[5] = 0, [6] = 0,
			[7] = 0, [8] = 0,
			[9] = 0, [10] = 0
		}
		for k, v in pairs((attack.destruction or {}).destructionLevels or {}) do
			destruction[v.qualityLevel] = v.chance
		end

		-- local col = {}
		-- if attack.hitSphere then
		-- 	col.type = 0
		-- 	col.size = attack.hitSphere.radius
		-- elseif attack.hitBox then
		-- 	col.type = 1
		-- 	col.size = sm.vec3.new(attack.hitBox.halfWidth * 2, attack.hitBox.halfWidth * 2, attack.hitBox.halfHeight * 2)
		-- else
		-- 	col.type = 0
		-- 	col.size = 1
		-- end

		local col = 0
		if attack.hitSphere then
			col = attack.hitSphere.radius
		elseif attack.hitBox then
			col = sm.vec3.new(attack.hitBox.halfWidth * 2, attack.hitBox.halfWidth * 2, attack.hitBox.halfHeight * 2):length()
		else
			col = 1
		end

		MeleeLibrary[attack.uuid] = {
			collision = col,
			effect = attack.impactEffect,
			destruction = destruction
		}
    end
end

local function AddFromMeleeSet(meleeSet)
    if checkedMeeleSets[meleeSet] ~= nil then return end

	ParseList(meleeSet)

    checkedMeeleSets[meleeSet] = true
end

local function AddFromMeleeDB(meeleDB)
	local success, result = pcall(sm.json.open, meeleDB)
	if success then
		AddFromMeleeSet(result.meleeAttacks)
	-- else
	-- 	sm.log.error("BROKEN MELEE SET:", meeleDB)
	end
end

AddFromMeleeDB("$SURVIVAL_DATA/Melee/attacks.json")
AddFromMeleeDB("$GAME_DATA/Melee/attacks.json")

function RegisterModInMeleeLibrary(modId)
	AddFromMeleeDB("$CONTENT_"..modId.."/MeleeAttacks/meleeattacks.meleeattackset")
end



---Gets the attack's data from the melee library
---@param uuid Uuid
---@return MeleeData
function GetMeleeData(uuid)
    return MeleeLibrary[tostring(uuid)] or {
		destruction = {}
	}
end