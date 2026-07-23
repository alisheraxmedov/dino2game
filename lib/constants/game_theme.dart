import 'dart:ui';

/// A full canvas palette. The run crossfades between [night] and [day] as the
/// player keeps moving, so every component reads its colours from the theme the
/// game is currently holding instead of from a fixed constant.
class GameTheme {
  /// True once the crossfade is past the halfway point. Only used for labels and
  /// tests — the rendering always works off the interpolated colours.
  final bool isDay;

  // Sky gradient, top of the screen down to the horizon
  final Color sky0;
  final Color sky1;
  final Color sky2;
  final Color sky3;
  final Color sky4;

  // Aurora curtains at night, soft haze bands by day
  final Color auroraA;
  final Color auroraB;
  final Color auroraC;

  /// Multiplies star and shooting-star alpha — daylight washes them out.
  final double starOpacity;

  final Color celestialBody;
  final Color celestialDetail;

  final Color farMountainTop;
  final Color farMountainBottom;
  final Color farMountainEdge;
  final Color nearMountainTop;
  final Color nearMountainBottom;
  final Color nearMountainEdge;

  final Color groundTop;
  final Color groundMid;
  final Color groundBottom;

  /// Horizon line, perspective grid, runner glow and HUD chrome.
  final Color accent;
  final Color grass;
  final Color rock;
  final Color fog;

  final Color obstacle;
  final Color obstacleShade;
  final Color thorn;
  final Color highlight;

  /// Backing colour for the HUD pill and the touch pads.
  final Color panel;

  const GameTheme({
    required this.isDay,
    required this.sky0,
    required this.sky1,
    required this.sky2,
    required this.sky3,
    required this.sky4,
    required this.auroraA,
    required this.auroraB,
    required this.auroraC,
    required this.starOpacity,
    required this.celestialBody,
    required this.celestialDetail,
    required this.farMountainTop,
    required this.farMountainBottom,
    required this.farMountainEdge,
    required this.nearMountainTop,
    required this.nearMountainBottom,
    required this.nearMountainEdge,
    required this.groundTop,
    required this.groundMid,
    required this.groundBottom,
    required this.accent,
    required this.grass,
    required this.rock,
    required this.fog,
    required this.obstacle,
    required this.obstacleShade,
    required this.thorn,
    required this.highlight,
    required this.panel,
  });

  /// The original neon-night look the game shipped with.
  static const GameTheme night = GameTheme(
    isDay: false,
    sky0: Color(0xFF020810),
    sky1: Color(0xFF0A0E2A),
    sky2: Color(0xFF15083A),
    sky3: Color(0xFF200840),
    sky4: Color(0xFF1B0533),
    auroraA: Color(0xFF39FF14),
    auroraB: Color(0xFF00E5FF),
    auroraC: Color(0xFFBF40FF),
    starOpacity: 1.0,
    celestialBody: Color(0xFFE8E0D0),
    celestialDetail: Color(0xFFCDC0AA),
    farMountainTop: Color(0xFF0D0D28),
    farMountainBottom: Color(0xFF141438),
    farMountainEdge: Color(0xFFBF40FF),
    nearMountainTop: Color(0xFF0A0A20),
    nearMountainBottom: Color(0xFF101030),
    nearMountainEdge: Color(0xFFFF2D7C),
    groundTop: Color(0xFF1A1A3E),
    groundMid: Color(0xFF0A0A1E),
    groundBottom: Color(0xFF050510),
    accent: Color(0xFF00E5FF),
    grass: Color(0xFF39FF14),
    rock: Color(0xFF2A2A4A),
    fog: Color(0xFFBF40FF),
    obstacle: Color(0xFFFF2D7C),
    obstacleShade: Color(0xFF400020),
    thorn: Color(0xFFFF6B00),
    highlight: Color(0xFFFFE500),
    panel: Color(0xFF050B18),
  );

  /// Daylight: the same silhouettes under a bright sky, with every neon shifted
  /// to a saturated tone that still reads against sand and pale blue.
  static const GameTheme day = GameTheme(
    isDay: true,
    sky0: Color(0xFF3FA9E8),
    sky1: Color(0xFF6FC8F2),
    sky2: Color(0xFF9DDDF7),
    sky3: Color(0xFFCFEDF3),
    sky4: Color(0xFFFDEFC4),
    auroraA: Color(0xFFFFFFFF),
    auroraB: Color(0xFFF3FBFF),
    auroraC: Color(0xFFFFF0F6),
    starOpacity: 0.0,
    celestialBody: Color(0xFFFFF3A0),
    celestialDetail: Color(0xFFFFE07A),
    farMountainTop: Color(0xFF8FA9BE),
    farMountainBottom: Color(0xFFBACBD8),
    farMountainEdge: Color(0xFF6A5AA8),
    nearMountainTop: Color(0xFF6F8AA4),
    nearMountainBottom: Color(0xFF9BB2C4),
    nearMountainEdge: Color(0xFFB03A66),
    groundTop: Color(0xFFE6D9AB),
    groundMid: Color(0xFFCBBB8B),
    groundBottom: Color(0xFFAD9C6C),
    accent: Color(0xFF00707F),
    grass: Color(0xFF2E7D32),
    rock: Color(0xFF8C8060),
    fog: Color(0xFF7E57C2),
    obstacle: Color(0xFFC2185B),
    obstacleShade: Color(0xFF7A1038),
    thorn: Color(0xFFE65100),
    highlight: Color(0xFFB26A00),
    panel: Color(0xFFF2F6F8),
  );

  /// Blends two palettes channel by channel. [t] is 0 for [a], 1 for [b].
  static GameTheme lerp(GameTheme a, GameTheme b, double t) {
    Color mix(Color x, Color y) => Color.lerp(x, y, t)!;
    return GameTheme(
      isDay: t >= 0.5 ? b.isDay : a.isDay,
      sky0: mix(a.sky0, b.sky0),
      sky1: mix(a.sky1, b.sky1),
      sky2: mix(a.sky2, b.sky2),
      sky3: mix(a.sky3, b.sky3),
      sky4: mix(a.sky4, b.sky4),
      auroraA: mix(a.auroraA, b.auroraA),
      auroraB: mix(a.auroraB, b.auroraB),
      auroraC: mix(a.auroraC, b.auroraC),
      starOpacity: a.starOpacity + (b.starOpacity - a.starOpacity) * t,
      celestialBody: mix(a.celestialBody, b.celestialBody),
      celestialDetail: mix(a.celestialDetail, b.celestialDetail),
      farMountainTop: mix(a.farMountainTop, b.farMountainTop),
      farMountainBottom: mix(a.farMountainBottom, b.farMountainBottom),
      farMountainEdge: mix(a.farMountainEdge, b.farMountainEdge),
      nearMountainTop: mix(a.nearMountainTop, b.nearMountainTop),
      nearMountainBottom: mix(a.nearMountainBottom, b.nearMountainBottom),
      nearMountainEdge: mix(a.nearMountainEdge, b.nearMountainEdge),
      groundTop: mix(a.groundTop, b.groundTop),
      groundMid: mix(a.groundMid, b.groundMid),
      groundBottom: mix(a.groundBottom, b.groundBottom),
      accent: mix(a.accent, b.accent),
      grass: mix(a.grass, b.grass),
      rock: mix(a.rock, b.rock),
      fog: mix(a.fog, b.fog),
      obstacle: mix(a.obstacle, b.obstacle),
      obstacleShade: mix(a.obstacleShade, b.obstacleShade),
      thorn: mix(a.thorn, b.thorn),
      highlight: mix(a.highlight, b.highlight),
      panel: mix(a.panel, b.panel),
    );
  }
}
