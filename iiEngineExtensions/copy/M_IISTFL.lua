-- iiEngineExtensions component: SetStoreFlag(S:Store*,I:Flag*Stoflag,I:SetReset*Boolean)
-- ACTION.IDS 481 — sets or clears a bit in the STO header flags dword (file offset 0x0010 /
-- CStore.m_header.m_nStoreFlags), then marshals the store so the change is packed into saves.
-- Requires EEex; start the game with InfinityLoader.exe.
-- Supported: BGEE / BG2EE 2.6.6.0 Win64 (RVAs relative to CItem::GetAbility).

(function()

	if not EEex_Active then
		error("[iiEESetStoreFlag] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	-- Reserved third-party action ID (EEex uses 472-479; this mod uses 480 for CentreCameraOn).
	local ACTION_ID = 481

	-- CStore::* is not in InfinityLoader's pattern DB; resolve via offsets from a labeled symbol
	-- (same approach as M_IISTKF). Values from EEex function_names.db for BG2EE 2.6.6.0.
	local OFF_CTOR_FROM_RESREF = 0x54170 -- CStore::CStore(CResRef&)
	local OFF_DTOR             = 0x54280 -- CStore::~CStore
	local OFF_INVALIDATE       = 0x550E0 -- CStore::InvalidateStore
	local OFF_MARSHAL          = 0x55260 -- CStore::Marshal
	local OFF_SET_RESREF       = 0x55540 -- CStore::SetResRef

	local getAbility = EEex_TryLabel("CItem::GetAbility")
	if not getAbility then
		error("[iiEESetStoreFlag] Label CItem::GetAbility missing; unsupported EEex/game build.")
	end

	local ctorFromResRef = getAbility + OFF_CTOR_FROM_RESREF
	local dtor           = getAbility + OFF_DTOR
	local invalidate     = getAbility + OFF_INVALIDATE
	local marshal        = getAbility + OFF_MARSHAL
	local setResRef      = getAbility + OFF_SET_RESREF

	local function expectBytes(addr, name, expected)
		for i = 0, #expected - 1 do
			local b = EEex_ReadU8(addr + i)
			if b ~= expected[i + 1] then
				error(string.format(
					"[iiEESetStoreFlag] Unexpected prologue at %s (%s): got %02X, expected %02X - unsupported build.",
					name, EEex_ToHex(addr), b, expected[i + 1]))
			end
		end
	end

	local function matchesBytes(addr, expected)
		for i = 0, #expected - 1 do
			if EEex_ReadU8(addr + i) ~= expected[i + 1] then
				return false
			end
		end
		return true
	end

	-- Spot-check prologues so a wrong build fails loudly instead of corrupting memory.
	expectBytes(marshal, "CStore::Marshal", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(invalidate, "CStore::InvalidateStore", { 0x48, 0x83, 0xEC, 0x28 })
	expectBytes(ctorFromResRef, "CStore::CStore(CResRef&)", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(dtor, "CStore::~CStore", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(setResRef, "CStore::SetResRef", { 0x4C, 0x8B, 0xDC })


	-- void __fastcall f(this)
	if type(II_Sto_CallThis0) ~= "function" then
		EEex_JITNearAsLuaFunction("II_Sto_CallThis0", {[[
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

	-- void __fastcall f(this, void* arg)
	if type(II_Sto_CallThisPtr) ~= "function" then
		EEex_JITNearAsLuaFunction("II_Sto_CallThisPtr", {[[
			#MAKE_SHADOW_SPACE(64)
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rbx
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rsi
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdi

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
			mov rdi, rax

			mov edx, 3
			mov rcx, rbx
			#ALIGN
			call #L(luaL_checkinteger)
			#ALIGN_END

			mov rcx, rsi
			mov rdx, rax
			mov rax, rdi
			#ALIGN
			call rax
			#ALIGN_END

			xor eax, eax
			mov rdi, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
			mov rsi, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
			mov rbx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
			#DESTROY_SHADOW_SPACE
			ret
		]]})
	end

	-- void f(void* arg) — static InvalidateStore(CResRef&)
	if type(II_Sto_CallPtr) ~= "function" then
		EEex_JITNearAsLuaFunction("II_Sto_CallPtr", {[[
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

			mov rcx, rax
			mov rax, rsi
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

	local function normalizeStoreResref(name)
		if type(name) ~= "string" then
			return ""
		end
		name = name:match("^%s*(.-)%s*$") or ""
		name = name:gsub("%.[sS][tT][oO]$", "")
		return name:upper()
	end

	local function resrefToString(resref)
		if resref == nil then
			return ""
		end
		local ok, s = pcall(function()
			return resref:get()
		end)
		if ok and type(s) == "string" then
			return normalizeStoreResref(s)
		end
		return ""
	end

	local function applyFlagBit(flags, bitIndex, setBit)
		-- EE Lua has no native bitwise ops; use EEex helpers.
		local mask = EEex_LShift(1, bitIndex)
		if setBit then
			return EEex_BOr(flags, mask)
		end
		return EEex_BAnd(flags, EEex_BNot(mask))
	end

	local function setHeaderFlag(header, bitIndex, setBit)
		if header == nil then
			return false
		end
		local flags = header.m_nStoreFlags
		if type(flags) ~= "number" then
			return false
		end
		header.m_nStoreFlags = applyFlagBit(flags, bitIndex, setBit)
		return true
	end

	-- Bottom-bar panel IDs (engine hard-caps at 4 slots).
	-- Offer order = keep priority; overflow drops Drinks first, then Cures.
	-- Rooms stay type-gated (inn); other services follow STOFLAG bits on any type.
	local PANEL_BUYSELL  = 2
	local PANEL_IDENTIFY = 4
	local PANEL_CURES    = 5
	local PANEL_ROOMS    = 7
	local PANEL_DRINKS   = 8
	local PANEL_DONATE   = 9 -- BG2EE: separate donate button (temple strip)

	local function removePanel(candidates, panelId)
		for i = #candidates, 1, -1 do
			if candidates[i] == panelId then
				table.remove(candidates, i)
				return true
			end
		end
		return false
	end

	local function rebuildOpenStoreButtons(screen, store)
		if screen == nil or store == nil or store.m_header == nil then
			return
		end
		local flags = store.m_header.m_nStoreFlags
		local storeType = store.m_header.m_nStoreType
		if type(flags) ~= "number" or type(storeType) ~= "number" then
			return
		end

		local candidates = {}
		local function offer(panelId)
			candidates[#candidates + 1] = panelId
		end

		-- Rooms: inn store type (enablement is SetStoreRooms / STO room data).
		if storeType == 2 then
			offer(PANEL_ROOMS)
		end
		if EEex_BAnd(flags, 0x3) ~= 0 then offer(PANEL_BUYSELL) end   -- BUY|SELL
		if EEex_BAnd(flags, 0x4) ~= 0 then offer(PANEL_IDENTIFY) end  -- IDENTIFY
		if EEex_BAnd(flags, 0x10) ~= 0 then offer(PANEL_DONATE) end   -- DONATE
		if EEex_BAnd(flags, 0x20) ~= 0 then offer(PANEL_CURES) end    -- CURES
		if EEex_BAnd(flags, 0x40) ~= 0 then offer(PANEL_DRINKS) end   -- DRINKS

		-- Engine only has 4 bottom buttons: drop Drinks, then Cures, then tail.
		if #candidates > 4 then
			removePanel(candidates, PANEL_DRINKS)
		end
		if #candidates > 4 then
			removePanel(candidates, PANEL_CURES)
		end
		while #candidates > 4 do
			table.remove(candidates)
		end

		local ids = { -1, -1, -1, -1 }
		for i = 1, #candidates do
			ids[i] = candidates[i]
		end

		local buttons = screen.m_adwButtonPanelId
		if buttons == nil then
			return
		end
		for i = 0, 3 do
			local ok = pcall(function()
				buttons:set(i, ids[i + 1])
			end)
			if not ok then
				pcall(function()
					buttons[i] = ids[i + 1]
				end)
			end
		end
	end

	local function refreshOpenStoreIdentify(screen)
		if screen == nil then
			return
		end
		-- Prefer bound methods; fall back to RVA from CItem::GetAbility (2.6.6.0).
		local ok = pcall(function()
			screen:UpdateIdentifyItems()
		end)
		if not ok then
			local updateIdentifyItems = getAbility + 0xEBE20 -- CScreenStore::UpdateIdentifyItems
			if matchesBytes(updateIdentifyItems, { 0x48, 0x89, 0x5C, 0x24, 0x08 }) then
				II_Sto_CallThis0(EEex_UDToPtr(screen), updateIdentifyItems)
			end
		end
		pcall(function()
			screen:UpdateIdentifyPanel()
		end)
		pcall(function()
			screen:UpdateMainPanel()
		end)
	end

	-- After StartStore finishes vanilla type-specific button wiring it hits
	-- `mov dword [this+0x8FC], 1`. Rebuild from STO flags there so any store type can
	-- show Identify / Donate / Cures / Drinks / Buy-Sell when the matching bits are set.
	-- Pure ASM only — GenLuaCall mid-StartStore silently access-violates on this build.
	-- Fill order matches Lua: Rooms, BuySell, Identify, Donate, Cures, Drinks (cap 4).
	local OFF_START_STORE = 0xE9B30
	local OFF_AFTER_BUTTONS = 0x4FB -- mov dword [rsi+0x8FC], 1
	local afterButtons = getAbility + OFF_START_STORE + OFF_AFTER_BUTTONS
	local afterButtonsPattern = { 0xC7, 0x86, 0xFC, 0x08, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00 }
	-- CScreenStore / CStore field offsets (BG2EE 2.6.6.0 x64), verified against StartStore.
	local OFF_BUTTONS = 0x78C -- m_adwButtonPanelId[4]
	local OFF_PSTORE  = 0x7A0 -- m_pStore
	local OFF_STYPE   = 0x08  -- CStore: store type
	local OFF_SFLAGS  = 0x10  -- CStore: store flags
	if matchesBytes(afterButtons, afterButtonsPattern) then
		EEex_DisableCodeProtection()
		EEex_HookBeforeRestoreWithLabels(afterButtons, 0, 10, 10, {
			{"stack_mod", 8},
			{"hook_integrity_watchdog_ignore_registers", {
				EEex_HookIntegrityWatchdogRegister.RAX,
				EEex_HookIntegrityWatchdogRegister.RCX,
				EEex_HookIntegrityWatchdogRegister.RDX,
				EEex_HookIntegrityWatchdogRegister.R8,
				EEex_HookIntegrityWatchdogRegister.R9,
				EEex_HookIntegrityWatchdogRegister.R10,
				EEex_HookIntegrityWatchdogRegister.R11,
			}},
		}, EEex_FlattenTable({
			{[[
			#MAKE_SHADOW_SPACE(40)
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rbx
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rcx
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], rdx

			; rsi = CScreenStore*
			mov rax, qword ptr ds:[rsi+#$(1)] ]], {OFF_PSTORE}, [[ #ENDL
			test rax, rax
			jz ii_sto_btns_done

			; clear four button slots
			mov dword ptr ds:[rsi+#$(1)], -1 ]], {OFF_BUTTONS}, [[ #ENDL
			mov dword ptr ds:[rsi+#$(1)], -1 ]], {OFF_BUTTONS + 4}, [[ #ENDL
			mov dword ptr ds:[rsi+#$(1)], -1 ]], {OFF_BUTTONS + 8}, [[ #ENDL
			mov dword ptr ds:[rsi+#$(1)], -1 ]], {OFF_BUTTONS + 12}, [[ #ENDL

			mov ebx, dword ptr ds:[rax+#$(1)] ]], {OFF_SFLAGS}, [[ #ENDL ; flags
			mov ecx, dword ptr ds:[rax+#$(1)] ]], {OFF_STYPE}, [[ #ENDL  ; type
			xor edx, edx ; next button index

			; Rooms (inn type 2)
			cmp ecx, 2
			jne ii_sto_btns_buysell
			mov dword ptr ds:[rsi+rdx*4+#$(1)], 7 ]], {OFF_BUTTONS}, [[ #ENDL
			inc edx

			ii_sto_btns_buysell:
			test ebx, 3
			jz ii_sto_btns_identify
			cmp edx, 4
			jge ii_sto_btns_done
			mov dword ptr ds:[rsi+rdx*4+#$(1)], 2 ]], {OFF_BUTTONS}, [[ #ENDL
			inc edx

			ii_sto_btns_identify:
			test ebx, 4
			jz ii_sto_btns_donate
			cmp edx, 4
			jge ii_sto_btns_done
			mov dword ptr ds:[rsi+rdx*4+#$(1)], 4 ]], {OFF_BUTTONS}, [[ #ENDL
			inc edx

			ii_sto_btns_donate:
			; DONATE bit 4 (0x10) -> panel 9
			test ebx, 10h
			jz ii_sto_btns_cures
			cmp edx, 4
			jge ii_sto_btns_done
			mov dword ptr ds:[rsi+rdx*4+#$(1)], 9 ]], {OFF_BUTTONS}, [[ #ENDL
			inc edx

			ii_sto_btns_cures:
			; after donate; skipped when edx >= 4 (drops cures before drinks)
			test ebx, 20h
			jz ii_sto_btns_drinks
			cmp edx, 4
			jge ii_sto_btns_done
			mov dword ptr ds:[rsi+rdx*4+#$(1)], 5 ]], {OFF_BUTTONS}, [[ #ENDL
			inc edx

			ii_sto_btns_drinks:
			; lowest priority — skipped first when edx >= 4
			test ebx, 40h
			jz ii_sto_btns_done
			cmp edx, 4
			jge ii_sto_btns_done
			mov dword ptr ds:[rsi+rdx*4+#$(1)], 8 ]], {OFF_BUTTONS}, [[ #ENDL

			ii_sto_btns_done:
			mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
			mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
			mov rbx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
			mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
			#DESTROY_SHADOW_SPACE
			]]},
		}))
		EEex_EnableCodeProtection()
	else
		print("[iiEESetStoreFlag] Warning: StartStore after-buttons pattern mismatch at "
			.. EEex_ToHex(afterButtons) .. "; flag-driven store buttons skipped.")
	end

	-- Kept for live SetStoreFlag while the store UI is already open (Lua-safe path).
	function II_Sto_FixStoreButtons(screen)
		if screen == nil then
			return
		end
		local store = screen.m_pStore
		if store ~= nil then
			rebuildOpenStoreButtons(screen, store)
		end
	end

	local function updateLiveStoreCopies(storeName, bitIndex, setBit)
		local chitin = EngineGlobals.g_pBaldurChitin
		if chitin == nil then
			return
		end

		local game = chitin.m_pObjectGame
		if game ~= nil then
			local servers = game.m_aServerStore
			if servers ~= nil then
				for i = 0, 11 do
					local live = nil
					local okGet = pcall(function()
						live = servers:get(i)
					end)
					if (not okGet) or live == nil then
						pcall(function()
							live = servers[i]
						end)
					end
					if live ~= nil and resrefToString(live.m_resRef) == storeName then
						setHeaderFlag(live.m_header, bitIndex, setBit)
					end
				end
			end
		end

		local screen = chitin.m_pEngineStore
		if screen == nil then
			pcall(function()
				screen = chitin:GetEngineStore()
			end)
		end
		if screen ~= nil then
			local openStore = screen.m_pStore
			if openStore ~= nil and resrefToString(openStore.m_resRef) == storeName then
				setHeaderFlag(openStore.m_header, bitIndex, setBit)
				rebuildOpenStoreButtons(screen, openStore)
				if bitIndex == 2 then
					refreshOpenStoreIdentify(screen)
				else
					pcall(function()
						screen:UpdateMainPanel()
					end)
				end
			end
			local openBag = screen.m_pBag
			if openBag ~= nil and resrefToString(openBag.m_resRef) == storeName then
				setHeaderFlag(openBag.m_header, bitIndex, setBit)
			end
		end
	end

	local function destroyStore(store)
		local ok = pcall(function()
			store:Destruct()
		end)
		if not ok then
			II_Sto_CallThis0(EEex_UDToPtr(store), dtor)
		end
		EEex_FreeUD(store)
	end

	local function onSetStoreFlag(aiBase, curAction)
		local storeName = normalizeStoreResref(curAction.m_string1.m_pchData:get())
		local bitIndex = curAction.m_specificID
		local setBit = curAction.m_specificID2 ~= 0

		if storeName == "" or type(bitIndex) ~= "number" or bitIndex < 0 or bitIndex > 31 then
			return EEex_Action_ReturnType.ACTION_ERROR
		end

		local success = false

		EEex_RunWithStackManager({
			{ ["name"] = "resref", ["struct"] = "CResRef", ["constructor"] = { ["args"] = { storeName } } },
		}, function(manager)
			local resref = manager:getUD("resref")
			local store = EEex_NewUD("CStore")

			-- Construct CStore(resref); fall back to SetResRef if Lua Construct is unbound/wrong.
			local constructed = pcall(function()
				store:Construct(resref)
			end)
			if not constructed then
				II_Sto_CallThisPtr(EEex_UDToPtr(store), ctorFromResRef, EEex_UDToPtr(resref))
			end

			if resrefToString(store.m_resRef) == "" then
				II_Sto_CallThisPtr(EEex_UDToPtr(store), setResRef, EEex_UDToPtr(resref))
			end

			if resrefToString(store.m_resRef) == "" then
				destroyStore(store)
				return
			end

			if not setHeaderFlag(store.m_header, bitIndex, setBit) then
				destroyStore(store)
				return
			end

			local marshaled = pcall(function()
				store:Marshal()
			end)
			if not marshaled then
				II_Sto_CallThis0(EEex_UDToPtr(store), marshal)
			end

			local invalidated = pcall(function()
				CStore.InvalidateStore(resref)
			end)
			if not invalidated then
				invalidated = pcall(function()
					CStore:InvalidateStore(resref)
				end)
			end
			if not invalidated then
				II_Sto_CallPtr(invalidate, EEex_UDToPtr(resref))
			end

			updateLiveStoreCopies(storeName, bitIndex, setBit)
			destroyStore(store)
			success = true
		end)

		if not success then
			return EEex_Action_ReturnType.ACTION_ERROR
		end
		return EEex_Action_ReturnType.ACTION_DONE
	end

	local function install()
		if EEex_Action_Private_Switch == nil then
			error("[iiEESetStoreFlag] EEex_Action_Private_Switch missing; install/update EEex.")
		end
		EEex_Action_Private_Switch[ACTION_ID] = onSetStoreFlag
		print("[iiEESetStoreFlag] SetStoreFlag (action " .. ACTION_ID .. ") installed.")
	end

	if EEex_Action_Private_Switch ~= nil then
		install()
	elseif EEex_GameState_AddInitializedListener ~= nil then
		EEex_GameState_AddInitializedListener(install)
	else
		error("[iiEESetStoreFlag] Cannot register SetStoreFlag; EEex action table not ready.")
	end

end)()
