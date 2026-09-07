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


## Credit

- Bubb for EEex
- Beamdog for public EE debug symbols
- All contributors to the IESDP