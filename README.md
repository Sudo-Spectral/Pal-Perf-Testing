# FPS Friendly Bases (UE4SS) - Palworld 1.0

Performance-leaning base FPS mod with a generated/editable `config.ini`.

## Install

Copy `FPSFriendlyBases` into:

`Palworld\Pal\Binaries\Win64\ue4ss\Mods\`

Then add to `mods.txt`:

`FPSFriendlyBases : 1`

## Config

On first run (or if missing), the mod writes `config.ini` next to `Scripts` with every value documented.

Edit `config.ini`, restart Palworld, and check `ue4ss\UE4SS.log` for `[FPSFriendlyBases ...]` lines.

## Notes

- No PalSchema required.
- Band count should match the game’s existing significance arrays; mismatched counts patch the overlapping bands only.
- Restart after config edits.
