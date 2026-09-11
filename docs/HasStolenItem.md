# HasStolenItem - TRIGGER.IDS 0x4111

## Synopsis

```
HasStolenItem(O:Object*)
```

Script trigger. Returns true if the resolved object is a creature (`CGameSprite`) that currently has at least one inventory item with the **Stolen** instance flag set.

## Parameters

| Param | Type | Meaning |
|-------|------|---------|
| Object | object | Creature to check (`Myself`, `Player1`, `"KORGAN8"`, etc.) |

## Example

```
IF
  HasStolenItem(Myself)
  SetGlobal("iiCaughtThief","GLOBAL",0)
THEN
  RESPONSE #100
    SetGlobal("iiCaughtThief","GLOBAL",1)
END
```

## Requirements

- EEex + InfinityLoader
- BGEE / BG2EE **2.6.6.0 Win64**
- Trigger ID **0x4111**

## Behaviour notes

- Resolves `Object` with the same `QuickDecode` path EEex uses for `EEex_HasDispellableEffect`.
- Scans all `CGameSprite` equipment slots (`m_equipment.m_items`, 39 slots).
- Tests `CItem.m_flags` bit **0x4** (`STOLEN`). This is the CRE inventory / instance flag described in the [IESDP CRE item table](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/cre_v1.htm) (Identified / Unstealable / **Stolen** / Magical), not an ITM file header flag from `itemflag.ids`.
- Non-sprite objects, missing objects, or empty inventories: returns false.
- Does **not** recurse into bag/container contents (Bag of Holding, etc.); only top-level inventory/equipment slots.