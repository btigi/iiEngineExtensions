-- iiEngineExtensions component: StoreDrinks
-- ACTION.IDS 483 AddStoreDrink(S:Store*,I:NameStrRef*,S:Rumour*,I:Alcohol*,I:Price*)
-- ACTION.IDS 484 RemoveStoreDrink(S:Store*,I:NameStrRef*)
-- Mutates the STO drinks array (CStore.m_pDrinks / m_nDrinks), then marshals so changes
-- persist in saves. Duplicate name strrefs are not added. Requires EEex + InfinityLoader.
-- Supported: BGEE / BG2EE 2.6.6.0 Win64 (RVAs relative to CItem::GetAbility).

(function()

	if not EEex_Active then
		error("[iiEEStoreDrinks] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	local ACTION_ADD = 483
	local ACTION_REMOVE = 484

	local OFF_CTOR_FROM_RESREF = 0x54170 -- CStore::CStore(CResRef&)
	local OFF_DTOR             = 0x54280 -- CStore::~CStore
	local OFF_INVALIDATE       = 0x550E0 -- CStore::InvalidateStore
	local OFF_MARSHAL          = 0x55260 -- CStore::Marshal
	local OFF_SET_RESREF       = 0x55540 -- CStore::SetResRef
	-- CStore::SetResRef allocates drinks via operator_new[](count*0x14) which thunks to operator_new.
	local OFF_NEW              = 0x2FB9D8 -- operator_new @ 0x4F6AA8 (GetAbility+off)
	-- Dtor frees drinks via operator_delete[] thunk target (0x45D6B0).
	local OFF_DELETE           = 0x2625E0 -- 0x45D6B0 - 0x1FB0D0

	-- CStore x64 drink array (from CStore::GetDrink / SetResRef load path)
	local OFF_PDRINKS = 0xE8
	local OFF_NDRINKS = 0xF0
	local DRINK_SIZE  = 0x14
	local OFF_DRINK_NAME = 0x08
	local OFF_DRINK_COST = 0x0C
	local OFF_DRINK_ALCOHOL = 0x10
	local MAX_DRINKS = 256

	local getAbility = EEex_TryLabel("CItem::GetAbility")
	if not getAbility then
		error("[iiEEStoreDrinks] Label CItem::GetAbility missing; unsupported EEex/game build.")
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
					"[iiEEStoreDrinks] Unexpected prologue at %s (%s): got %02X, expected %02X - unsupported build.",
					name, EEex_ToHex(addr), b, expected[i + 1]))
			end
		end
	end

	expectBytes(marshal, "CStore::Marshal", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(invalidate, "CStore::InvalidateStore", { 0x48, 0x83, 0xEC, 0x28 })
	expectBytes(ctorFromResRef, "CStore::CStore(CResRef&)", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(dtor, "CStore::~CStore", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(setResRef, "CStore::SetResRef", { 0x4C, 0x8B, 0xDC })

	if type(II_StDr_CallThis0) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StDr_CallThis0", {[[
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

	if type(II_StDr_CallThisPtr) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StDr_CallThisPtr", {[[
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

	if type(II_StDr_CallPtr) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StDr_CallPtr", {[[
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

	-- size_t -> void*  (engine drink alloc uses operator_new via new[] thunk)
	if type(II_StDr_Alloc) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StDr_Alloc", {[[
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

	-- void* -> void  (same free path CStore::~CStore uses for m_pDrinks)
	if type(II_StDr_Free) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StDr_Free", {[[
			#MAKE_SHADOW_SPACE(48)
			mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rbx

			mov rbx, rcx
			mov edx, 1
			#ALIGN
			call #L(luaL_checkinteger)
			#ALIGN_END

			test rax, rax
			jz ii_stdr_free_done
			mov rcx, rax
			#ALIGN
			call #$(1) ]], {opDelete}, [[ #ENDL
			#ALIGN_END

			ii_stdr_free_done:
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

	local function normalizeRumourResref(name)
		if type(name) ~= "string" then
			return ""
		end
		name = name:match("^%s*(.-)%s*$") or ""
		name = name:gsub("%.[dD][lL][gG]$", "")
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

	local function storePtr(store)
		return EEex_UDToPtr(store)
	end

	local function getDrinksPtr(store)
		return EEex_ReadPtr(storePtr(store) + OFF_PDRINKS)
	end

	local function getDrinkCount(store)
		-- Prefer raw offset used by CStore::GetDrink (avoid wrong Lua field bindings).
		local n = EEex_ReadU32(storePtr(store) + OFF_NDRINKS)
		if type(n) ~= "number" or n < 0 or n > MAX_DRINKS then
			return 0
		end
		return n
	end

	local function setDrinksPtrAndCount(store, drinksPtr, count)
		EEex_WritePtr(storePtr(store) + OFF_PDRINKS, drinksPtr or 0)
		EEex_WriteU32(storePtr(store) + OFF_NDRINKS, count)
		pcall(function()
			store.m_nDrinks = count
		end)
		pcall(function()
			if store.m_header ~= nil then
				store.m_header.m_drinkCount = count
			end
		end)
	end

	local function drinkNameAt(drinksPtr, index)
		return EEex_ReadU32(drinksPtr + index * DRINK_SIZE + OFF_DRINK_NAME)
	end

	local function findDrinkIndex(drinksPtr, count, nameStrref)
		if drinksPtr == 0 or count <= 0 then
			return -1
		end
		for i = 0, count - 1 do
			if drinkNameAt(drinksPtr, i) == nameStrref then
				return i
			end
		end
		return -1
	end

	local function writeDrink(drinksPtr, index, rumour, nameStrref, price, alcohol)
		local base = drinksPtr + index * DRINK_SIZE
		writeResref8(base, rumour)
		EEex_WriteU32(base + OFF_DRINK_NAME, nameStrref)
		EEex_WriteU32(base + OFF_DRINK_COST, price)
		EEex_WriteU32(base + OFF_DRINK_ALCOHOL, alcohol)
	end

	local function allocDrinks(count)
		if count <= 0 then
			return 0
		end
		local ptr = II_StDr_Alloc(count * DRINK_SIZE)
		if type(ptr) ~= "number" or ptr == 0 then
			return 0
		end
		return ptr
	end

	local function freeDrinks(ptr)
		if type(ptr) == "number" and ptr ~= 0 then
			II_StDr_Free(ptr)
		end
	end

	-- Swap in a new array. Free the previous block with the same path ~CStore uses.
	local function replaceDrinkArray(store, newPtr, newCount)
		local oldPtr = getDrinksPtr(store)
		setDrinksPtrAndCount(store, newPtr, newCount)
		if oldPtr ~= 0 and oldPtr ~= newPtr then
			freeDrinks(oldPtr)
		end
	end

	local function destroyStore(store)
		local ok = pcall(function()
			store:Destruct()
		end)
		if not ok then
			II_StDr_CallThis0(EEex_UDToPtr(store), dtor)
		end
		EEex_FreeUD(store)
	end

	local function marshalAndInvalidate(store, resref)
		local marshaled = pcall(function()
			store:Marshal()
		end)
		if not marshaled then
			II_StDr_CallThis0(EEex_UDToPtr(store), marshal)
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
			II_StDr_CallPtr(invalidate, EEex_UDToPtr(resref))
		end
	end

	local function loadStore(storeName, manager)
		local resref = manager:getUD("resref")
		local store = EEex_NewUD("CStore")

		local constructed = pcall(function()
			store:Construct(resref)
		end)
		if not constructed then
			II_StDr_CallThisPtr(EEex_UDToPtr(store), ctorFromResRef, EEex_UDToPtr(resref))
		end

		if resrefToString(store.m_resRef) == "" then
			II_StDr_CallThisPtr(EEex_UDToPtr(store), setResRef, EEex_UDToPtr(resref))
		end

		if resrefToString(store.m_resRef) == "" then
			destroyStore(store)
			return nil, nil
		end
		return store, resref
	end

	local function onAddStoreDrink(aiBase, curAction)
		local storeName = normalizeStoreResref(curAction.m_string1.m_pchData:get())
		local nameStrref = curAction.m_specificID
		local rumour = normalizeRumourResref(curAction.m_string2.m_pchData:get())
		local alcohol = curAction.m_specificID2
		local price = curAction.m_specificID3

		if storeName == "" or type(nameStrref) ~= "number" or type(alcohol) ~= "number" or type(price) ~= "number" then
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

			local oldPtr = getDrinksPtr(store)
			local oldCount = getDrinkCount(store)
			if findDrinkIndex(oldPtr, oldCount, nameStrref) >= 0 then
				destroyStore(store)
				success = true
				return
			end

			if oldCount >= MAX_DRINKS then
				destroyStore(store)
				return
			end

			local newCount = oldCount + 1
			local newPtr = allocDrinks(newCount)
			if newPtr == 0 then
				destroyStore(store)
				return
			end
			if oldPtr ~= 0 and oldCount > 0 then
				EEex_Memcpy(newPtr, oldPtr, oldCount * DRINK_SIZE)
			end
			writeDrink(newPtr, oldCount, rumour, nameStrref, price, alcohol)
			replaceDrinkArray(store, newPtr, newCount)

			marshalAndInvalidate(store, resref)
			-- Do not patch live in-memory store copies here: InvalidateStore is enough for
			-- the next open, and cloning/freeing live drink arrays was crashing silently.
			destroyStore(store)
			success = true
		end)

		if not success then
			return EEex_Action_ReturnType.ACTION_ERROR
		end
		return EEex_Action_ReturnType.ACTION_DONE
	end

	local function onRemoveStoreDrink(aiBase, curAction)
		local storeName = normalizeStoreResref(curAction.m_string1.m_pchData:get())
		local nameStrref = curAction.m_specificID

		if storeName == "" or type(nameStrref) ~= "number" then
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

			local oldPtr = getDrinksPtr(store)
			local oldCount = getDrinkCount(store)
			local idx = findDrinkIndex(oldPtr, oldCount, nameStrref)
			if idx < 0 then
				destroyStore(store)
				success = true
				return
			end

			local newCount = oldCount - 1
			local newPtr = 0
			if newCount > 0 then
				newPtr = allocDrinks(newCount)
				if newPtr == 0 then
					destroyStore(store)
					return
				end
				if idx > 0 then
					EEex_Memcpy(newPtr, oldPtr, idx * DRINK_SIZE)
				end
				if idx < oldCount - 1 then
					EEex_Memcpy(
						newPtr + idx * DRINK_SIZE,
						oldPtr + (idx + 1) * DRINK_SIZE,
						(oldCount - idx - 1) * DRINK_SIZE)
				end
			end
			replaceDrinkArray(store, newPtr, newCount)

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
			error("[iiEEStoreDrinks] EEex_Action_Private_Switch missing; install/update EEex.")
		end
		EEex_Action_Private_Switch[ACTION_ADD] = onAddStoreDrink
		EEex_Action_Private_Switch[ACTION_REMOVE] = onRemoveStoreDrink
		print("[iiEEStoreDrinks] AddStoreDrink (483) / RemoveStoreDrink (484) installed.")
	end

	if EEex_Action_Private_Switch ~= nil then
		install()
	elseif EEex_GameState_AddInitializedListener ~= nil then
		EEex_GameState_AddInitializedListener(install)
	else
		error("[iiEEStoreDrinks] Cannot register StoreDrinks actions; EEex action table not ready.")
	end

end)()
