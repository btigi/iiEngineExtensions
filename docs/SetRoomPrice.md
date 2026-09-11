# SetRoomPrice - ACTION.IDS 486

## Synopsis

```
SetRoomPrice(S:Store*,I:Room*Storeroom,I:Price*)
```

Instant action. Sets one room rental price dword on a store, then marshals the store so the change is written into the game temp tree and included in subsequent save games.

## Parameters

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO filename (with or without `.STO`) |
| Room | 0–3 | Room tier (`STOREROOM.IDS`) |
| Price | integer | New rental price in gold (`>= 0`) |

### Room types (`STOREROOM.IDS`)

| ID | Symbol | STO offset |
|----|--------|------------|
| 0 | `PEASANT` | `0x0060` |
| 1 | `MERCHANT` | `0x0064` |
| 2 | `NOBLE` | `0x0068` |
| 3 | `ROYAL` | `0x006c` |

Room prices are only meaningful for inn-type stores that offer rooms (`SetStoreRooms` / STO room flags). This component also installs `STOREROOM.IDS` so symbols such as `PEASANT` compile even if SetStoreRooms is not installed.

## Example

```
IF
  Global("iiCheapRooms","GLOBAL",1)
THEN
  RESPONSE #100
    SetGlobal("iiCheapRooms","GLOBAL",2)
    SetRoomPrice("BERNARD",PEASANT,1)
    SetRoomPrice("BERNARD",ROYAL,50)
END
```

## Requirements

- EEex + InfinityLoader
- BGEE / BG2EE **2.6.6.0 Win64**

## Behaviour notes

- Loads the store through the engine: `CInfGame::DemandServerStore` (unless that resref is already present in `CInfGame.m_aServerStore`), then finds the live `CStore` in `m_aServerStore`.
- Writes the selected room cost at `CStore+0x60 + roomType*4`, then `CStore::Marshal` and `CStore::InvalidateStore`.
- Calls `CInfGame::ReleaseServerStore` when this action was the one that demanded the store.
- Does **not** use `EEex_NewUD("CStore")` / native `CStore` construction.
- Does **not** refresh the open rent-room UI; reopen the store (or switch panels) to see the new price.
- Missing / unloadable store resref, room type outside 0–3, or negative price: action errors.