# SetStoreFlag - ACTION.IDS 481

## Synopsis

```
SetStoreFlag(S:Store*,I:Flag*Stoflag,I:SetReset*Boolean)
```

Instant action. Sets or clears one bit in the store header flags dword (`STO` offset `0x0010` / `CStore.m_header.m_nStoreFlags`), then marshals the store so the change is written into the game temp tree and included in subsequent save games — even when inventory is unchanged.

## Parameters

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO filename (with or without `.STO`) |
| Flag | 0–31 | Bit index in the flags dword (`STOFLAG.IDS`) |
| SetReset | Boolean | `TRUE`/`1` set the bit; `FALSE`/`0` clear it |

## Flag bits (`STOFLAG.IDS`)

| Bit | Name | Meaning |
|-----|------|---------|
| 0 | BUY | User allowed to buy |
| 1 | SELL | User allowed to sell |
| 2 | IDENTIFY | User allowed to identify |
| 3 | STEAL | User allowed to steal |
| 4 | DONATE | User allowed to donate |
| 5 | CURES | User allowed to purchase cures |
| 6 | DRINKS | User allowed to purchase drinks |
| 9 | QUALITY1 | Tavern quality bit 1 |
| 10 | QUALITY2 | Tavern quality bit 2 |
| 12 | FENCE | Buy fenced goods |
| 13 | REPUTATION | Reputation does not affect prices (BGEE) |
| 14 | RECHARGE | Toggle item recharge (TobEx) |
| 15 | CRITICAL | User allowed to sell critical items (BGEE) |

Bits 7, 8, and 11 are unused/unknown in IESDP; 16–31 are accepted as raw integers.

## Example

Disable drink sales at an inn after an event:

```
IF
  Global("iiNoDrinks","GLOBAL",1)
THEN
  RESPONSE #100
    SetGlobal("iiNoDrinks","GLOBAL",2)
    SetStoreFlag("INN2616",DRINKS,FALSE)
END
```

Equivalent with a raw bit index:

```
SetStoreFlag("INN2616",6,FALSE)
```

## Requirements

- EEex + InfinityLoader
- BGEE / BG2EE **2.6.6.0 Win64**
- Action ID **481**

## Behaviour notes

- Loads the store via `CStore`, toggles `m_header.m_nStoreFlags`, calls `CStore::Marshal` (persists into temp for SAV packing), then `CStore::InvalidateStore`.
- Also updates any already-loaded live copies (`CInfGame.m_aServerStore` / open `CScreenStore` store or bag) so the UI reflects the change without a restart.
- When the store screen is open, rebuilds the bottom-button panel IDs from the new flags (so Identify can appear without closing the store) and refreshes the identify item list when bit 2 changes.
- Missing / unloadable store resref: action errors.

### Inn UI (Copper Coronet, etc.)

Vanilla `CScreenStore::StartStore` for store type **Inn** only wires Rooms / Buy-Sell / Drinks buttons — it never checks the identify flag, so Identify would never appear even when bit 2 is set in the STO.

This component hooks the end of `StartStore`’s button setup and rebuilds the bottom-button IDs so Inns also get Identify (panel 4) when bit 2 is set: Rooms, Buy-Sell, Identify, Drinks.