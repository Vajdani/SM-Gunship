dofile("$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua")

---@class ProjectileData
---@field destruction number[]
---@field effect string|EffectName

---@type ProjectileData[]
ProjectileLibrary = {}
local checkedProjectileSets = {}

local function ParseList(list)
    if not list then return end

    for i, projectile in pairs(list) do
		if type(projectile) ~= "table" then
			sm.log.error("PROJECITLESET CONTAINS INCORRECT INFORMATION")
			break
		end

		local destruction = {
			[1] = 0, [2] = 0,
			[3] = 0, [4] = 0,
			[5] = 0, [6] = 0,
			[7] = 0, [8] = 0,
			[9] = 0, [10] = 0
		}
		for k, v in pairs((projectile.destruction or {}).destructionLevels or {}) do
			destruction[v.qualityLevel] = v.chance
		end

		ProjectileLibrary[projectile.uuid] = {
			effect = projectile.effect,
			destruction = destruction
		}
    end
end

local function AddFromProjectileSet(projectileSet)
    if checkedProjectileSets[projectileSet] ~= nil then return end

	ParseList(projectileSet)

    checkedProjectileSets[projectileSet] = true
end

local function AddFromProjectileDB(projectileDB)
	local success, result = pcall(sm.json.open, projectileDB)
	if success then
		AddFromProjectileSet(result.projectiles)
	else
		sm.log.error("BROKEN PROJECTILE SET:", projectileDB)
	end
end

AddFromProjectileDB("$SURVIVAL_DATA/Projectiles/projectiles.json")
AddFromProjectileDB("$GAME_DATA/Projectiles/projectiles.json")
AddFromProjectileDB("$CHALLENGE_DATA/Projectiles/projectiles.json")
AddFromProjectileDB("$CONTENT_39a89fcb-db1d-43b6-b9c6-16dfab7027ba/Projectiles/projectiles.projectileset")

ModDatabase.loadShapesets()
for k, modId in pairs(ModDatabase.getAllLoadedMods(true)) do
	AddFromProjectileDB("$CONTENT_"..modId.."/Projectiles/projectiles.projectileset")
end
ModDatabase.unloadShapesets()



---Gets the projectile's data from the projectile library
---@param uuid Uuid
---@return ProjectileData
function GetProjectileData(uuid)
    return ProjectileLibrary[tostring(uuid)] or {
		destruction = {}
	}
end