# Batch 1 - Rebuild Ladder K0 + K1 + K2a

Batch 1 of the rebuild (Rebuild Blueprint, Chapter 7), delivered as a
testable tree instead of commits, per instruction: nothing below has been
pushed or committed anywhere. Test it locally; when it passes on your
machine, apply the commit series at the bottom and push.

Status at packaging time: `godot --headless --path . res://tests/smoke.tscn`
ends **SMOKE: ALL PASS** (7 domains, 50 checks) on Godot 4.7, and the
reference-still round-trip reports `REF: MATCH` on repeat runs.

## What this batch does

- **K0 - pin the baseline, purge the debris.** The four orphans the audit
  named are gone, each proven unreferenced by grep before deletion:
  `assets_src/gen_ps1_textures.py` (the stale second generator),
  `assets/tex/pi_hat.png` and `assets/tex/phone_ring.png` (sheets the
  November lean-out retired; the current `gen_textures.py` no longer
  produces either), and the root `level_builder.gd.uid` (a UID with no
  matching script). The `pre-rebuild-110e437` tag and `rebuild/R0` branch
  are left for you to cut when you commit (see below).
- **K1 - the frame becomes contract law.** The smoke suite gained a THE
  FRAME domain: the canvas samples nearest and is 640x360, `ps1_post` is
  the terminal pass on the office tube, every one of the 180 meshes in the
  office wears `ps1_mat` with `snap_grid` at 240x135 and `affine` on, and
  the menu sits behind the `crt_menu` tube. `capture.tscn` gained
  `--ref=save / --ref=check`: it pins a committed reference still
  (`tests/ref/office_ref.png`) and diffs against it forever after, exit 2
  on drift. Animated layers are pinned too: `--clock` freezes the room
  clock (`qa_clock` on office.gd), and the still is captured with
  `--strip=grain` because film grain is animated by design.
- **K2a - the silence dies.** `assets_src/gen_sfx.py` synthesizes the
  first sound set into `audio/` under the code-generated law: a seamless
  room-tone loop, the fan's blade-pass loop, radio static, three iron
  footstep variants and the shelf creak. The office wires them: room tone
  on the air from `_ready`, the fan loop's pitch and level riding
  `fan_speed`, radio crackle on the new `Ambient.radio_cue`, the creak on
  `shelf_drop`, and footsteps on a new stride-beat `footstep` signal from
  the PI. The extractor fan is now a machine: a seeded run / sputter /
  stall / kick cycle with visible blade speed, walked end-to-end by the
  smoke suite's THE SOUND domain.

## What was verified, and how

1. `godot --headless --path . --import` - clean.
2. `godot --headless --path . res://tests/smoke.tscn` - ends
   `SMOKE: ALL PASS`; the run also exits clean (the audio bus stops in
   `office._exit_tree()` so no mix playbacks leak at shutdown).
3. Reference round-trip under a virtual display (software GL):
   `--seed=7 --clock=3.7 --strip=grain --ref=save` then two `--ref=check`
   runs - both `REF: MATCH` at 0.18% / 0.30% drifted pixels.

## How to test locally

```sh
cd red-harbor                # this tree
godot --headless --path . --import
godot --headless --path . res://tests/smoke.tscn   # ends SMOKE: ALL PASS
godot --path .                                     # play: hear the room
xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 \
    res://tests/capture.tscn -- --scene=office --seed=7 --clock=3.7 \
    --strip=grain --ref=save                         # pin your GPU's frame
xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 \
    res://tests/capture.tscn -- --scene=office --seed=7 --clock=3.7 \
    --strip=grain --ref=check                        # REF: MATCH
```

Listen for: the room-tone bed under everything; the fan losing pitch and
sinking into silence around the 24th second, then kicking back on; radio
crackle behind the state-radio subtitles; footsteps when you walk.
Watch for: the fan blades visibly slowing during the sputter, stopping,
then snapping back to speed.

## When it passes: cut the baseline, then commit the series

```sh
git checkout Testing
git tag pre-rebuild-110e437            # K0's pin, before anything lands
git checkout -b rebuild/R0
# unpack this tree over your checkout (or apply _rebuild/batch1.patch),
# then commit the series below, one commit per line
```

Commit series (Conventional Commits, in order):

1. `chore(art): purge orphan second generator and retired tex sheets`
2. `chore: drop orphaned level_builder.gd.uid from the repo root`
3. `feat(audio): add gen_sfx.py synthesis pipeline and the first sound set`
4. `feat(level): give the extractor fan a seeded run-sputter-stall cycle`
5. `feat(player): emit footstep on the stride beat for the office bus`
6. `feat(audio): wire room tone, fan, radio and footstep into the office`
7. `test(build): lock the frame and the sound into the smoke gate`
8. `test(build): add reference-still save and drift check to capture`
9. `docs: batch 1 rebuild notes and README sound section`

Notes on the series: commits 1-2 are the K0 deletions; 3-6 are K2a
(gen_sfx.py + the machine + the bus - each one still passes the smoke
suite as it stands at that commit); 7 is the batch's gate itself, the
commit that teaches smoke about the frame and the sound; 8 is the
capture pin; 9 is these notes.

## Left out of this batch, on purpose

- `docs/character_reference.png` - the README's pointer still dangles;
  that file is yours to push, it cannot be synthesized.
- Other unreferenced tex sheets (`bottles`, `case_indicator`, `casefile`,
  `clock`, `crate`, `fan`, `news`, `mat`, `vent`, `pi_glove`, `radio`)
  loaded by nothing today, but kept: K0's list was the audit's four
  orphans; confirm the rest are truly dead at the next rung and purge
  them there.
- K2b - the case file returns as a desk object and the floating HUD case
  line dies (the audit calls the HUD line off-bar; it stays for one more
  batch so this one stays reviewable).
- K3 - the gait probe, then the movement freeze.

## Test results at packaging time

| Gate | Result |
| --- | --- |
| `SMOKE: ALL PASS` (7 domains) | PASS, 50 checks |
| Exit code / leaks | 0, no ObjectDB leaks, no resources in use |
| Reference round-trip | `REF: MATCH` (0.18%, 0.30% on repeat runs) |
| Baseline sanity | untouched 110e437 tree also passed before any edit |
