# 🔥 Neon T-Rex Runner — A Flame Engine Demo Game

> **Built with [Flame Engine](https://flame-engine.org/)** — the open-source 2D game engine for Flutter.
>
> This project was created to explore and showcase the capabilities of the Flame game engine.
> It demonstrates how to build a fully-featured, visually polished 2D side-scrolling runner game
> using Flame's component system, collision detection, parallax rendering, and procedural graphics.
>
> 🔗 **Flame Repository:** [github.com/flame-engine/flame](https://github.com/flame-engine/flame)
> 🌐 **Flame Website:** [flame-engine.org](https://flame-engine.org/)

---

## 🎮 About

Neon T-Rex Runner is a Chrome Dino (T-Rex Runner) inspired game with a cyberpunk/synthwave visual style. The player controls a neon dinosaur, jumping over cacti and ducking under pterodactyls in an endless runner format. The game features procedurally rendered vector graphics, aurora borealis atmospheric effects, perspective-scrolling ground, and screen-shake impact feedback.

### Key Flame Features Demonstrated

| Feature | Usage |
|---|---|
| `FlameGame` | Core game loop, update/render cycle |
| `HasCollisionDetection` | Built-in collision system for obstacles |
| `PositionComponent` | All game entities (Dino, Cactus, Bird, Ground) |
| `HasGameReference` | Cross-component communication |
| `CollisionCallbacks` | Game over trigger on Dino-Obstacle contact |
| `TapCallbacks` & `KeyboardEvents` | Touch + keyboard input handling |
| Canvas API | Procedural rendering with `Path`, `Paint`, gradients, blur |
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

- **Tap** the screen or press **Space / Arrow Up** to jump
- Avoid **neon cacti** on the ground and **pterodactyls** in the air
- The game speed increases over time — survive as long as possible!
- Your **high score** is saved locally between sessions

---

## 🏗️ Project Structure

```
lib/
├── main.dart                          # App entry point
├── constants/
│   └── game_constants.dart            # Physics, colors, dimensions
├── game/
│   ├── dino_game.dart                 # Core game engine & state
│   └── components/
│       ├── dino.dart                  # Player character (T-Rex)
│       ├── ground.dart                # Perspective grid terrain
│       ├── obstacle.dart              # Cactus & Bird obstacles
│       └── parallax_background.dart   # Sky, stars, aurora, moon
└── widgets/
    ├── main_menu_overlay.dart         # Start screen UI
    ├── game_over_overlay.dart         # Game over screen UI
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
