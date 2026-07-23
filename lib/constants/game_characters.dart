/// One selectable runner from the Kenney "Platformer Characters 1" pack (CC0).
///
/// [id] is both the asset folder name and the value written to
/// shared_preferences, so an unknown or missing id falls back to [fallback]
/// instead of crashing on a sprite that is not there.
class GameCharacter {
  final String id;
  final String label;
  final String blurb;

  const GameCharacter({
    required this.id,
    required this.label,
    required this.blurb,
  });

  /// Flame resolves sprite paths under assets/images/ on its own.
  String get spritePath => 'characters/$id';

  /// Flutter widgets need the full path instead.
  String get previewAsset => 'assets/images/characters/$id/${id}_idle.png';

  static const GameCharacter player = GameCharacter(
    id: 'player',
    label: 'PLAYER',
    blurb: 'Balanced all-rounder',
  );
  static const GameCharacter adventurer = GameCharacter(
    id: 'adventurer',
    label: 'ADVENTURER',
    blurb: 'Scarf in the wind',
  );
  static const GameCharacter female = GameCharacter(
    id: 'female',
    label: 'EXPLORER',
    blurb: 'Light on her feet',
  );
  static const GameCharacter soldier = GameCharacter(
    id: 'soldier',
    label: 'SOLDIER',
    blurb: 'Field hardened',
  );
  static const GameCharacter zombie = GameCharacter(
    id: 'zombie',
    label: 'ZOMBIE',
    blurb: 'Slow brains, quick legs',
  );

  static const List<GameCharacter> all = [
    player,
    adventurer,
    female,
    soldier,
    zombie,
  ];

  /// The character a fresh install starts on.
  static const GameCharacter fallback = player;

  static GameCharacter fromId(String? id) {
    for (final character in all) {
      if (character.id == id) return character;
    }
    return fallback;
  }
}
