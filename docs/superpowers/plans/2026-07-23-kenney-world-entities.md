# Kenney World Entities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace procedural hazards and terrain accents with the supplied
Kenney sprites, add persistent collectible coins and animated ground enemies,
and add reachable one-way elevated platforms.

**Architecture:** Keep `DinoGame` as the owner of the persistent bidirectional
world layout, but replace the bird boolean with typed entity specifications and
keep platform specifications separate. Sprite components remain thin streamed
views of those specifications. One-way platform support is resolved by the
runner's vertical physics against stable world-space platform footprints, while
coins use an idempotent collection callback.

**Tech Stack:** Flutter 3.12-compatible Dart, Flame 1.18,
`flutter_test`, `shared_preferences`.

## Global Constraints

- Do not change the existing day/night hold duration, transition duration,
  palette interpolation, or restart-at-night behavior.
- Do not change gravity, jump force, run speed, backward speed, distance score,
  high score persistence, or the clear opening runway.
- Preserve bidirectional persistent-world behavior.
- Coins are per-run, not persisted, and do not alter the distance score.
- Enemies cannot be defeated and always cause game over on contact.
- Elevated platforms are about 90 logical pixels above lower ground and are
  one-way landing surfaces.

---

## File Map

- `assets/images/environment/`: runtime cactus and lower/elevated terrain
  sprites plus Kenney license.
- `assets/images/enemies/`: runtime SpikeMan, SpringMan, and WingMan sprites
  plus Kenney license.
- `assets/images/items/`: runtime gold animation sprites plus Kenney license.
- `lib/game/world_layout.dart`: typed persistent entity/platform specs with no
  rendering behavior.
- `lib/game/components/obstacle.dart`: sprite-based hazard base, cactus,
  SpikeMan, SpringMan, and WingMan.
- `lib/game/components/coin.dart`: spinning collectible view and idempotent
  collision handoff.
- `lib/game/components/elevated_platform.dart`: streamed theme-selecting
  platform view.
- `lib/game/components/ground.dart`: lower terrain sprite strip layered into
  the existing ground plane.
- `lib/game/components/dino.dart`: hazard-vs-coin collision distinction and
  one-way platform landing physics.
- `lib/game/dino_game.dart`: world generation, streaming, coin state, platform
  surface query, and reset lifecycle.
- `lib/widgets/hud_overlay.dart`: per-run coin counter.
- `test/kenney_assets_test.dart`: packaging and sprite-load coverage.
- `test/world_entities_test.dart`: typed specs, streaming, collisions, coin
  persistence, and reset coverage.
- `test/elevated_platform_test.dart`: pass-through, landing, standing, falling,
  and placement coverage.
- `test/theme_render_test.dart`: lower/elevated theme sprite selection coverage.

---

### Task 1: Package the Kenney runtime assets

**Files:**

- Create: `assets/images/environment/*.png`
- Create: `assets/images/environment/KENNEY_LICENSE.txt`
- Create: `assets/images/enemies/*.png`
- Create: `assets/images/enemies/KENNEY_LICENSE.txt`
- Create: `assets/images/items/*.png`
- Create: `assets/images/items/KENNEY_LICENSE.txt`
- Modify: `pubspec.yaml:35-47`
- Create: `test/kenney_assets_test.dart`

**Interfaces:**

- Consumes: source PNGs under `components/kenney_jumper-pack/PNG`.
- Produces: the asset prefixes `images/environment`,
  `images/enemies`, and `images/items`, relative to Flame's image loader.

- [ ] **Step 1: Write the failing packaging test**

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const requiredKenneyAssets = <String>[
  'assets/images/environment/cactus.png',
  'assets/images/environment/ground_cake_broken.png',
  'assets/images/environment/ground_cake_small_broken.png',
  'assets/images/environment/ground_grass_broken.png',
  'assets/images/environment/ground_grass_small_broken.png',
  'assets/images/environment/ground_stone.png',
  'assets/images/environment/ground_wood_broken.png',
  'assets/images/enemies/spikeMan_walk1.png',
  'assets/images/enemies/spikeMan_walk2.png',
  'assets/images/enemies/springMan_stand.png',
  'assets/images/enemies/wingMan1.png',
  'assets/images/enemies/wingMan2.png',
  'assets/images/enemies/wingMan3.png',
  'assets/images/enemies/wingMan4.png',
  'assets/images/enemies/wingMan5.png',
  'assets/images/items/gold_1.png',
  'assets/images/items/gold_2.png',
  'assets/images/items/gold_3.png',
  'assets/images/items/gold_4.png',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every required Kenney world sprite is packaged', () async {
    for (final path in requiredKenneyAssets) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
flutter test test/kenney_assets_test.dart
```

Expected: FAIL with `Unable to load asset` for
`assets/images/environment/cactus.png`.

- [ ] **Step 3: Copy only the approved sprites and license**

Create the three runtime directories. Copy the exact files listed by
`requiredKenneyAssets` from the matching Jumper Pack `PNG` directories. Copy
`components/kenney_jumper-pack/License.txt` into each runtime directory as
`KENNEY_LICENSE.txt`.

Add these entries to `pubspec.yaml`:

```yaml
    - assets/images/environment/
    - assets/images/enemies/
    - assets/images/items/
```

- [ ] **Step 4: Verify GREEN**

Run:

```bash
flutter test test/kenney_assets_test.dart
flutter analyze
```

Expected: both commands exit successfully.

- [ ] **Step 5: Commit**

```bash
git add assets/images/environment assets/images/enemies assets/images/items \
  pubspec.yaml test/kenney_assets_test.dart
git commit -m "feat: package Kenney world sprites"
```

---

### Task 2: Introduce typed persistent world specifications

**Files:**

- Create: `lib/game/world_layout.dart`
- Modify: `lib/game/dino_game.dart:13-27,43-49,335-438`
- Create: `test/world_entities_test.dart`

**Interfaces:**

- Produces:
  - `enum WorldEntityKind { cactus, spikeMan, springMan, wingMan, coin }`
  - `enum CactusVariant { smallSingle, smallDouble, largeSingle, largeTriple }`
  - `enum WingHeight { low, high }`
  - `WorldEntitySpec(worldX, kind, wingHeight, cactusVariant, elevation)`
  - `ElevatedPlatformSpec(worldX, width, elevation)`
  - `DinoGame({Random? random})`
  - read-only `worldLayout` and `platformLayout` getters for verification.
- Consumes: no component types; persistent layout data remains independent from
  rendering.

- [ ] **Step 1: Write the failing type and deterministic-layout tests**

Add this structure to `test/world_entities_test.dart`, reusing the existing
headless `_bootGame` and fixed-step `_tick` helpers from `test/widget_test.dart`:

```dart
test('world slots explicitly identify every supported entity kind', () {
  expect(
    WorldEntityKind.values.toSet(),
    {
      WorldEntityKind.cactus,
      WorldEntityKind.spikeMan,
      WorldEntityKind.springMan,
      WorldEntityKind.wingMan,
      WorldEntityKind.coin,
    },
  );
});

test('a seeded long world contains hazards, coins, and platforms', () async {
  final game = await _bootGame(random: Random(7));
  game.startGame();
  game.setInputDirection(1);
  _tick(game, 35);

  final kinds = game.worldLayout.map((slot) => slot.kind).toSet();
  expect(kinds, containsAll(WorldEntityKind.values));
  expect(game.platformLayout, isNotEmpty);
});

test('platform footprints contain no hazard slots', () async {
  final game = await _bootGame(random: Random(7));
  game.startGame();
  game.setInputDirection(1);
  _tick(game, 35);

  for (final platform in game.platformLayout) {
    final hazards = game.worldLayout.where(
      (slot) =>
          slot.kind != WorldEntityKind.coin &&
          slot.worldX >= platform.worldX &&
          slot.worldX <= platform.worldX + platform.width,
    );
    expect(hazards, isEmpty);
  }
});
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
flutter test test/world_entities_test.dart
```

Expected: compile failure because `WorldEntityKind`, the spec classes, and the
injectable `Random` constructor do not exist.

- [ ] **Step 3: Add the model**

Create `lib/game/world_layout.dart`:

```dart
import 'package:flame/components.dart';

enum WorldEntityKind { cactus, spikeMan, springMan, wingMan, coin }
enum CactusVariant { smallSingle, smallDouble, largeSingle, largeTriple }
enum WingHeight { low, high }

class WorldEntitySpec {
  final double worldX;
  final WorldEntityKind kind;
  final WingHeight wingHeight;
  final CactusVariant cactusVariant;
  final double elevation;
  bool collected;
  PositionComponent? live;

  WorldEntitySpec({
    required this.worldX,
    required this.kind,
    this.wingHeight = WingHeight.low,
    this.cactusVariant = CactusVariant.smallSingle,
    this.elevation = 36,
    this.collected = false,
  });
}

class ElevatedPlatformSpec {
  final double worldX;
  final double width;
  final double elevation;
  PositionComponent? live;

  ElevatedPlatformSpec({
    required this.worldX,
    this.width = 260,
    this.elevation = 90,
  });

  bool containsWorldX(double left, double right) =>
      right > worldX && left < worldX + width;
}
```

Update `DinoGame`:

```dart
DinoGame({Random? random}) : _random = random ?? Random();

final Random _random;
final List<WorldEntitySpec> _layout = [];
final List<ElevatedPlatformSpec> _platformLayout = [];

List<WorldEntitySpec> get worldLayout => List.unmodifiable(_layout);
List<ElevatedPlatformSpec> get platformLayout =>
    List.unmodifiable(_platformLayout);
```

Replace `_buildSpec` with `_buildWorldAt(double worldX)`. It draws one random
roll and chooses one of:

```dart
if (roll < 0.16) {
  final platform = ElevatedPlatformSpec(
    worldX: worldX,
    width: _random.nextBool() ? 260 : 340,
  );
  _platformLayout.add(platform);
  final count = 2 + _random.nextInt(4);
  for (var index = 0; index < count; index++) {
    _layout.add(WorldEntitySpec(
      worldX: platform.worldX +
          (index + 1) * platform.width / (count + 1),
      kind: WorldEntityKind.coin,
      elevation: platform.elevation + 36,
    ));
  }
  return;
}

if (roll < 0.32) {
  final count = 1 + _random.nextInt(3);
  for (var index = 0; index < count; index++) {
    _layout.add(WorldEntitySpec(
      worldX: worldX + index * 42,
      kind: WorldEntityKind.coin,
    ));
  }
  return;
}
```

The remaining roll selects cactus, SpikeMan, SpringMan, or WingMan. Express the
current cactus size-by-difficulty rules with `CactusVariant` and only permit WingMan when
`difficulty > 150`. `_ensureLayout` calls `_buildWorldAt` rather than adding a
single returned spec. Clear both lists in `startGame` and `returnToMenu`.

Use explicit thresholds that allow `Random(7)` to cover all kinds within the
35-second test distance. If the seed does not cover all kinds on the first RED
to GREEN attempt, adjust the fixed seed, not the production distribution.

- [ ] **Step 4: Verify GREEN and regressions**

Run:

```bash
flutter test test/world_entities_test.dart test/widget_test.dart
flutter analyze
```

Expected: all pass. The old streaming tests now inspect
`WorldEntitySpec.worldX` through `game.worldLayout` where necessary.

- [ ] **Step 5: Commit**

```bash
git add lib/game/world_layout.dart lib/game/dino_game.dart \
  test/world_entities_test.dart test/widget_test.dart
git commit -m "refactor: type persistent world slots"
```

---

### Task 3: Replace procedural hazards with Kenney sprites

**Files:**

- Modify: `lib/game/components/obstacle.dart`
- Modify: `lib/game/dino_game.dart`
- Modify: `test/world_entities_test.dart`

**Interfaces:**

- Produces:
  - `abstract class Obstacle extends PositionComponent`
  - `Cactus`, `SpikeManEnemy`, `SpringManEnemy`, and `WingMan`
  - public `bool get spritesLoaded` and `int get frameIndex` for load/animation
    verification.
- Consumes: `WorldEntitySpec`, `WorldEntityKind`, existing obstacle collision
  behavior in `Dino`.

- [ ] **Step 1: Write failing sprite and factory tests**

```dart
test('every hazard loads its Kenney sprite set', () async {
  final game = await _bootGame();
  final hazards = <Obstacle>[
    Cactus(
      variant: CactusVariant.smallSingle,
      screenHeight: game.size.y,
      worldX: 200,
    ),
    SpikeManEnemy(screenHeight: game.size.y, worldX: 300),
    SpringManEnemy(screenHeight: game.size.y, worldX: 400),
    WingMan(
      heightLevel: WingHeight.low,
      screenHeight: game.size.y,
      worldX: 500,
    ),
  ];

  for (final hazard in hazards) {
    game.add(hazard);
  }
  await game.ready();
  expect(hazards.every((hazard) => hazard.spritesLoaded), isTrue);
});

test('WingMan advances through the five supplied frames', () async {
  final game = await _bootGame();
  game.startGame();
  final wingMan = WingMan(
    heightLevel: WingHeight.low,
    screenHeight: game.size.y,
    worldX: 200,
  );
  game.add(wingMan);
  await game.ready();

  final start = wingMan.frameIndex;
  _tick(game, 0.25);

  expect(wingMan.frameIndex, isNot(start));
  expect(wingMan.frameCount, 5);
});
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
flutter test test/world_entities_test.dart
```

Expected: compile failure because the new enemy classes and sprite-state
getters do not exist.

- [ ] **Step 3: Implement the sprite hazards**

Retain `Obstacle`'s stable `worldX` update and trimmed `RectangleHitbox`, but
replace all Canvas path drawing with loaded `Sprite` frames.

Use these exact logical sizes and frame times:

```dart
static final cactusSmallSize = Vector2(36, 50);
static final cactusLargeSize = Vector2(44, 60);
static final spikeManSize = Vector2(44, 58);
static final springManSize = Vector2(42, 54);
static final wingManSize = Vector2(64, 40);
static const enemyFrameTime = 0.14;
static const wingManFrameTime = 0.09;
```

Load sprites with:

```dart
final frames = await Future.wait([
  Sprite.load('images/enemies/wingMan1.png'),
  Sprite.load('images/enemies/wingMan2.png'),
  Sprite.load('images/enemies/wingMan3.png'),
  Sprite.load('images/enemies/wingMan4.png'),
  Sprite.load('images/enemies/wingMan5.png'),
]);
```

Catch load failures inside each component, leave `spritesLoaded == false`, and
call `removeFromParent()` so an invisible hazard cannot remain lethal.

`SpikeManEnemy` alternates its two frames. `SpringManEnemy` renders its single
frame with a visual-only sinusoidal Y translation of at most 3 logical pixels;
its world anchor and hitbox do not move. `WingMan` replaces `Bird` completely
and cycles all five frames. Cactus clusters render the same sprite `type.count`
times inside a component whose hitbox covers the opaque cluster footprint.

Update `_streamWorld` in `DinoGame` to map kinds:

```dart
final obstacle = switch (spec.kind) {
  WorldEntityKind.cactus => Cactus(...),
  WorldEntityKind.spikeMan => SpikeManEnemy(...),
  WorldEntityKind.springMan => SpringManEnemy(...),
  WorldEntityKind.wingMan => WingMan(...),
  WorldEntityKind.coin => null,
};
```

- [ ] **Step 4: Verify GREEN**

Run:

```bash
flutter test test/world_entities_test.dart test/widget_test.dart
flutter analyze
```

Expected: all pass and no reference to the old `Bird` class remains:

```bash
rg -n "class Bird|Bird\\(" lib
```

Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/obstacle.dart lib/game/dino_game.dart \
  test/world_entities_test.dart
git commit -m "feat: render Kenney hazards and WingMan"
```

---

### Task 4: Add persistent collectible coins and the HUD counter

**Files:**

- Create: `lib/game/components/coin.dart`
- Modify: `lib/game/dino_game.dart`
- Modify: `lib/game/components/dino.dart`
- Modify: `lib/widgets/hud_overlay.dart`
- Modify: `test/world_entities_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**

- Produces:
  - `ValueNotifier<int> coinNotifier`
  - `int get currentCoins`
  - `bool collectCoin(WorldEntitySpec spec)`
  - `Coin(spec:, screenHeight:)`
  - `Coin.collect()`
- Consumes: coin specs from Task 2 and Flame collision callbacks.

- [ ] **Step 1: Write failing coin behavior tests**

```dart
test('collecting a coin increments once without ending the run', () async {
  final game = await _bootGame();
  game.startGame();
  final spec = WorldEntitySpec(
    worldX: game.worldOffset + game.dino.position.x,
    kind: WorldEntityKind.coin,
  );
  final coin = Coin(spec: spec, screenHeight: game.size.y);
  game.add(coin);
  await game.ready();

  coin.collect();
  coin.collect();

  expect(game.currentCoins, 1);
  expect(game.coinNotifier.value, 1);
  expect(game.isPlaying, isTrue);
  expect(spec.collected, isTrue);
});

test('a collected streamed coin never respawns', () async {
  final game = await _bootGame();
  game.startGame();
  final spec = WorldEntitySpec(
    worldX: 900,
    kind: WorldEntityKind.coin,
  );
  game.addWorldSpecForTest(spec);
  game.streamWorldForTest();
  final coin = spec.live! as Coin;
  coin.collect();

  game.worldOffset = 2000;
  game.streamWorldForTest();
  game.worldOffset = 500;
  game.streamWorldForTest();

  expect(spec.collected, isTrue);
  expect(spec.live, isNull);
});

test('a new run and menu return reset the coin count', () async {
  final game = await _bootGame();
  game.startGame();
  final spec = WorldEntitySpec(worldX: 200, kind: WorldEntityKind.coin);
  expect(game.collectCoin(spec), isTrue);
  expect(game.currentCoins, 1);

  game.startGame();
  expect(game.currentCoins, 0);

  expect(
    game.collectCoin(
      WorldEntitySpec(worldX: 300, kind: WorldEntityKind.coin),
    ),
    isTrue,
  );
  game.returnToMenu();
  expect(game.currentCoins, 0);
});
```

Expose the two test seams with `@visibleForTesting`; they only add a supplied
spec and invoke the normal private streamer:

```dart
@visibleForTesting
void addWorldSpecForTest(WorldEntitySpec spec) => _layout.add(spec);

@visibleForTesting
void streamWorldForTest() => _streamWorld();
```

Add a widget assertion that pumping `HudOverlay` with
`game.coinNotifier.value = 3` renders `3` beside `Icons.monetization_on_rounded`.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
flutter test test/world_entities_test.dart test/widget_test.dart
```

Expected: compile failure because `Coin`, coin state, and collection APIs do not
exist.

- [ ] **Step 3: Implement collection and rendering**

`DinoGame` owns:

```dart
int currentCoins = 0;
final ValueNotifier<int> coinNotifier = ValueNotifier<int>(0);

bool collectCoin(WorldEntitySpec spec) {
  if (spec.kind != WorldEntityKind.coin || spec.collected) return false;
  spec.collected = true;
  spec.live = null;
  currentCoins++;
  coinNotifier.value = currentCoins;
  return true;
}
```

Reset both values in `startGame` and `returnToMenu`. Dispose the notifier in
`onRemove`.

`Coin` is a 32x32 `PositionComponent` with a centered 24x28 hitbox. It loads
`gold_1.png` through `gold_4.png`, advances every 0.10 seconds while playing,
anchors screen X to `spec.worldX - game.worldOffset`, and computes Y from
`spec.elevation`. `collect()` calls `game.collectCoin(spec)` and only then
removes itself.

In `Dino.onCollisionStart`:

```dart
if (other is Coin) {
  other.collect();
} else if (other is Obstacle) {
  game.triggerGameOver();
}
```

Stream uncollected coin specs in `_streamWorld`; skip collected specs. Add a
coin icon, a small divider, and a `ValueListenableBuilder<int>` to the existing
right score pill without changing score formatting.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
flutter test test/world_entities_test.dart test/widget_test.dart
flutter analyze
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/coin.dart lib/game/components/dino.dart \
  lib/game/dino_game.dart lib/widgets/hud_overlay.dart \
  test/world_entities_test.dart test/widget_test.dart
git commit -m "feat: add persistent collectible coins"
```

---

### Task 5: Add lower terrain sprites and one-way elevated platforms

**Files:**

- Create: `lib/game/components/elevated_platform.dart`
- Modify: `lib/game/components/ground.dart`
- Modify: `lib/game/components/dino.dart`
- Modify: `lib/game/dino_game.dart`
- Create: `test/elevated_platform_test.dart`
- Modify: `test/theme_render_test.dart`

**Interfaces:**

- Produces:
  - `Ground.terrainAssetNames`
  - `ElevatedPlatform.activeAssetName`
  - `double? DinoGame.landingSurfaceY(...)`
  - `bool Dino.isOnElevatedPlatform`
  - `double Dino.verticalVelocity`
- Consumes: `ElevatedPlatformSpec` and stable `worldOffset`.

- [ ] **Step 1: Write failing one-way-platform tests**

Use a headless game with a manually installed platform spec:

```dart
test('runner passes upward through a platform then lands while descending',
    () async {
  final game = await _bootGame();
  game.startGame();
  game.addPlatformSpecForTest(
    ElevatedPlatformSpec(worldX: 40, width: 240, elevation: 90),
  );

  game.requestJump();
  var passedUnderside = false;
  for (var i = 0; i < 180; i++) {
    game.update(1 / 60);
    final platformTop =
        game.size.y - GameConstants.dinoGroundYOffset - 90;
    if (game.dino.position.y + game.dino.size.y < platformTop) {
      passedUnderside = true;
    }
    if (game.dino.isOnElevatedPlatform) break;
  }

  expect(passedUnderside, isTrue);
  expect(game.dino.isOnElevatedPlatform, isTrue);
  expect(
    game.dino.position.y + game.dino.size.y,
    closeTo(game.size.y - GameConstants.dinoGroundYOffset - 90, 0.01),
  );
});

test('runner falls after the platform footprint scrolls away', () async {
  final game = await _bootGame();
  game.startGame();
  game.addPlatformSpecForTest(
    ElevatedPlatformSpec(worldX: 40, width: 160, elevation: 90),
  );
  game.requestJump();
  _tick(game, 0.9);
  expect(game.dino.isOnElevatedPlatform, isTrue);

  game.worldOffset = 400;
  game.update(1 / 60);
  expect(game.dino.isOnElevatedPlatform, isFalse);

  _tick(game, 1);
  expect(
    game.dino.position.y,
    closeTo(
      game.size.y -
          GameConstants.dinoGroundYOffset -
          GameConstants.dinoHeight,
      0.01,
    ),
  );
});
```

Add theme selection tests:

```dart
expect(
  Ground.terrainAssetNames(isDay: false),
  containsAll([
    'images/environment/ground_cake_broken.png',
    'images/environment/ground_cake_small_broken.png',
  ]),
);
expect(
  Ground.terrainAssetNames(isDay: true),
  containsAll([
    'images/environment/ground_grass_broken.png',
    'images/environment/ground_grass_small_broken.png',
  ]),
);
expect(
  ElevatedPlatform.assetName(isDay: false),
  'images/environment/ground_stone.png',
);
expect(
  ElevatedPlatform.assetName(isDay: true),
  'images/environment/ground_wood_broken.png',
);
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
flutter test test/elevated_platform_test.dart test/theme_render_test.dart
```

Expected: compile failure because platform components, support APIs, and terrain
asset selectors do not exist.

- [ ] **Step 3: Implement terrain rendering**

In `Ground`, load all four lower sprites once. Add:

```dart
static List<String> terrainAssetNames({required bool isDay}) => isDay
    ? const [
        'images/environment/ground_grass_broken.png',
        'images/environment/ground_grass_small_broken.png',
      ]
    : const [
        'images/environment/ground_cake_broken.png',
        'images/environment/ground_cake_small_broken.png',
      ];
```

Render alternating 380x94 and 200x100 source shapes scaled to
`Ground.bandHeight`, starting from the positive modulo of `-game.worldOffset`.
Keep the existing gradient, horizon, fog, and foliage. Draw the sprite strip
after the gradient/grid and before fog so the supplied lower terrain is visible
without changing physical ground height.

- [ ] **Step 4: Implement the streamed platform view**

`ElevatedPlatform` owns its `ElevatedPlatformSpec`, loads both theme sprites,
and selects:

```dart
static String assetName({required bool isDay}) => isDay
    ? 'images/environment/ground_wood_broken.png'
    : 'images/environment/ground_stone.png';
```

Its position is:

```dart
position
  ..x = spec.worldX - game.worldOffset
  ..y = game.size.y -
      GameConstants.dinoGroundYOffset -
      spec.elevation;
```

Render the selected sprite at `spec.width` by 64 logical pixels. It has no
hazard hitbox. Stream it from `_platformLayout` using the same margins as world
entities, and clear live references on removal.

- [ ] **Step 5: Implement one-way support in player physics**

Add to `DinoGame`:

```dart
double? landingSurfaceY({
  required double worldLeft,
  required double worldRight,
  required double previousFeetY,
  required double currentFeetY,
}) {
  final candidates = _platformLayout.where(
    (platform) =>
        platform.containsWorldX(worldLeft, worldRight) &&
        previousFeetY <=
            size.y - GameConstants.dinoGroundYOffset - platform.elevation &&
        currentFeetY >=
            size.y - GameConstants.dinoGroundYOffset - platform.elevation,
  );
  if (candidates.isEmpty) return null;
  return candidates
      .map(
        (platform) =>
            size.y -
            GameConstants.dinoGroundYOffset -
            platform.elevation,
      )
      .reduce(min);
}
```

Add `hasPlatformSupport` that checks the runner world-space horizontal interval
against the currently occupied platform at the same feet Y.

In `Dino.update`, record the previous feet Y before applying gravity. When
descending, query `landingSurfaceY`; snap the runner feet to the returned top,
zero vertical velocity, set `_isOnGround = true`, and remember elevated
support. Before each grounded update, clear elevated support and resume falling
if `hasPlatformSupport` becomes false. `jump()` works unchanged because the
same `_isOnGround` flag permits jumping from either surface.

- [ ] **Step 6: Verify GREEN and complete regressions**

Run:

```bash
flutter test test/elevated_platform_test.dart test/theme_render_test.dart
flutter test
flutter analyze
```

Expected: every command exits successfully.

- [ ] **Step 7: Commit**

```bash
git add lib/game/components/elevated_platform.dart \
  lib/game/components/ground.dart lib/game/components/dino.dart \
  lib/game/dino_game.dart test/elevated_platform_test.dart \
  test/theme_render_test.dart
git commit -m "feat: add themed one-way platforms"
```

---

### Task 6: Final integration polish and documentation

**Files:**

- Modify: `README.md`
- Modify only as required by failures: files from Tasks 1-5.

**Interfaces:**

- Consumes: all prior task interfaces.
- Produces: documented controls/gameplay and a clean full verification run.

- [ ] **Step 1: Update the gameplay documentation**

Replace stale references to the neon T-Rex, procedural cactus, and
pterodactyl. Document the selectable runner, Kenney cactus and enemies,
WingMan, per-run coins, and elevated one-way platforms. Keep the existing run,
jump, reverse, and platform build commands.

- [ ] **Step 2: Format all touched Dart files**

Run:

```bash
dart format lib test
```

Expected: formatter exits successfully.

- [ ] **Step 3: Run the complete quality gate**

Run:

```bash
flutter test
flutter analyze
git diff --check
```

Expected: all tests pass, analyzer reports no issues, and diff check prints no
errors.

- [ ] **Step 4: Inspect the final diff against the spec**

Run:

```bash
git status --short
git diff HEAD~5 --stat
rg -n "class Bird|Bird\\(" lib
```

Expected: only intended game, asset, test, and documentation changes; no old
bird implementation references.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: describe Kenney world gameplay"
```

---

## Final Acceptance Checklist

- The lower terrain visibly uses cake at night and grass by day.
- Elevated platforms visibly use stone at night and wood by day.
- Existing day/night timing remains byte-for-byte unchanged.
- Cactus, SpikeMan, SpringMan, and WingMan are sprite-based and lethal.
- WingMan uses all five supplied animation frames.
- Coins use all four supplied animation frames and increment a separate HUD
  value exactly once.
- Collected coins remain collected after reverse traversal.
- The runner passes through platform undersides, lands from above, stands, can
  jump again, and falls from the edge.
- Platforms never overlap generated hazards.
- New runs reset coins while distance high score persistence remains intact.
- `flutter test`, `flutter analyze`, and `git diff --check` all pass.
