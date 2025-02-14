// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:cache_generator_example/cache.dart';
import 'package:cache_generator_example/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test set and get', () async {
    Cache cache = Cache.instance;
    await cache.deleteAll();

    await cache.deviceId().set(['Hello', 'ok']);
    expect(await cache.deviceId().get(), ['Hello', 'ok']);

    await cache.me().set(User('Someone', 26));
    expect(await cache.me().get(), User('Someone', 26));

    await cache.friendById(12).set('joe');
    expect(await cache.friendById(12).get(), 'joe');
  });

  test('Test expiration', () async {
    Cache cache = Cache.instance;
    await cache.deleteAll();

    int? value = await cache
        .friends()
        .set(1)
        .then((value) => Future.delayed(const Duration(seconds: 3)))
        .then((value) => Cache.instance.friends().get());
    expect(value, null);

    value = await cache
        .friends()
        .set(1, maxAge: const Duration(seconds: 4))
        .then((value) => Future.delayed(const Duration(seconds: 3)))
        .then((value) => Cache.instance.friends().get());
    expect(value, 1);
  });

  test('Test delete all', () async {
    Cache cache = Cache.instance;
    await cache.deleteAll();

    await cache.deviceId().set(['Hello', 'ok']);
    await cache.me().set(User('Someone', 26));
    await cache.friendById(12).set('joe');

    await cache.deleteAll();
    expect(await cache.deviceId().get(), ['Hello', 'ok']);
    expect(await cache.me().get(), null);
    expect(await cache.friendById(12).get(), null);

    await cache.deleteAll(deletePersistent: true);
    expect(await cache.deviceId().get(), null);
  });
}
