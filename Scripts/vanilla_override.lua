sm.log.warning("[GUNSHIP] OVERRIDE LOADING")

gunship_originalFuncs = gunship_originalFuncs or {}
for k, v in pairs(_G) do
	if type(v) ~= "table" then
		goto continue
	end

    if k == "BaseWorld" or ((v.cellMaxX or v.cellMaxY or v.cellMinX or v.cellMinY)) then
        function v:sv_e_onProjectile(args)
            self:server_onProjectile(
                args.position,
                args.airTime,
                args.velocity,
                args.projectileName,
                args.shooter,
                args.damage,
                args.customData,
                args.normal,
                args.target,
                args.uuid
            )
        end
    end

    ::continue::
end