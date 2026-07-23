import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// Fits a sprite inside fixed gameplay bounds without stretching its source.
Rect containedSpriteRect({
  required Vector2 sourceSize,
  required Vector2 boundsSize,
  Offset origin = Offset.zero,
  double alignmentX = 0.5,
  double alignmentY = 0.5,
}) {
  if (sourceSize.x <= 0 ||
      sourceSize.y <= 0 ||
      boundsSize.x <= 0 ||
      boundsSize.y <= 0) {
    return Rect.fromLTWH(origin.dx, origin.dy, 0, 0);
  }

  final scale = math.min(
    boundsSize.x / sourceSize.x,
    boundsSize.y / sourceSize.y,
  );
  final width = sourceSize.x * scale;
  final height = sourceSize.y * scale;
  return Rect.fromLTWH(
    origin.dx + (boundsSize.x - width) * alignmentX,
    origin.dy + (boundsSize.y - height) * alignmentY,
    width,
    height,
  );
}
