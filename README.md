# iiEngineExtensions

iiEngineExtensions is a Weidu mod for Baldur's Gate 2 Enhanced Edition, built on top of EEex, providing a couple of engine extensions.

Note: The creation of this mod relied heavily on AI.

## Requirements

- Baldur's Gate II: EE 2.6.6.0 (Win64)
- [EEex](https://github.com/Bubb13/EEex)

The engine extensions should work with Baldur’s Gate: EE, but they are untested.

## Install

1. Install EEex and confirm the game starts with InfinityLoader
2. Copy this package into the game directory (so the `iiEngineExtensions` folder sits next to `Baldur.exe`)
3. Run `setup-iiEngineExtensions.exe`
4. Start the game with InfinityLoader

## Components

### 1 - Fix: stackable secondary abilities deplete one from stack

Hooks `CItem::GetUsageCount` / `SetUsageCount` so secondary abilities on stackable items decrement the stack by one, instead of consuming the whole stack.

Console: `[iiEEexStackFix] Stackable secondary-ability deplete fix installed.`

Details: [docs/symbols-2.6.6.0.md](docs/symbols-2.6.6.0.md)


### 2 - Action: CentreCameraOn

Adds scripting action:

```
480 CentreCameraOn(O:Object*)
```

Appends to `ACTION.IDS` and `INSTANT.IDS` so script compilers recognise it.
Centres the camera on a global object, switching the visible area when the object is on another map.


```
IF
  Global("iiDemo","GLOBAL",1)
THEN
  RESPONSE #100
    SetGlobal("iiDemo","GLOBAL",2)
    MakeGlobal("my_beacon")
    MoveGlobalObject(Player1, "my_beacon")
    CentreCameraOn("my_beacon")
END
```

Details: [docs/CentreCameraOn.md](docs/CentreCameraOn.md)

Console: `[iiEEexCam] CentreCameraOn (action 480) installed.`

### 3 - Record: party area visit path

Hooks `CGameArea::OnActivation` and, when portrait 0 is in that area, appends the area resref to GLOBAL variables (`II_PATH_LEN`, `II_PATH_0`...).

Details: [docs/AreaVisitPath.md](docs/AreaVisitPath.md)

Console: `[iiEEexPath] Area visit path tracker installed (II_PATH_* globals).`

### 4 - Action: SetStoreFlag

Adds scripting action:

```
481 SetStoreFlag(S:Store*,I:Flag*Stoflag,I:SetReset*Boolean)
```

Sets or clears a bit in a store's header flags (e.g. disable drink sales with bit 6 / `DRINKS`), and marshals the STO so flag-only changes persist in save games.

```
SetStoreFlag("INN2616",DRINKS,FALSE)
```

This component also allows the INN store type to display the identify button.

Details: [docs/SetStoreFlag.md](docs/SetStoreFlag.md)

Console: `[iiEESetStoreFlag] SetStoreFlag (action 481) installed.`

### 5 - Action: SetStoreRooms

Adds scripting action:

```
482 SetStoreRooms(S:Store*,I:Room*Storeroom,I:SetReset*Boolean)
```

Sets or clears a bit in a store's room flags dword (`STO` offset `0x005c`, e.g. disable royal rooms with bit 3 / `ROYAL`), and marshals the STO so the change persists in save games.

```
SetStoreRooms("INN2616",ROYAL,FALSE)
```

Details: [docs/SetStoreRooms.md](docs/SetStoreRooms.md)

Console: `[iiEESetStoreRooms] SetStoreRooms (action 482) installed.`

### 6 - Action: StoreDrinks

Adds scripting actions:

```
483 AddStoreDrink(S:Store*,I:NameStrRef*,S:Rumour*,I:Alcohol*,I:Price*)
484 RemoveStoreDrink(S:Store*,I:NameStrRef*)
```

Adds or removes a drink entry in a store (rumour DLG, name strref, alcohol strength, price). Duplicate name strrefs are not added. Changes are marshaled so they persist in save games.

```
AddStoreDrink("INN2616",4098,"RUUMDR01",10,2)
RemoveStoreDrink("INN2616",4098)
```

Interacting with an unloaded store may cause a crash.

Details: [docs/StoreDrinks.md](docs/StoreDrinks.md)

Console: `[iiEEStoreDrinks] AddStoreDrink (483) / RemoveStoreDrink (484) installed.`

### 7 - Action: StoreLore

Adds scripting action:

```
485 SetStoreLore(S:Store*,I:Lore*)
```

Sets a store's lore value and marshals the STO so the change persists in save games.

```
SetStoreLore("INN2616",100)
```

Details: [docs/SetStoreLore.md](docs/SetStoreLore.md)

Console: `[iiEESetStoreLore] SetStoreLore (action 485) installed.`

### 8 - Action: RoomPrice

Adds scripting action:

```
486 SetRoomPrice(S:Store*,I:Room*Storeroom,I:Price*)
```

Sets a store room rental price (`PEASANT` / `MERCHANT` / `NOBLE` / `ROYAL` via `STOREROOM.IDS`) and marshals the STO so the change persists in save games.

```
SetRoomPrice("BERNARD",PEASANT,1)
SetRoomPrice("BERNARD",ROYAL,50)
```

Details: [docs/SetRoomPrice.md](docs/SetRoomPrice.md)

Console: `[iiEESetRoomPrice] SetRoomPrice (action 486) installed.`

### 9 - Trigger: StolenItemTrigger

Adds scripting trigger:

```
0x4111 HasStolenItem(O:Object*)
```

Returns true if the object is carrying any inventory item marked Stolen.

```
IF
  HasStolenItem(Player1)
THEN
  RESPONSE #100
    DisplayStringHead(Player1,1)
END
```

Details: [docs/HasStolenItem.md](docs/HasStolenItem.md)

Console: `[iiEEHasStolenItem] HasStolenItem (trigger 0x4111) installed.`


## Credit

- Bubb for EEex
- Beamdog for public EE debug symbols
- All contributors to the IESDP