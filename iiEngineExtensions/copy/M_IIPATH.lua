-- iiEngineExtensions component: record party area visits into GLOBAL variables.
-- On each real area activation where Player1 is present, appends the area resref
-- to II_PATH_<n> and bumps II_PATH_LEN. Skips duplicates via II_PATH_LAST.
-- Requires EEex; start the game with InfinityLoader.exe.

(function()

	if not EEex_Active then
		error("[iiEEPartyPath] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	local LEN_VAR = "II_PATH_LEN"
	local LAST_VAR = "II_PATH_LAST"

	local function pathVarName(index)
		return string.format("II_PATH_%d", index)
	end

	-- Called from the OnActivation hook (rcx = CGameArea*).
	function II_Path_OnAreaActivated(area)
		if area == nil then
			return
		end

		local okRes, resref = pcall(function()
			return area.m_resref:get()
		end)
		if not okRes or resref == nil or resref == "" then
			return
		end
		-- CResRef may be padded; trim trailing nulls/spaces.
		resref = resref:match("^%s*(.-)%s*$") or resref
		resref = resref:gsub("%z", "")
		if resref == "" then
			return
		end

		-- Ignore camera-only / non-party activations (e.g. CentreCameraOn elsewhere).
		local p1 = EEex_Sprite_GetInPortrait(0)
		if p1 == nil or p1.m_pArea == nil or not EEex_UDEqual(p1.m_pArea, area) then
			return
		end

		local last = EEex_GameState_GetGlobalString(LAST_VAR)
		if last == resref then
			return
		end

		local len = EEex_GameState_GetGlobalInt(LEN_VAR)
		if type(len) ~= "number" or len < 0 then
			len = 0
		end

		EEex_GameState_SetGlobalString(pathVarName(len), resref)
		EEex_GameState_SetGlobalInt(LEN_VAR, len + 1)
		EEex_GameState_SetGlobalString(LAST_VAR, resref)
	end

	local onActivation = EEex_TryLabel("CGameArea::OnActivation")
	if not onActivation then
		error("[iiEEPartyPath] Label CGameArea::OnActivation missing; unsupported EEex/game build.")
	end

	-- Prologue: push rdi; push r14; push r15  (6 bytes on BGEE/BG2EE 2.6.6.0 x64).
	EEex_DisableCodeProtection()
	EEex_HookBeforeRestoreWithLabels(onActivation, 0, 6, 6, {
		{"stack_mod", 8},
		{"hook_integrity_watchdog_ignore_registers", {
			EEex_HookIntegrityWatchdogRegister.RAX,
			EEex_HookIntegrityWatchdogRegister.RDX,
			EEex_HookIntegrityWatchdogRegister.R8,
			EEex_HookIntegrityWatchdogRegister.R9,
			EEex_HookIntegrityWatchdogRegister.R10,
			EEex_HookIntegrityWatchdogRegister.R11,
		}},
	}, EEex_FlattenTable({
		{[[
			#MAKE_SHADOW_SPACE(48)
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rcx
		]]},
		EEex_GenLuaCall("II_Path_OnAreaActivated", {
			["args"] = {
				function(rspOffset)
					return {"mov qword ptr ss:[rsp+#$(1)], rcx #ENDL", {rspOffset}}, "CGameArea"
				end,
			},
		}),
		{[[
			call_error:
			mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
			#DESTROY_SHADOW_SPACE
		]]},
	}))
	EEex_EnableCodeProtection()

	print("[iiEEPartyPath] Area visit path tracker installed (II_PATH_* globals).")

end)()
