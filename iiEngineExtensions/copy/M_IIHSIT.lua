-- iiEngineExtensions component: HasStolenItem(O:Object*)
-- TRIGGER.IDS 0x4111 — true if the resolved object is a sprite carrying any
-- inventory item with the STOLEN instance flag (INVITEM bit 2 / value 0x4;
-- CRE item flags per IESDP). Requires EEex + InfinityLoader.

(function()

	if not EEex_Active then
		error("[iiEEHasStolenItem] EEex not active.\n\nDid you forget to start the game with InfinityLoader.exe?")
	end

	-- Next free ID after EEex's 0x410D–0x4110 block.
	local TRIGGER_ID = 0x4111

	-- CItem.m_flags / CRE inventory flags (IESDP CRE items table).
	local FLAG_STOLEN = 0x4

	-- BG2EE sprite equipment array length (CGameSpriteEquipment::m_items).
	local NUM_SLOTS = 39

	local function dbg(msg)
		print("[iiEEHasStolenItem] " .. tostring(msg))
	end

	local function resolveSprite(aiBase, trigger)
		local sprite = nil
		local ok = pcall(function()
			EEex_RunWithStackManager({
				{ ["name"] = "pointer", ["struct"] = "Pointer<CGameSprite>" },
			}, function(manager)
				local pointer = manager:getUD("pointer")
				aiBase:virtual_QuickDecode(trigger, pointer)
				sprite = pointer.reference
			end)
		end)
		if not ok or sprite == nil then
			return nil
		end
		if not EEex_GameObject_IsSprite(sprite) then
			return nil
		end
		return sprite
	end

	local function itemIsStolen(item)
		if item == nil then
			return false
		end
		local ok, flags = pcall(function()
			return item.m_flags
		end)
		if not ok or type(flags) ~= "number" then
			return false
		end
		return EEex_BAnd(flags, FLAG_STOLEN) ~= 0
	end

	local function spriteHasStolenItem(sprite)
		local items = nil
		local ok = pcall(function()
			items = sprite.m_equipment.m_items
		end)
		if not ok or items == nil then
			return false
		end

		for slot = 0, NUM_SLOTS - 1 do
			local item = nil
			pcall(function()
				item = items:get(slot)
			end)
			if item == nil then
				pcall(function()
					item = items[slot]
				end)
			end
			if itemIsStolen(item) then
				return true
			end
		end
		return false
	end

	local function onHasStolenItem(aiBase, trigger)
		local ok, result = pcall(function()
			local sprite = resolveSprite(aiBase, trigger)
			if sprite == nil then
				return false
			end
			return spriteHasStolenItem(sprite)
		end)
		if not ok then
			dbg("error: " .. tostring(result))
			return false
		end
		return result and true or false
	end

	local function install()
		if type(EEex_Trigger_Hook_OnEvaluatingUnknown) ~= "function" then
			error("[iiEEHasStolenItem] EEex_Trigger_Hook_OnEvaluatingUnknown missing; install/update EEex.")
		end
		if rawget(_G, "iiEE_HasStolenItem_HookInstalled") then
			return
		end

		local previous = EEex_Trigger_Hook_OnEvaluatingUnknown
		function EEex_Trigger_Hook_OnEvaluatingUnknown(aiBase, trigger)
			if trigger.m_triggerID == TRIGGER_ID then
				return onHasStolenItem(aiBase, trigger)
			end
			return previous(aiBase, trigger)
		end

		_G.iiEE_HasStolenItem_HookInstalled = true
		dbg("HasStolenItem (trigger 0x4111) installed.")
		print("[iiEEHasStolenItem] HasStolenItem (trigger 0x4111) installed.")
	end

	if type(EEex_Trigger_Hook_OnEvaluatingUnknown) == "function" then
		install()
	elseif EEex_GameState_AddInitializedListener ~= nil then
		EEex_GameState_AddInitializedListener(install)
	else
		error("[iiEEHasStolenItem] Cannot register HasStolenItem; EEex trigger hook not ready.")
	end

end)()
