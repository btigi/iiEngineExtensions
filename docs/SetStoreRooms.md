# SetStoreRooms - ACTION.IDS 482

## Synopsis

```
SetStoreRooms(S:Store*,I:Room*Storeroom,I:SetReset*Boolean)
```

Instant action. Sets or clears one bit in the store room flags dword (`STO` offset `0x005c` / `CStore.m_header.m_nInnFlags`), then marshals the store so the change is written into the game temp tree and included in subsequent save games — even when inventory is unchanged.

## Parameters

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO filename (with or without `.STO`) |
| Room | 0–31 | Bit index in the room flags dword (`STOREROOM.IDS`) |
| SetReset | Boolean | `TRUE`/`1` set the bit; `FALSE`/`0` clear it |

## Room bits (`STOREROOM.IDS`)

| Bit | Name | Meaning |
|-----|------|---------|
| 0 | PEASANT | Peasant room available |
| 1 | MERCHANT | Merchant room available |
| 2 | NOBLE | Noble room available |
| 3 | ROYAL | Royal room available |

Bits 4–31 are accepted as raw integers but have no effect in-game.

## Example

Disable royal rooms at an inn after an event:

```
IF
  Global("iiNoRoyal","GLOBAL",1)
THEN
  RESPONSE #100
    SetGlobal("iiNoRoyal","GLOBAL",2)
    SetStoreRooms("INN2616",ROYAL,FALSE)
END
```

Equivalent with a raw bit index:

```
SetStoreRooms("INN2616",3,FALSE)
```

## Requirements

- EEex + InfinityLoader
- BGEE / BG2EE **2.6.6.0 Win64**
- Action ID **482**

## Behaviour notes

- Loads the store via `CStore`, toggles `m_header.m_nInnFlags`, calls `CStore::Marshal` (persists into temp for SAV packing), then `CStore::InvalidateStore`.
- Also updates any already-loaded live copies (`CInfGame.m_aServerStore` / open `CScreenStore` store or bag) so the UI reflects the change without a restart.
- When the store screen is open, refreshes the rent-room panel so room type availability updates immediately.
- Missing / unloadable store resref: action errors.
