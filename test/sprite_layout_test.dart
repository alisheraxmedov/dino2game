import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dino2game/game/components/elevated_platform.dart';
import 'package:dino2game/game/components/sprite_layout.dart';
import 'package:dino2game/game/world_layout.dart';

void main() {
  test(
    'contained frames preserve aspect ratio and center within their bounds',
    () {
      final rect = containedSpriteRect(
        sourceSize: Vector2(15, 84),
        boundsSize: Vector2.all(32),
      );

      expect(rect.width / rect.height, closeTo(15 / 84, 0.0001));
      expect(rect.width, lessThan(rect.height));
      expect(rect.center.dx, closeTo(16, 0.0001));
      expect(rect.center.dy, closeTo(16, 0.0001));
    },
  );

  test('bottom-aligned frames preserve aspect ratio within hazard bounds', () {
    final rect = containedSpriteRect(
      sourceSize: Vector2(216, 101),
      boundsSize: Vector2(64, 40),
      alignmentY: 1,
    );

    expect(rect.width / rect.height, closeTo(216 / 101, 0.0001));
    expect(rect.right, lessThanOrEqualTo(64));
    expect(rect.bottom, 40);
  });

  test('wide elevated platforms retain the terrain sprite aspect ratio', () {
    final platform = ElevatedPlatform(
      spec: ElevatedPlatformSpec(worldX: 0, width: 340),
    );

    expect(
      platform.size.x / platform.size.y,
      closeTo(
        ElevatedPlatform.sourceWidth / ElevatedPlatform.sourceHeight,
        0.0001,
      ),
    );
  });
}
