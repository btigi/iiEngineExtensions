# Area visit path tracker (`II_PATH_*`)

## Synopsis

EEex hook on `CGameArea::OnActivation`. When the party’s leader (portrait 0) is in the area being activated, append that area’s resref to a growing GLOBAL list.

## Globals

| Variable | Type | Meaning |
|----------|------|---------|
| `II_PATH_LEN` | int | Number of recorded visits |
| `II_PATH_0` ... `II_PATH_<n-1>` | string | Area resrefs in visit order (repeats allowed) |
| `II_PATH_LAST` | string | Last recorded resref (dedup / reload guard) |

Example after visiting AR1000 → AR1001 → AR1001 → AR1020:

```
II_PATH_LEN  = 3
II_PATH_0    = AR1000
II_PATH_1    = AR1001
II_PATH_2    = AR1020
II_PATH_LAST = AR1020
```

(`AR1001` twice in a row is stored once; leaving and returning later appends again.)

## Behaviour notes

- Records only when **Player1 (portrait 0)** is in the activated area — camera-only switches do not append.
- Identical consecutive resref is skipped (save/load reactivation, redundant `OnActivation` calls).
- String globals are set via EEex (`EEex_GameState_SetGlobalString`); integer length via `SetGlobalInt`.
