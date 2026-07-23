# Kenney World Entities Design

## Goal

Replace the remaining hand-drawn hazards and terrain accents with the supplied
Kenney assets, add collectible coins, add ground enemies, and add reachable
elevated platforms without changing the existing player-driven movement,
distance score, persistent-world behavior, or day/night timing.

## Existing Constraints

- The runner stays at a fixed screen X while the world scrolls in either
  direction.
- Generated world objects have stable world coordinates and must reappear at
  the same location after leaving and re-entering the streaming window.
- The opening screen remains a clear runway.
- The current day/night hold duration, transition duration, palette blending,
  and restart-at-night behavior remain unchanged.
- The distance score and saved high score remain unchanged.
- All new visual assets come from the supplied Kenney Jumper Pack.

## Asset Layout

Copy only the assets used by the game into focused runtime directories under
`assets/images` and register those directories in `pubspec.yaml`.

- `assets/images/environment/`
  - `cactus.png`
  - `ground_cake_broken.png`
  - `ground_cake_small_broken.png`
  - `ground_grass_broken.png`
  - `ground_grass_small_broken.png`
  - `ground_stone.png`
  - `ground_wood_broken.png`
- `assets/images/enemies/`
  - `spikeMan_walk1.png`
  - `spikeMan_walk2.png`
  - `springMan_stand.png`
  - `wingMan1.png` through `wingMan5.png`
- `assets/images/items/`
  - `gold_1.png` through `gold_4.png`

Each runtime directory also carries the Kenney license file. Sprites retain
their source aspect ratios when scaled. Collision hitboxes exclude transparent
padding where practical.

## World Layout Model

Replace the obstacle layout's `isBird` flag with an explicit world-slot kind.
The supported kinds are cactus, spike enemy, spring enemy, WingMan, and coin.
Each slot retains its stable `worldX`, variant data, and current streamed
component.

Coin slots also retain a `collected` flag. Removing a coin from the screen does
not erase the slot; a collected slot is simply not instantiated again. This
ensures that walking backward never respawns a collected coin.

Elevated platforms use a separate persistent platform specification because a
platform owns a width, height, and optional group of coin slots. Platforms are
streamed with the same window and stable world-coordinate rules as hazards.

Generation must enforce these placement rules:

- No hazard is placed inside the horizontal footprint of an elevated platform.
- Coin slots may be placed on clear lower ground or above an elevated platform.
- Ground coins are single coins or short groups.
- Elevated-platform coins form groups of two to five.
- WingMan enemies continue to appear only after the existing introductory
  difficulty threshold.
- The existing distance-based gap ramp remains the source of world difficulty.

## Components and Gameplay

### Lower Terrain

The runner's lower ground remains physically flat, preserving the current jump
and landing behavior. A scrolling row of alternating large and small broken
ground sprites replaces the foreground's purely procedural terrain surface:

- Night/dark presentation uses cake ground sprites.
- Day/light presentation uses grass ground sprites.

The current theme state selects the matching asset without changing the theme
clock or transition state machine. Existing background and theme-aware effects
remain intact.

### Elevated Platforms

Occasional elevated platforms appear approximately 90 logical pixels above the
lower ground:

- Night/dark presentation uses `ground_stone.png`.
- Day/light presentation uses `ground_wood_broken.png`.

The platform is a one-way surface. The runner can jump upward through its
underside, lands when descending across its top, stands on it while its
horizontal footprint remains underneath, and falls naturally to the lower
ground after leaving its edge. The existing jump force is unchanged.

Platform collision is limited to landing support. Contact with the side or
underside never causes game over.

### Cactus

The procedural cactus drawing is replaced by `cactus.png`. The same source
sprite may appear at two or three balanced sizes and in occasional paired
clusters. Touching its hitbox causes game over.

### Ground Enemies

`SpikeManEnemy` alternates `spikeMan_walk1.png` and
`spikeMan_walk2.png` to appear as a walking enemy while remaining anchored to
its generated world slot.

`SpringManEnemy` uses `springMan_stand.png` with a subtle vertical
spring/pulse animation while remaining anchored to its world slot.

Touching either ground enemy causes game over.

### WingMan

The hand-drawn flame bird is removed. Its replacement cycles through
`wingMan1.png` through `wingMan5.png` as a looping wing animation. Existing low
and high flight lanes remain. Touching WingMan causes game over.

### Coins

Coins cycle through `gold_1.png` through `gold_4.png` to create a spinning
animation. A coin has a collectible hitbox and is not an obstacle:

- Contact never triggers game over.
- Contact marks its world slot collected.
- Contact removes the live component.
- Contact increments the current run's coin count by exactly one.

The coin count starts at zero for each new run and when returning to the menu.
It is independent from the distance score and high score and is not persisted
between runs.

## HUD

Add a compact coin value to the existing right-hand score pill using the same
theme-aware glass styling. The value is driven by its own notifier and rendered
as a coin icon or `COIN` label plus the current count. Existing score and high
score values retain their current meaning and formatting.

## Collision Flow

The runner distinguishes collision targets:

- `Hazard` contact calls the existing game-over flow.
- `Coin` contact calls the collection flow and continues play.
- `ElevatedPlatform` contact only participates in one-way landing support.

Coin collection is idempotent: repeated collision callbacks for the same slot
cannot increment the count more than once.

## Asset Failure Handling

A failed optional sprite load must not crash the entire run. The affected
component logs or safely skips its visual/component creation while the rest of
the game remains playable. Asset paths are covered by load tests so missing
packaging is detected during development.

## Testing

Automated tests cover:

- every required runtime sprite can be loaded;
- world specs can generate cactus, both ground enemies, WingMan, coins, and
  elevated platforms under controlled conditions;
- the old hand-drawn bird is no longer used;
- collecting a coin increments the coin notifier once and never causes game
  over;
- a collected coin stays absent after leaving and re-entering the streaming
  window;
- starting a new run and returning to the menu reset the coin count;
- hazard collision still triggers game over;
- the runner passes upward through an elevated platform, lands while
  descending, stands on its top, and falls after leaving its footprint;
- platform and hazard generation footprints do not overlap;
- night selects cake lower ground and stone elevated platforms;
- day selects grass lower ground and wood elevated platforms;
- all existing movement, reverse traversal, distance scoring, day/night,
  character-selection, foliage, and render tests continue to pass.

## Out of Scope

- Changing the duration or behavior of the current day/night cycle.
- Persisting coins or adding a coin shop.
- Combat, enemy health, projectiles, or defeating enemies.
- Changing player jump force, gravity, run speed, or backward speed.
- Moving enemies independently through world space.
