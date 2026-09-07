-- iiEEStackDepletion: secondary abilities on stackable items deplete one from the stack
-- (same as ability 0), instead of consuming the entire stack via a separate charge field.
-- Requires EEex; start the game with InfinityLoader.exe.
-- Supported: BGEE / BG2EE 2.6.6.0 Win64 (RVAs relative to CItem::GetAbility).

(function()

	if not EEex_Active then
		error("[iiEEStackDepletion] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	-- Offsets from CItem::GetAbility for BGEE/BG2EE v2.6.6.0 (see docs/symbols-2.6.6.0.md).
	local OFF_GET_MAX_STACKABLE = 0x870
	local OFF_GET_USAGE_COUNT   = 0x43E0
	local OFF_SET_USAGE_COUNT   = 0x53E0

	local getAbility = EEex_TryLabel("CItem::GetAbility")
	if not getAbility then
		error("[iiEEStackDepletion] Label CItem::GetAbility missing; unsupported EEex/game build.")
	end

	local getMaxStackable = getAbility + OFF_GET_MAX_STACKABLE
	local getUsageCount   = getAbility + OFF_GET_USAGE_COUNT
	local setUsageCount   = getAbility + OFF_SET_USAGE_COUNT

	-- mov qword ptr [rsp+8], rbx
	local function expectPrologue(addr, name)
		local b0, b1, b2, b3, b4 =
			EEex_ReadU8(addr), EEex_ReadU8(addr + 1), EEex_ReadU8(addr + 2),
			EEex_ReadU8(addr + 3), EEex_ReadU8(addr + 4)
		if b0 ~= 0x48 or b1 ~= 0x89 or b2 ~= 0x5C or b3 ~= 0x24 or b4 ~= 0x08 then
			error(string.format(
				"[iiEEStackDepletion] Unexpected prologue at %s (0x%X): %02X %02X %02X %02X %02X - unsupported build.",
				name, addr, b0, b1, b2, b3, b4))
		end
	end

	expectPrologue(getUsageCount, "CItem::GetUsageCount")
	expectPrologue(setUsageCount, "CItem::SetUsageCount")
	expectPrologue(getMaxStackable, "CItem::GetMaxStackable")

	-- At entry: rcx = CItem*, edx = nAbility [, r8w = new count for SetUsageCount].
	-- If nAbility > 0 and maxStackable > 1, force nAbility = 0 (stack field).
	local function installRemapHook(funcAddr)
		EEex_HookBeforeRestoreWithLabels(funcAddr, 0, 5, 5, {
			{"stack_mod", 8},
			{"hook_integrity_watchdog_ignore_registers", {
				EEex_HookIntegrityWatchdogRegister.RAX,
				EEex_HookIntegrityWatchdogRegister.R10,
				EEex_HookIntegrityWatchdogRegister.R11,
			}},
		}, EEex_FlattenTable({
			{[[
				#MAKE_SHADOW_SPACE(40)
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rcx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rdx
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], r8
				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r9

				test edx, edx
				jle ii_stkf_restore

				; rcx already this (CItem*)
				call #$(1) ]], {getMaxStackable}, [[ #ENDL
				cmp ax, 1
				jle ii_stkf_restore

				mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], 0

				ii_stkf_restore:
				mov r9, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
				mov r8, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
				mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
				mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
				#DESTROY_SHADOW_SPACE
			]]},
		}))
	end

	EEex_DisableCodeProtection()
	installRemapHook(getUsageCount)
	installRemapHook(setUsageCount)
	EEex_EnableCodeProtection()

	print("[iiEEStackDepletion] Stackable secondary-ability deplete fix installed.")

end)()
