# SetStoreLore - ACTION.IDS 485

## Synopsis

```
SetStoreLore(S:Store*,I:Lore*)
```

Instant action. Sets the store lore dword (`STO` offset `0x003c` / `CStore.m_header.m_nLore`), then marshals the store so the change is written into the game temp tree and included in subsequent save games.

## Parameters

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO filename (with or without `.STO`) |
| Lore | integer | New lore value (`>= 0`) |

Store lore is compared against item lore when deciding whether the store can identify an item.

## Example

```
IF
  Global("iiHighLore","GLOBAL",1)
THEN
  RESPONSE #100
    SetGlobal("iiHighLore","GLOBAL",2)
    SetStoreLore("BERNARD",100)
END
```

## Requirements

- EEex + InfinityLoader
- BGEE / BG2EE **2.6.6.0 Win64**

## Behaviour notes

- Loads the store through the engine: `CInfGame::DemandServerStore` (unless that resref is already present in `CInfGame.m_aServerStore`), then finds the live `CStore` in `m_aServerStore`.
- Writes lore at `CStore+0x3C` (STO file `0x003c`), then `CStore::Marshal` and `CStore::InvalidateStore`.
- Calls `CInfGame::ReleaseServerStore` when this action was the one that demanded the store.
- Does **not** use `EEex_NewUD("CStore")` / native `CStore` construction. On this toolchain `CStore` has no Lua `Construct`, and JIT ctor / `SetResRef` on `NewUD` memory access-violates.
- Does **not** patch identify UI panels; reopen the store (or switch panels) if the open UI must rebuild identify lists.
- Missing / unloadable store resref, or negative lore: action errors.
- Independent of other iiEngineExtensions store components (owns its own `II_StLr_*` JIT helpers).
