// ignore_for_file: avoid_print

import 'package:cache_generator_example/cache.dart';
import 'package:cache_generator_example/user.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Cache generator Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: _test,
              child: const Text('Test set/get'),
            ),
            TextButton(
              onPressed: _testExpiration,
              child: const Text('Test expiration'),
            ),
            TextButton(
              onPressed: () =>
                  Cache.instance.deleteAll().then((value) => print('deleted')),
              child: const Text('Delete all'),
            ),
            TextButton(
              onPressed: () => Cache.instance
                  .deleteAll(deletePersistent: true)
                  .then((value) => print('deleted')),
              child: const Text('Delete all (with persistent)'),
            ),
          ],
        ),
      ),
    );
  }

  void _test() async {
    Cache cache = Cache.instance;
    await cache.deviceId().set(['lol', 'ok']);
    print(await cache.deviceId().get());

    await cache.me().set(User('Someone', 26));
    print(await cache.me().get());

    await cache.friendById(12).set('joe');
    print(await cache.friendById(12).get());
  }

  Future<void> _testExpiration() async {
    await Cache.instance
        .friends()
        .set(1)
        .then((value) => debugPrint('Value saved: $value'))
        .then((value) => Future.delayed(const Duration(seconds: 3)))
        .then((value) => Cache.instance.friends().get())
        .then((value) => debugPrint('Value is: $value (should be null)'));
    await Cache.instance
        .friends()
        .set(1, maxAge: const Duration(seconds: 4))
        .then((value) => debugPrint('Value saved: $value'))
        .then((value) => Future.delayed(const Duration(seconds: 3)))
        .then((value) => Cache.instance.friends().get())
        .then((value) => debugPrint('Value is: $value (should be 1)'));
  }
}
