-- iiEngineExtensions component: SetRoomPrice(S:Store*,I:Room*Storeroom,I:Price*)
-- ACTION.IDS 486 — sets a room rental price dword and marshals the store.
-- Room types (STOREROOM.IDS): 0 PEASANT, 1 MERCHANT, 2 NOBLE, 3 ROYAL
--   → STO offsets 0x0060 / 0x0064 / 0x0068 / 0x006c (CStore + same).
-- Requires EEex + InfinityLoader. BGEE/BG2EE 2.6.6.0 Win64.
--
-- Loads via CInfGame::DemandServerStore (engine path). Does not use EEex_NewUD("CStore"):
-- CStore has no Lua Construct, and JIT ctor/SetResRef on NewUD memory AVs.

(function()

	if not EEex_Active then
		error("[iiEESetRoomPrice] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	local ACTION_ID = 486

	local OFF_INVALIDATE    = 0x550E0 -- CStore::InvalidateStore
	local OFF_MARSHAL       = 0x55260 -- CStore::Marshal
	local OFF_DEMAND_STORE  = 0x775B0 -- CInfGame::DemandServerStore
	local OFF_RELEASE_STORE = 0x8A690 -- CInfGame::ReleaseServerStore

	-- Base peasant price; each room type is +4 bytes.
	local OFF_ROOM_PRICE_BASE = 0x60
	local ROOM_TYPE_MAX = 3

	local function dbg(msg)
		print("[iiEESetRoomPrice] " .. tostring(msg))
	end

	local getAbility = EEex_TryLabel("CItem::GetAbility")
	if not getAbility then
		error("[iiEESetRoomPrice] Label CItem::GetAbility missing; unsupported EEex/game build.")
	end

	local invalidate   = getAbility + OFF_INVALIDATE
	local marshal      = getAbility + OFF_MARSHAL
	local demandStore  = getAbility + OFF_DEMAND_STORE
	local releaseStore = getAbility + OFF_RELEASE_STORE

	local function expectBytes(addr, name, expected)
		for i = 0, #expected - 1 do
			local b = EEex_ReadU8(addr + i)
			if b ~= expected[i + 1] then
				error(string.format(
					"[iiEESetRoomPrice] Unexpected prologue at %s (%s): got %02X, expected %02X - unsupported build.",
					name, EEex_ToHex(addr), b, expected[i + 1]))
			end
		end
	end

	expectBytes(marshal, "CStore::Marshal", { 0x48, 0x89, 0x5C, 0x24, 0x08 })
	expectBytes(invalidate, "CStore::InvalidateStore", { 0x48, 0x83, 0xEC, 0x28 })

	if type(II_StRp_CallThis0) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StRp_CallThis0", {[[
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

	if type(II_StRp_CallThisPtr) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StRp_CallThisPtr", {[[
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

	if type(II_StRp_CallPtr) ~= "function" then
		EEex_JITNearAsLuaFunction("II_StRp_CallPtr", {[[
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

	local callThis0 = II_StRp_CallThis0
	local callThisPtr = II_StRp_CallThisPtr
	local callPtr = II_StRp_CallPtr

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

	local function storeNameOf(store)
		local ok, name = pcall(function()
			return resrefToString(store.m_resRef)
		end)
		return (ok and name) or ""
	end

	local function findServerStore(storeName)
		local chitin = EngineGlobals.g_pBaldurChitin
		if chitin == nil or chitin.m_pObjectGame == nil then
			return nil
		end
		local servers = chitin.m_pObjectGame.m_aServerStore
		if servers == nil then
			return nil
		end
		for i = 0, 11 do
			local live = nil
			pcall(function() live = servers:get(i) end)
			if live == nil then
				pcall(function() live = servers[i] end)
			end
			if live ~= nil and storeNameOf(live) == storeName then
				return live
			end
		end
		return nil
	end

	local function roomPriceOffset(roomType)
		return OFF_ROOM_PRICE_BASE + (roomType * 4)
	end

	local function setHeaderRoomPrice(header, roomType, price)
		if header == nil then
			return
		end
		if roomType == 0 then
			header.m_nRoomCostPeasant = price
		elseif roomType == 1 then
			header.m_nRoomCostMerchant = price
		elseif roomType == 2 then
			header.m_nRoomCostNoble = price
		elseif roomType == 3 then
			header.m_nRoomCostRoyal = price
		end
	end

	local function onSetRoomPrice(aiBase, curAction)
		local ok, result = pcall(function()
			dbg("enter")
			local storeName = normalizeStoreResref(curAction.m_string1.m_pchData:get())
			local roomType = curAction.m_specificID
			local price = curAction.m_specificID2
			dbg(string.format("args store=%s room=%s price=%s",
				tostring(storeName), tostring(roomType), tostring(price)))

			if storeName == ""
				or type(roomType) ~= "number" or roomType < 0 or roomType > ROOM_TYPE_MAX
				or type(price) ~= "number" or price < 0
			then
				return EEex_Action_ReturnType.ACTION_ERROR
			end

			local chitin = EngineGlobals.g_pBaldurChitin
			if chitin == nil or chitin.m_pObjectGame == nil then
				dbg("no game")
				return EEex_Action_ReturnType.ACTION_ERROR
			end
			local game = chitin.m_pObjectGame

			local success = false

			EEex_RunWithStackManager({
				{ ["name"] = "resref", ["struct"] = "CResRef", ["constructor"] = { ["args"] = { storeName } } },
			}, function(manager)
				local resref = manager:getUD("resref")
				local resrefPtr = EEex_UDToPtr(resref)
				local gamePtr = EEex_UDToPtr(game)

				local alreadyLoaded = findServerStore(storeName) ~= nil
				dbg("alreadyLoaded=" .. tostring(alreadyLoaded))

				if not alreadyLoaded then
					dbg("DemandServerStore...")
					callThisPtr(gamePtr, demandStore, resrefPtr)
					dbg("DemandServerStore done")
				end

				local store = findServerStore(storeName)
				if store == nil then
					dbg("store not in m_aServerStore")
					if not alreadyLoaded then
						callThisPtr(gamePtr, releaseStore, resrefPtr)
					end
					return
				end

				local off = roomPriceOffset(roomType)
				local before = EEex_ReadU32(EEex_UDToPtr(store) + off)
				EEex_WriteU32(EEex_UDToPtr(store) + off, price)
				pcall(function()
					setHeaderRoomPrice(store.m_header, roomType, price)
				end)
				dbg(string.format("room %d price %d -> %d (off=0x%X)", roomType, before, price, off))

				dbg("Marshal...")
				local marshaled = pcall(function() store:Marshal() end)
				if not marshaled then
					callThis0(EEex_UDToPtr(store), marshal)
				end

				dbg("Invalidate...")
				local invalidated = pcall(function() CStore.InvalidateStore(resref) end)
				if not invalidated then
					invalidated = pcall(function() CStore:InvalidateStore(resref) end)
				end
				if not invalidated then
					callPtr(invalidate, resrefPtr)
				end

				if not alreadyLoaded then
					dbg("ReleaseServerStore...")
					callThisPtr(gamePtr, releaseStore, resrefPtr)
				end

				dbg("ok")
				success = true
			end)

			if not success then
				return EEex_Action_ReturnType.ACTION_ERROR
			end
			return EEex_Action_ReturnType.ACTION_DONE
		end)

		if not ok then
			dbg("pcall error: " .. tostring(result))
			return EEex_Action_ReturnType.ACTION_ERROR
		end
		return result
	end

	local function install()
		if EEex_Action_Private_Switch == nil then
			error("[iiEESetRoomPrice] EEex_Action_Private_Switch missing; install/update EEex.")
		end
		EEex_Action_Private_Switch[ACTION_ID] = onSetRoomPrice
		dbg("installed")
		print("[iiEESetRoomPrice] SetRoomPrice (action " .. ACTION_ID .. ") installed.")
	end

	if EEex_Action_Private_Switch ~= nil then
		install()
	elseif EEex_GameState_AddInitializedListener ~= nil then
		EEex_GameState_AddInitializedListener(install)
	else
		error("[iiEESetRoomPrice] Cannot register SetRoomPrice; EEex action table not ready.")
	end

end)()
