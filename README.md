# 🔥 Neon Kenney Runner — A Flame Engine Demo Game

> **Built with [Flame Engine](https://flame-engine.org/)** — the open-source 2D game engine for Flutter.
>
> This project was created to explore and showcase the capabilities of the Flame game engine.
> It demonstrates how to build a fully-featured, visually polished 2D side-scrolling runner game
> using Flame's component system, collision detection, parallax rendering, and persistent world streaming.
>
> 🔗 **Flame Repository:** [github.com/flame-engine/flame](https://github.com/flame-engine/flame)
> 🌐 **Flame Website:** [flame-engine.org](https://flame-engine.org/)

---

## 🎮 About

Neon Kenney Runner is a player-driven side-scrolling platform runner with a
cyberpunk/synthwave visual style. Choose one of five Kenney runners, explore in
either direction, collect coins, jump between platforms, and avoid a cast of
sprite-based hazards. The game combines themed Kenney terrain with aurora
atmospheric effects, a perspective-scrolling ground plane, persistent world
streaming, and screen-shake impact feedback.

### Key Flame Features Demonstrated

| Feature | Usage |
|---|---|
| `FlameGame` | Core game loop, update/render cycle |
| `HasCollisionDetection` | Hazards, collectible coins, and runner collision |
| `PositionComponent` | Runner, hazards, coins, terrain, and platforms |
| `HasGameReference` | Cross-component communication |
| `CollisionCallbacks` | Hazard game-over and idempotent coin collection |
| `TapCallbacks` & `KeyboardEvents` | Touch + keyboard input handling |
| Canvas API | Theme-aware backgrounds, gradients, glow, and particles |
| Overlay System | Flutter widgets layered over the game (HUD, menus) |

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** `>=3.6.0`
- **Dart SDK** `>=3.6.0`
- A target device or emulator (macOS, iOS, Android, Linux, Windows, or Web)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/dino2game.git
cd dino2game

# Install dependencies
flutter pub get
```

### Running the Game

```bash
# Run on macOS (default)
flutter run -d macos

# Run on iOS Simulator
flutter run -d ios

# Run on Android Emulator
flutter run -d android

# Run on Chrome (Web)
flutter run -d chrome

# Run on Linux
flutter run -d linux

# Run on Windows
flutter run -d windows
```

### Build for Release

```bash
# Build release APK (Android)
flutter build apk --release

# Build release IPA (iOS)
flutter build ipa --release

# Build macOS app
flutter build macos --release

# Build for Web
flutter build web --release
```

---

## 🎯 Gameplay

- Choose **Player, Adventurer, Explorer, Soldier, or Zombie** from the
  settings screen; the selection is remembered locally.
- Hold **Right Arrow / D** to run forward and **Left Arrow / A** to reverse.
  On iOS and Android, use the on-screen left and right controls.
- Press **Space / Arrow Up / W**, tap the game canvas, or use the mobile
  **JUMP** control to jump.
- Avoid the Kenney **cactus**, **SpikeMan**, **SpringMan**, and flying
  **WingMan** hazards. Contact with any hazard ends the run.
- Collect animated gold coins. Coins have a separate per-run HUD count, reset
  for each new run, and remain collected if you reverse back through the same
  part of the world.
- Jump upward through elevated platforms, land on them from above, and walk off
  either edge. Platforms use stone at night and wood by day.
- Lower terrain uses cake sprites at night and grass sprites by day as the
  world cycles between themes.
- Distance score only increases at the furthest point reached. Your distance
  **high score** is saved locally between sessions.

---

## 🏗️ Project Structure

```
lib/
├── main.dart                          # App entry point
├── constants/
│   ├── game_characters.dart           # Selectable Kenney runners
│   ├── game_constants.dart            # Physics, colors, dimensions
│   └── game_theme.dart                # Day/night palettes
├── game/
│   ├── dino_game.dart                 # Core game engine & state
│   ├── world_layout.dart              # Persistent world entity slots
│   └── components/
│       ├── coin.dart                  # Animated collectibles
│       ├── dino.dart                  # Selectable runner
│       ├── elevated_platform.dart     # One-way stone/wood platforms
│       ├── ground.dart                # Cake/grass lower terrain
│       ├── obstacle.dart              # Kenney hazards and enemies
│       └── parallax_background.dart   # Sky, stars, aurora, moon
└── widgets/
    ├── controls_overlay.dart          # Mobile movement controls
    ├── game_over_overlay.dart         # Game over screen UI
    ├── main_menu_overlay.dart         # Start screen UI
    ├── settings_overlay.dart          # Runner selection
    └── hud_overlay.dart               # In-game score display
```

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| [flame](https://pub.dev/packages/flame) | 2D game engine for Flutter |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | Local high score persistence |

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
