# StoreDrinks - ACTION.IDS 483 / 484

## Synopsis

```
AddStoreDrink(S:Store*,I:NameStrRef*,S:Rumour*,I:Alcohol*,I:Price*)
RemoveStoreDrink(S:Store*,I:NameStrRef*)
```

Instant actions. Add or remove a drink entry in a store's drinks array, then marshal the store so the change is written into the game temp tree and included in subsequent save games.

## Parameters

### AddStoreDrink

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO filename (with or without `.STO`) |
| NameStrRef | integer | Drink name strref (duplicate strrefs are not added) |
| Rumour | resref | Rumour dialog resource (with or without `.DLG`) |
| Alcohol | integer | Alcoholic strength (IESDP drink `+0x10`) |
| Price | integer | Drink price (IESDP drink `+0x0C`) |

### RemoveStoreDrink

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO filename (with or without `.STO`) |
| NameStrRef | integer | Drink name strref to remove (first match) |

## Drink record layout

| Offset | Field |
|--------|--------|
| `+0x00` | Rumour resref (8 bytes) |
| `+0x08` | Name strref |
| `+0x0C` | Price |
| `+0x10` | Alcoholic strength |

## Example

```
IF
  Global("iiNewDrink","GLOBAL",1)
THEN
  RESPONSE #100
    SetGlobal("iiNewDrink","GLOBAL",2)
    AddStoreDrink("INN2616",4098,"RUUMDR01",10,2)
END
```

Remove it later:

```
RemoveStoreDrink("INN2616",4098)
```

## Requirements

- EEex + InfinityLoader
- BGEE / BG2EE **2.6.6.0 Win64**
- Action IDs **483** / **484**

## Behaviour notes

- Loads the store via `CStore`, mutates `m_pDrinks` / `m_nDrinks` (reallocating with the game `operator_new[]` / `operator_delete[]`), calls `CStore::Marshal`, then `CStore::InvalidateStore`.
- **Add:** if a drink with the same name strref already exists, the action succeeds as a no-op (no duplicate).
- **Remove:** if no matching strref is found, the action succeeds as a no-op.
- Live copies (`CInfGame.m_aServerStore` / open store or bag) are not mutated in place; `InvalidateStore` ensures the next open reloads the marshaled drinks.
- Re-open the store to see added/removed drinks in the UI.
- Missing / unloadable store resref: action errors.
