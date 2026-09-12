-- iiEngineExtensions component: StoreHasItem(S:Store*,S:Item*)
-- TRIGGER.IDS 0x4112 — true if the specified store file contains the specified
-- item for sale. Constructs a temporary CStore from the STO resref, walks the
-- items-for-sale linked list (CPtrList at CStore+0xA0), and checks for a
-- matching ITM resref. Requires EEex + InfinityLoader.
-- Supported: BGEE / BG2EE 2.6.6.0 Win64 (RVAs relative to CItem::GetAbility).

(function()

	if not EEex_Active then
		error("[iiEEStoreHasItem] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	local TRIGGER_ID = 0x4112

	-- CStore::* offsets from the CItem::GetAbility label (same approach as other iiEE store components).
	local OFF_CTOR_FROM_RESREF = 0x54170 -- CStore::CStore(CResRef&)
	local OFF_DTOR             = 0x54280 -- CStore::~CStore
	local OFF_SET_RESREF       = 0x55540 -- CStore::SetResRef

	-- Items-for-sale linked list inside CStore.
	-- CPtrList starts at CStore+0xA0; its m_pNodeHead is at CPtrList+0x08 = CStore+0xA8.
	-- Each CNode: pNext (+0x00), pPrev (+0x08), data (+0x10).
	-- Item data: CResRef at +0x00 (8 bytes, null-padded).
	local OFF_ITEM_LIST_HEAD = 0xA8

	local getAbility = EEex_TryLabel("CItem::GetAbility")
	if not getAbility then
		error("[iiEEStoreHasItem] Label CItem::GetAbility missing; unsupported EEex/game build.")
	end

	local ctorFromResRef = getAbility + OFF_CTOR_FROM_RESREF
	local dtor           = getAbility + OFF_DTOR
	local setResRef      = getAbility + OFF_SET_RESREF

	local function expectBytes(addr, name, expected)
		for i = 0, #expected - 1 do
			local b = EEex_ReadU8(addr + i)
			if b ~= expected[i + 1] then
				error(string.format(
					"[iiEEStoreHasItem] Unexpected prologue at %s (%s): got %02X, expected %02X - unsupported build.",
					name, EEex_ToHex(addr), b, expected[i + 1]))
			end
		end
	end

	expectBytes(ctorFromResRef, "CStore::CStore(CResRef&)", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(dtor, "CStore::~CStore", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(setResRef, "CStore::SetResRef", { 0x4C, 0x8B, 0xDC })

	---------------------------------------------------------------------------
	-- JIT helpers (shared with other iiEE store components — reuse if present)
	---------------------------------------------------------------------------

	-- void __fastcall f(this, func) → func(this)
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

	-- void __fastcall f(this, func, arg) → func(this, arg)
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

	---------------------------------------------------------------------------
	-- Helpers
	---------------------------------------------------------------------------

	local function dbg(msg)
		print("[iiEEStoreHasItem] " .. tostring(msg))
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

	local function normalizeResref(name)
		if type(name) ~= "string" then
			return ""
		end
		name = name:match("^%s*(.-)%s*$") or ""
		name = name:gsub("%.[sS][tT][oO]$", "")
		name = name:gsub("%.[iI][tT][mM]$", "")
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
			return normalizeResref(s)
		end
		return ""
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

	---------------------------------------------------------------------------
	-- Core: load store and scan its items-for-sale list
	---------------------------------------------------------------------------

	local function storeContainsItem(storeName, itemName)
		local found = false

		EEex_RunWithStackManager({
			{ ["name"] = "resref", ["struct"] = "CResRef", ["constructor"] = { ["args"] = { storeName } } },
		}, function(manager)
			local resref = manager:getUD("resref")
			local store = EEex_NewUD("CStore")

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

			local storePtr = EEex_UDToPtr(store)
			local node = EEex_ReadPtr(storePtr + OFF_ITEM_LIST_HEAD)
			local safety = 0

			while node ~= 0 and safety < 10000 do
				safety = safety + 1
				local itemData = EEex_ReadPtr(node + 0x10)
				if itemData ~= 0 then
					local ref = readResref8(itemData)
					if ref == itemName then
						found = true
						break
					end
				end
				node = EEex_ReadPtr(node)
			end

			destroyStore(store)
		end)

		return found
	end

	---------------------------------------------------------------------------
	-- Trigger handler
	---------------------------------------------------------------------------

	local function onStoreHasItem(aiBase, trigger)
		local ok, result = pcall(function()
			local storeName = normalizeResref(trigger.m_string1.m_pchData:get())
			local itemName  = normalizeResref(trigger.m_string2.m_pchData:get())
			if storeName == "" or itemName == "" then
				return false
			end
			return storeContainsItem(storeName, itemName)
		end)
		if not ok then
			dbg("error: " .. tostring(result))
			return false
		end
		return result and true or false
	end

	---------------------------------------------------------------------------
	-- Hook installation (chain onto EEex_Trigger_Hook_OnEvaluatingUnknown)
	---------------------------------------------------------------------------

	local function install()
		if type(EEex_Trigger_Hook_OnEvaluatingUnknown) ~= "function" then
			error("[iiEEStoreHasItem] EEex_Trigger_Hook_OnEvaluatingUnknown missing; install/update EEex.")
		end
		if rawget(_G, "iiEE_StoreHasItem_HookInstalled") then
			return
		end

		local previous = EEex_Trigger_Hook_OnEvaluatingUnknown
		function EEex_Trigger_Hook_OnEvaluatingUnknown(aiBase, trigger)
			if trigger.m_triggerID == TRIGGER_ID then
				return onStoreHasItem(aiBase, trigger)
			end
			return previous(aiBase, trigger)
		end

		_G.iiEE_StoreHasItem_HookInstalled = true
		dbg("StoreHasItem (trigger 0x4112) installed.")
	end

	if type(EEex_Trigger_Hook_OnEvaluatingUnknown) == "function" then
		install()
	elseif EEex_GameState_AddInitializedListener ~= nil then
		EEex_GameState_AddInitializedListener(install)
	else
		error("[iiEEStoreHasItem] Cannot register StoreHasItem; EEex trigger hook not ready.")
	end

end)()
