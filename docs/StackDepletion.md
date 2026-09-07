# Stack Depletion

Source: EEex `function_names.db` (from PDB) + local `Baldur.exe` (FileVersion 2.6.6.0).

Image base (preferred): `0x140000000`. Runtime addresses = module base + RVA (ASLR).

## Key symbols (BG2EE / BGEE)

| Symbol | VA (PDB) | RVA |
|--------|----------|-----|
| `CItem::GetAbility` | `0x1401FB0D0` | `0x1FB0D0` |
| `CItem::GetMaxStackable` | `0x1401FB940` | `0x1FB940` |
| `CItem::GetUsageCount` | `0x1401FF4B0` | `0x1FF4B0` |
| `CItem::SetUsageCount` | `0x1402004B0` | `0x2004B0` |
| `CGameSprite::UseItem` | `0x1403BA8C0` | `0x3BA8C0` |
| `CGameSprite::UseItemPoint` | `0x1403BB9C0` | `0x3BB9C0` |
| `CMessageUseItemCharges::Run` | `0x140218EA0` | `0x218EA0` |

InfinityLoader already patterns `CItem::GetAbility` (`7535488B4B08`, `ADD -40`). Offsets from that label:

| Target | Offset from `CItem::GetAbility` |
|--------|----------------------------------|
| `GetMaxStackable` | `+0x870` |
| `GetUsageCount` | `+0x43E0` |
| `SetUsageCount` | `+0x53E0` |

IWDEE 2.6.6.0 uses different RVAs — not supported by this mod’s offset table.

## `CItem` usage fields (x64)

| Offset | Field |
|--------|-------|
| `0x18` | `m_nAbilities` |
| `0x1C` | `m_useCount1` (ability 0 / stack for stackables) |
| `0x1E` | `m_useCount2` (ability 1) |
| `0x20` | `m_useCount3` (ability 2) |

`Item_Header_st.maxStackable` @ `0x38`. Ability `maxUsageCount` @ header `0x22`, depletion @ `0x24`.

## Bug mechanism

`CItem::GetUsageCount` / `SetUsageCount`:

- Ability **0** + `GetMaxStackable() > 1` → read/write **`m_useCount1`** (stack).
- Ability **1 / 2** → always read/write **`m_useCount2` / `m_useCount3`**, ignoring max stack.

`CGameSprite::UseItem` depletes with:

```text
count = GetUsageCount(item, abilityIndex)
SetUsageCount(item, abilityIndex, count - 1)
```

Primary (ability 0) on a potion stack therefore decrements the stack. Secondary abilities decrement a separate charge field (often `1`); hitting zero triggers vanish and the **whole stack** disappears.

Call sites that hit this path include `UseItem` (`0x3BB8E9`), `UseItemPoint` (`0x3BC3C9`), and `CMessageUseItemCharges::Run` (`0x218F43`).

## Hook site

Entry of `GetUsageCount` and `SetUsageCount`: if `nAbility > 0` and `GetMaxStackable(this) > 1`, force `nAbility = 0` so secondary uses share the stack counter (IESDP stack-depletion rule).
