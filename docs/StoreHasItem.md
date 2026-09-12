# StoreHasItem - TRIGGER.IDS 0x4112

## Synopsis

```
StoreHasItem(S:Store*,S:Item*)
```

Script trigger. Returns true if the specified store (STO resource) currently has the specified item (ITM resource) in its items-for-sale list.

## Parameters

| Param | Type | Meaning |
|-------|------|---------|
| Store | resref | STO resource name (e.g. `"RIBALD"`, `"INN2616"`) |
| Item  | resref | ITM resource name (e.g. `"SWORD01"`, `"AMUL01"`) |

## Example

```
IF
  StoreHasItem("RIBALD","SW2H01")
THEN
  RESPONSE #100
    DisplayStringHead(Player1,1)
END
```

Check for an item across multiple stores:

```
IF
  OR(2)
    StoreHasItem("RIBALD","RING06")
    StoreHasItem("ARNOLINUS","RING06")
THEN
  RESPONSE #100
    SetGlobal("iiRingAvailable","GLOBAL",1)
END
```

## Requirements

- EEex + InfinityLoader
- BGEE / BG2EE **2.6.6.0 Win64**
- Trigger ID **0x4112**

## Behaviour notes

- Constructs a temporary `CStore` from the STO resref, walks the items-for-sale linked list (`CPtrList` at `CStore+0xA0`), and compares each item's resref against the specified ITM name.
- The comparison is **case-insensitive** (both resrefs are uppercased before matching).
- File extensions (`.STO`, `.ITM`) in the parameters are stripped automatically; pass bare resref names.
- Picks up save-game overrides: if the store was modified at runtime (e.g. items added/removed via other actions), the trigger sees the current state.
- If the STO resource cannot be loaded (e.g. invalid resref), the trigger returns **false** without error.
- The temporary `CStore` is destroyed after the check; the trigger does not keep stores open.
- A safety cap of 10 000 items prevents infinite loops on corrupt data.
