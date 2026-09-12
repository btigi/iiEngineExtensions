# StoreCures - ACTION.IDS 487 / 488

## Synopsis

```
AddStoreCure(S:Store*,S:Spell*,I:Price*)
RemoveStoreCure(S:Store*,S:Spell*)
```

Instant actions. Add or remove a cure (temple spell) entry in a store's cures array, then marshal the store so the change is written into the game temp tree and included in subsequent save games.

## Parameters

### AddStoreCure

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO filename (with or without `.STO`) |
| Spell | resref | SPL filename (with or without `.SPL`) |
| Price | integer | Cure price |

### RemoveStoreCure

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO filename (with or without `.STO`) |
| Spell | resref | SPL filename to remove (first match) |

## Cure record layout

| Offset | Field |
|--------|--------|
| `+0x00` | Spell resref (8 bytes) |
| `+0x08` | Price |

## Example

```
IF
  Global("iiNewCure","GLOBAL",1)
THEN
  RESPONSE #100
    SetGlobal("iiNewCure","GLOBAL",2)
    AddStoreCure("TEMPLE1","SPPR103",50)
END
```

Remove it later:

```
RemoveStoreCure("TEMPLE1","SPPR103")
```

## Requirements

- EEex + InfinityLoader
- BGEE / BG2EE **2.6.6.0 Win64**
- Action IDs **487** / **488**

## Behaviour notes

- Loads the store via `CStore`, mutates `m_pSpells` / `m_nSpells` (reallocating with the game allocator), calls `CStore::Marshal`, then `CStore::InvalidateStore`.
- **Add:** if a cure with the same SPL resref already exists, the action succeeds as a no-op (no duplicate).
- **Remove:** if no matching SPL is found, the action succeeds as a no-op.
- Missing / unloadable store resref: action errors.
- Re-open the store (or ensure it was not already loaded) after changing cures so the UI picks up the marshaled file.
