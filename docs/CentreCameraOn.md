# CentreCameraOn — ACTION.IDS 480

## Synopsis

```
CentreCameraOn(O:Object*)
```

Instant action. Resolves `Object`, switches the visible area to that object's loaded map if needed, then centres the viewport on the object's position.

## Intended teleport-marker pattern


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

`MoveGlobalObject` moves party members to the beacon; `CentreCameraOn` makes the camera follow even when the beacon started on another area (as long as that area is still loaded in the engine's area slots).

## Requirements

- EEex + InfinityLoader
- Target object must exist and have a **loaded** `m_pArea` (MakeGlobal markers that live on a visited/cached map qualify)
- Action ID **480** (EEex reserves 472–479)

## Behaviour notes

- Same-area: centres viewport on the object (instant).
- Other loaded area: mirrors the engine’s area switch — `CGameArea::OnDeactivation` on the old map, `CInfGame::SetVisibleArea` / `m_visibleArea` with the target’s `CGameArea.m_id`, then `CGameArea::OnActivation` on the new map — then centres the viewport. (Writing `m_visibleArea` alone does not change the displayed map.)
- Unloaded area / missing object: action errors (no-op from the script's point of view beyond failure).
