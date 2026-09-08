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

	-- Mirror CScreenStore::StartStore button-panel wiring so flag changes while the
	-- store UI is open can show/hide Identify (and similar) without reopening.
	local function rebuildOpenStoreButtons(screen, store)
		if screen == nil or store == nil or store.m_header == nil then
			return
		end
		local flags = store.m_header.m_nStoreFlags
		local storeType = store.m_header.m_nStoreType
		if type(flags) ~= "number" or type(storeType) ~= "number" then
			return
		end

		local ids = { -1, -1, -1, -1 }
		local n = 0
		local function addButton(panelId)
			if n < 4 then
				n = n + 1
				ids[n] = panelId
			end
		end

		if storeType == 0 or storeType == 4 then
			addButton(2)
			if EEex_BAnd(flags, 0x4) ~= 0 then addButton(4) end
			if EEex_BAnd(flags, 0x20) ~= 0 then addButton(5) end
		elseif storeType == 1 then
			addButton(8)
			if EEex_BAnd(flags, 0x3) ~= 0 then addButton(2) end
			if EEex_BAnd(flags, 0x4) ~= 0 then addButton(4) end
		elseif storeType == 2 then
			-- Inn: vanilla StartStore never wires Identify (only Rooms / Buy-Sell / Drinks).
			-- Add Identify when bit 2 is set so SetStoreFlag can surface it on places like Copper Coronet.
			addButton(7)
			if EEex_BAnd(flags, 0x3) ~= 0 then addButton(2) end
			if EEex_BAnd(flags, 0x4) ~= 0 then addButton(4) end
			if EEex_BAnd(flags, 0x40) ~= 0 then addButton(8) end
		elseif storeType == 3 then
			addButton(5)
			if EEex_BAnd(flags, 0x3) ~= 0 then addButton(2) end
			if EEex_BAnd(flags, 0x4) ~= 0 then addButton(4) end
		elseif storeType == 5 then
			-- container / bag: no bottom service buttons
		else
			return
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

	-- Vanilla StartStore inn (type 2) wires Rooms / Buy-Sell / Drinks but never Identify.
	-- Do NOT HookBeforeRestore the drinks `jz` — relocating that relative branch crashes when
	-- drinks is clear (jz taken). Detour the whole drinks check with absolute continuations.
	local OFF_START_STORE = 0xE9B30
	local OFF_INN_DRINKS = 0x454 -- test bl, 40h ; jz after-buttons
	local OFF_AFTER_BUTTONS = 0x4FB -- mov dword [rsi+0x8FC], 1
	local startStore = getAbility + OFF_START_STORE
	local innDrinks = startStore + OFF_INN_DRINKS
	local afterButtons = startStore + OFF_AFTER_BUTTONS
	local innDrinksPattern = { 0xF6, 0xC3, 0x40, 0x0F, 0x84, 0x9E, 0x00, 0x00, 0x00 }
	if matchesBytes(innDrinks, innDrinksPattern) then
		EEex_DisableCodeProtection()
		local cave = EEex_JITNear({[[
			; bl = store flags, ecx = next button index, rsi = CScreenStore*
			test bl, 4
			jz ii_sto_inn_skip_identify
			mov dword ptr ds:[rsi+rcx*4+0x78C], 4
			inc ecx
			ii_sto_inn_skip_identify:
			test bl, 40h
			jz ii_sto_inn_done
			mov dword ptr ds:[rsi+rcx*4+0x78C], 8
			ii_sto_inn_done:
			jmp ]], afterButtons, [[ #ENDL
		]]})
		-- Replace test+jz (9 bytes) with jmp to cave; orphaned mov-drinks/jmp become dead.
		EEex_JITAt(innDrinks, {[[
			jmp ]], cave, [[ #ENDL
			nop
			nop
			nop
			nop
		]]})
		EEex_EnableCodeProtection()
	else
		print("[iiEESetStoreFlag] Warning: StartStore inn-drinks pattern mismatch at "
			.. EEex_ToHex(innDrinks) .. "; inn Identify button patch skipped.")
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
