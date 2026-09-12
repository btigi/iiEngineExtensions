-- iiEngineExtensions component: StoreCures
-- ACTION.IDS 487 AddStoreCure(S:Store*,S:Spell*,I:Price*)
-- ACTION.IDS 488 RemoveStoreCure(S:Store*,S:Spell*)
-- Mutates the STO cures/spells array (CStore.m_pSpells / m_nSpells), then marshals so
-- changes persist in saves. Duplicate SPL resrefs are not added. Requires EEex + InfinityLoader.
-- Supported: BGEE / BG2EE 2.6.6.0 Win64 (RVAs relative to CItem::GetAbility).

(function()

	if not EEex_Active then
		error("[iiEEStoreCures] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	local ACTION_ADD = 487
	local ACTION_REMOVE = 488

	local OFF_CTOR_FROM_RESREF = 0x54170 -- CStore::CStore(CResRef&)
	local OFF_DTOR             = 0x54280 -- CStore::~CStore
	local OFF_INVALIDATE       = 0x550E0 -- CStore::InvalidateStore
	local OFF_MARSHAL          = 0x55260 -- CStore::Marshal
	local OFF_SET_RESREF       = 0x55540 -- CStore::SetResRef
	-- Same alloc/free path StoreDrinks validated (operator_new / operator_delete).
	local OFF_NEW              = 0x2FB9D8 -- operator_new @ 0x4F6AA8 (GetAbility+off)
	local OFF_DELETE           = 0x2625E0 -- 0x45D6B0 - 0x1FB0D0

	-- CStore x64 spells/cures array (from CStore::GetSpell)
	local OFF_PSPELLS = 0xF8
	local OFF_NSPELLS = 0x100
	local CURE_SIZE   = 0x0C
	local OFF_CURE_COST = 0x08
	local MAX_CURES = 256

	local getAbility = EEex_TryLabel("CItem::GetAbility")
	if not getAbility then
		error("[iiEEStoreCures] Label CItem::GetAbility missing; unsupported EEex/game build.")
	end

	local ctorFromResRef = getAbility + OFF_CTOR_FROM_RESREF
	local dtor           = getAbility + OFF_DTOR
	local invalidate     = getAbility + OFF_INVALIDATE
	local marshal        = getAbility + OFF_MARSHAL
	local setResRef      = getAbility + OFF_SET_RESREF
	local opNew          = getAbility + OFF_NEW
	local opDelete       = getAbility + OFF_DELETE

	local function expectBytes(addr, name, expected)
		for i = 0, #expected - 1 do
			local b = EEex_ReadU8(addr + i)
			if b ~= expected[i + 1] then
				error(string.format(
					"[iiEEStoreCures] Unexpected prologue at %s (%s): got %02X, expected %02X - unsupported build.",
					name, EEex_ToHex(addr), b, expected[i + 1]))
			end
		end
	end

	expectBytes(marshal, "CStore::Marshal", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(invalidate, "CStore::InvalidateStore", { 0x48, 0x83, 0xEC, 0x28 })
	expectBytes(ctorFromResRef, "CStore::CStore(CResRef&)", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(dtor, "CStore::~CStore", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(setResRef, "CStore::SetResRef", { 0x4C, 0x8B, 0xDC })

	if type(II_StCu_CallThis0) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StCu_CallThis0", {[[
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

	if type(II_StCu_CallThisPtr) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StCu_CallThisPtr", {[[
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

	if type(II_StCu_CallPtr) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StCu_CallPtr", {[[
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

	if type(II_StCu_Alloc) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StCu_Alloc", {[[
			#MAKE_SHADOW_SPACE(48)
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rbx

			mov rbx, rcx
			mov edx, 1
			#ALIGN
			call #L(luaL_checkinteger)
			#ALIGN_END

			mov rcx, rax
			#ALIGN
			call #$(1) ]], {opNew}, [[ #ENDL
			#ALIGN_END

			mov rdx, rax
			mov rcx, rbx
			#ALIGN
			call #L(Hardcoded_lua_pushinteger)
			#ALIGN_END

			mov eax, 1
			mov rbx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
			#DESTROY_SHADOW_SPACE
			ret
		]]})
	end

	if type(II_StCu_Free) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StCu_Free", {[[
			#MAKE_SHADOW_SPACE(48)
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rbx

			mov rbx, rcx
			mov edx, 1
			#ALIGN
			call #L(luaL_checkinteger)
			#ALIGN_END

			test rax, rax
			jz ii_stcu_free_done
			mov rcx, rax
			#ALIGN
			call #$(1) ]], {opDelete}, [[ #ENDL
			#ALIGN_END

			ii_stcu_free_done:
			xor eax, eax
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

	local function normalizeSpellResref(name)
		if type(name) ~= "string" then
			return ""
		end
		name = name:match("^%s*(.-)%s*$") or ""
		name = name:gsub("%.[sS][pP][lL]$", "")
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

	local function writeResref8(addr, name)
		for i = 0, 7 do
			EEex_WriteU8(addr + i, 0)
		end
		if type(name) ~= "string" then
			return
		end
		local n = math.min(8, #name)
		for i = 1, n do
			EEex_WriteU8(addr + i - 1, name:byte(i))
		end
	end

	local function readResref8(addr)
		local chars = {}
		for i = 0, 7 do
			local b = EEex_ReadU8(addr + i)
			if b == 0 then
				break
			end
			chars[#chars + 1] = string.char(b)
		end
		return table.concat(chars):upper()
	end

	local function storePtr(store)
		return EEex_UDToPtr(store)
	end

	local function getSpellsPtr(store)
		return EEex_ReadPtr(storePtr(store) + OFF_PSPELLS)
	end

	local function getSpellCount(store)
		local n = EEex_ReadU32(storePtr(store) + OFF_NSPELLS)
		if type(n) ~= "number" or n < 0 or n > MAX_CURES then
			return 0
		end
		return n
	end

	local function setSpellsPtrAndCount(store, spellsPtr, count)
		EEex_WritePtr(storePtr(store) + OFF_PSPELLS, spellsPtr or 0)
		EEex_WriteU32(storePtr(store) + OFF_NSPELLS, count)
		pcall(function()
			store.m_nSpells = count
		end)
		pcall(function()
			if store.m_header ~= nil then
				store.m_header.m_spellCount = count
			end
		end)
	end

	local function findCureIndex(spellsPtr, count, spellName)
		if spellsPtr == 0 or count <= 0 or spellName == "" then
			return -1
		end
		for i = 0, count - 1 do
			if readResref8(spellsPtr + i * CURE_SIZE) == spellName then
				return i
			end
		end
		return -1
	end

	local function writeCure(spellsPtr, index, spellName, price)
		local base = spellsPtr + index * CURE_SIZE
		writeResref8(base, spellName)
		EEex_WriteU32(base + OFF_CURE_COST, price)
	end

	local function allocCures(count)
		if count <= 0 then
			return 0
		end
		local ptr = II_StCu_Alloc(count * CURE_SIZE)
		if type(ptr) ~= "number" or ptr == 0 then
			return 0
		end
		return ptr
	end

	local function freeCures(ptr)
		if type(ptr) == "number" and ptr ~= 0 then
			II_StCu_Free(ptr)
		end
	end

	local function replaceCureArray(store, newPtr, newCount)
		local oldPtr = getSpellsPtr(store)
		setSpellsPtrAndCount(store, newPtr, newCount)
		if oldPtr ~= 0 and oldPtr ~= newPtr then
			freeCures(oldPtr)
		end
	end

	local function destroyStore(store)
		local ok = pcall(function()
			store:Destruct()
		end)
		if not ok then
			II_StCu_CallThis0(EEex_UDToPtr(store), dtor)
		end
		EEex_FreeUD(store)
	end

	local function marshalAndInvalidate(store, resref)
		local marshaled = pcall(function()
			store:Marshal()
		end)
		if not marshaled then
			II_StCu_CallThis0(EEex_UDToPtr(store), marshal)
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
			II_StCu_CallPtr(invalidate, EEex_UDToPtr(resref))
		end
	end

	local function loadStore(storeName, manager)
		local resref = manager:getUD("resref")
		local store = EEex_NewUD("CStore")

		local constructed = pcall(function()
			store:Construct(resref)
		end)
		if not constructed then
			II_StCu_CallThisPtr(EEex_UDToPtr(store), ctorFromResRef, EEex_UDToPtr(resref))
		end

		if resrefToString(store.m_resRef) == "" then
			II_StCu_CallThisPtr(EEex_UDToPtr(store), setResRef, EEex_UDToPtr(resref))
		end

		if resrefToString(store.m_resRef) == "" then
			destroyStore(store)
			return nil, nil
		end
		return store, resref
	end

	local function onAddStoreCure(aiBase, curAction)
		local storeName = normalizeStoreResref(curAction.m_string1.m_pchData:get())
		local spellName = normalizeSpellResref(curAction.m_string2.m_pchData:get())
		local price = curAction.m_specificID

		if storeName == "" or spellName == "" or type(price) ~= "number" then
			return EEex_Action_ReturnType.ACTION_ERROR
		end

		local success = false

		EEex_RunWithStackManager({
			{ ["name"] = "resref", ["struct"] = "CResRef", ["constructor"] = { ["args"] = { storeName } } },
		}, function(manager)
			local store, resref = loadStore(storeName, manager)
			if store == nil then
				return
			end

			local oldPtr = getSpellsPtr(store)
			local oldCount = getSpellCount(store)
			if findCureIndex(oldPtr, oldCount, spellName) >= 0 then
				destroyStore(store)
				success = true
				return
			end

			if oldCount >= MAX_CURES then
				destroyStore(store)
				return
			end

			local newCount = oldCount + 1
			local newPtr = allocCures(newCount)
			if newPtr == 0 then
				destroyStore(store)
				return
			end
			if oldPtr ~= 0 and oldCount > 0 then
				EEex_Memcpy(newPtr, oldPtr, oldCount * CURE_SIZE)
			end
			writeCure(newPtr, oldCount, spellName, price)
			replaceCureArray(store, newPtr, newCount)

			marshalAndInvalidate(store, resref)
			destroyStore(store)
			success = true
		end)

		if not success then
			return EEex_Action_ReturnType.ACTION_ERROR
		end
		return EEex_Action_ReturnType.ACTION_DONE
	end

	local function onRemoveStoreCure(aiBase, curAction)
		local storeName = normalizeStoreResref(curAction.m_string1.m_pchData:get())
		local spellName = normalizeSpellResref(curAction.m_string2.m_pchData:get())

		if storeName == "" or spellName == "" then
			return EEex_Action_ReturnType.ACTION_ERROR
		end

		local success = false

		EEex_RunWithStackManager({
			{ ["name"] = "resref", ["struct"] = "CResRef", ["constructor"] = { ["args"] = { storeName } } },
		}, function(manager)
			local store, resref = loadStore(storeName, manager)
			if store == nil then
				return
			end

			local oldPtr = getSpellsPtr(store)
			local oldCount = getSpellCount(store)
			local idx = findCureIndex(oldPtr, oldCount, spellName)
			if idx < 0 then
				destroyStore(store)
				success = true
				return
			end

			local newCount = oldCount - 1
			local newPtr = 0
			if newCount > 0 then
				newPtr = allocCures(newCount)
				if newPtr == 0 then
					destroyStore(store)
					return
				end
				if idx > 0 then
					EEex_Memcpy(newPtr, oldPtr, idx * CURE_SIZE)
				end
				if idx < oldCount - 1 then
					EEex_Memcpy(
						newPtr + idx * CURE_SIZE,
						oldPtr + (idx + 1) * CURE_SIZE,
						(oldCount - idx - 1) * CURE_SIZE)
				end
			end
			replaceCureArray(store, newPtr, newCount)

			marshalAndInvalidate(store, resref)
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
			error("[iiEEStoreCures] EEex_Action_Private_Switch missing; install/update EEex.")
		end
		EEex_Action_Private_Switch[ACTION_ADD] = onAddStoreCure
		EEex_Action_Private_Switch[ACTION_REMOVE] = onRemoveStoreCure
		print("[iiEEStoreCures] AddStoreCure (487) / RemoveStoreCure (488) installed.")
	end

	if EEex_Action_Private_Switch ~= nil then
		install()
	elseif EEex_GameState_AddInitializedListener ~= nil then
		EEex_GameState_AddInitializedListener(install)
	else
		error("[iiEEStoreCures] Cannot register StoreCures actions; EEex action table not ready.")
	end

end)()
