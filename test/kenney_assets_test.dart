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
