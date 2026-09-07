-- iiEngineExtensions component: CentreCameraOn(O:Object*)
-- ACTION.IDS 480 — centres the viewport on a (typically MakeGlobal) object,
-- switching the visible area first when the object is on another loaded map.
-- Requires EEex; start the game with InfinityLoader.exe.

(function()

	if not EEex_Active then
		error("[iiEECentreCameraOn] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	-- Reserved third-party action ID (EEex uses 472-479).
	local ACTION_ID = 480

	-- Engine area switch uses CGameArea::OnDeactivation / CInfGame::SetVisibleArea /
	-- CGameArea::OnActivation. SetVisibleArea alone only stores m_visibleArea.
	local onActivation = EEex_TryLabel("CGameArea::OnActivation")
	local onDeactivation = EEex_TryLabel("CGameArea::OnDeactivation")
	if not onActivation or not onDeactivation then
		error("[iiEECentreCameraOn] Missing CGameArea::OnActivation/OnDeactivation labels; unsupported EEex/game build.")
	end

	-- lua_CFunction(thisPtr, funcPtr): call void __fastcall func(this).
	if type(II_Cam_CallThis0) ~= "function" then
		EEex_JITNearAsLuaFunction("II_Cam_CallThis0", {[[
			#MAKE_SHADOW_SPACE(48)
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rbx
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rsi

			mov rbx, rcx
			mov edx, 1
			#ALIGN
			call #L(luaL_checkinteger)
			#ALIGN_END
			mov rsi, rax

			mov edx, 2
			mov rcx, rbx
			#ALIGN
			call #L(luaL_checkinteger)
			#ALIGN_END

			mov rcx, rsi
			#ALIGN
			call rax
			#ALIGN_END

			xor eax, eax
			mov rsi, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
			mov rbx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
			#DESTROY_SHADOW_SPACE
			ret
		]]})
	end

	local function callAreaVoid(area, boundName, funcAddr)
		local ok = pcall(function()
			area[boundName](area)
		end)
		if ok then
			return true
		end
		II_Cam_CallThis0(EEex_UDToPtr(area), funcAddr)
		return true
	end

	local function findLoadedAreaIndex(game, area)
		-- Prefer CGameArea.m_id (slot id used by SetVisibleArea).
		local id = area.m_id
		if type(id) == "number" and id >= 0 and id <= 11 then
			local slot = game.m_gameAreas:get(id)
			if slot ~= nil and EEex_UDEqual(slot, area) then
				return id
			end
		end

		local areaPtr = EEex_UDToPtr(area)
		for i = 0, 11 do
			local slot = game.m_gameAreas:get(i)
			if slot ~= nil then
				if EEex_UDEqual(slot, area) or EEex_UDToPtr(slot) == areaPtr then
					return i
				end
			end
		end
		return nil
	end

	local function switchVisibleArea(game, area, areaIndex)
		local visible = game.m_visibleArea
		if visible == areaIndex then
			return
		end

		local oldArea = game.m_gameAreas:get(visible)
		if oldArea ~= nil then
			callAreaVoid(oldArea, "OnDeactivation", onDeactivation)
		end

		-- CInfGame::SetVisibleArea stores the area slot id (CGameArea.m_id).
		local newId = area.m_id
		if type(newId) ~= "number" then
			newId = areaIndex
		end
		local setOk = pcall(function()
			game:SetVisibleArea(newId)
		end)
		if not setOk then
			game.m_visibleArea = newId
		end

		-- Activate the area now referenced by m_visibleArea (engine pattern).
		local active = game.m_gameAreas:get(game.m_visibleArea)
		if active == nil then
			active = area
		end
		callAreaVoid(active, "OnActivation", onActivation)
	end

	local function centreInfinityOn(area, worldX, worldY)
		local inf = area.m_cInfinity
		local vp = inf.rViewPort
		local w = vp.right - vp.left
		local h = vp.bottom - vp.top
		if w <= 0 then w = 640 end
		if h <= 0 then h = 480 end

		local viewX = math.floor(worldX - (w / 2))
		local viewY = math.floor(worldY - (h / 2))

		if type(inf.nAreaX) == "number" and inf.nAreaX > 0 then
			viewX = math.max(0, math.min(viewX, math.max(0, inf.nAreaX - w)))
			viewY = math.max(0, math.min(viewY, math.max(0, inf.nAreaY - h)))
		end

		-- Prefer the real engine call when Lua bindings expose it.
		local ok = pcall(function()
			inf:SetViewPosition(viewX, viewY, 1)
		end)
		if ok then
			return
		end

		-- Fallback: mirror SetViewPosition's primary fields (instant).
		inf.nNewX = viewX
		inf.nNewY = viewY
		inf.nCurrentX = viewX
		inf.nCurrentY = viewY
	end

	local function onCentreCameraOn(aiBase, curAction)
		local target = aiBase:GetTargetShare()
		if target == nil then
			return EEex_Action_ReturnType.ACTION_ERROR
		end

		local area = target.m_pArea
		if area == nil then
			-- Object's area is not loaded; cannot display it.
			return EEex_Action_ReturnType.ACTION_ERROR
		end

		local game = EngineGlobals.g_pBaldurChitin.m_pObjectGame
		local areaIndex = findLoadedAreaIndex(game, area)
		if areaIndex == nil then
			return EEex_Action_ReturnType.ACTION_ERROR
		end

		switchVisibleArea(game, area, areaIndex)

		-- Prefer engine MoveViewObject (uses target pos + area infinity).
		local moved = pcall(function()
			aiBase:MoveViewObject(target)
		end)
		if not moved then
			local pos = target.m_pos
			centreInfinityOn(area, pos.x, pos.y)
		end

		return EEex_Action_ReturnType.ACTION_DONE
	end

	local function install()
		if EEex_Action_Private_Switch == nil then
			error("[iiEECentreCameraOn] EEex_Action_Private_Switch missing; install/update EEex.")
		end
		EEex_Action_Private_Switch[ACTION_ID] = onCentreCameraOn
		print("[iiEECentreCameraOn] CentreCameraOn (action " .. ACTION_ID .. ") installed.")
	end

	if EEex_Action_Private_Switch ~= nil then
		install()
	elseif EEex_GameState_AddInitializedListener ~= nil then
		EEex_GameState_AddInitializedListener(install)
	else
		error("[iiEECentreCameraOn] Cannot register CentreCameraOn; EEex action table not ready.")
	end

end)()
