sm.log.warning("[GUNSHIP] OVERRIDE LOADING")

gunship_originalFuncs = gunship_originalFuncs or {}
for k, v in pairs(_G) do
	if type(v) ~= "table" then
		goto continue
	end

    if k == "BaseWorld" or ((v.cellMaxX or v.cellMaxY or v.cellMinX or v.cellMinY) and not sm.GUNSHIP.World) then
        gunship_originalFuncs.server_onCreate = v.server_onCreate
        function v:server_onCreate()
            sm.GUNSHIP.World = self
            gunship_originalFuncs.server_onCreate(self)
        end
    end

    ::continue::
end