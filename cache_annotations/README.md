This package is a type conversion generator using source_gen and inspired by Retrofit 
to help you manage persistent cache.

## Usage
# Generator

Add the annotations and generators to your dependencies
```yaml 
dependencies:
  cache_annotations: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.8
  cache_generators: ^1.0.0
```

## Define and Generate your API

```dart
import 'package:cache_annotations/annotations.dart';
import 'package:cache_generator_example/user.dart';

part 'cache.g.dart';

@LocalStoreCache('my_local_store_cache')
abstract class Cache implements BaseCache {
  static final Cache _instance = _Cache();
  static Cache get instance => _instance;

  @persistent
  @CacheKey(name: 'device_id')
  CacheEntry<Iterable<String>> deviceId();

  @CacheKey(fromJson: User.fromJson, toJson: userToJson)
  CacheEntry<User> me();

  @MaxAge(Duration(seconds: 2))
  @CacheKey(name: 'friends')
  CacheEntry<int> friends();

  @CacheKey(name: 'friends/{id}')
  CacheEntry<String> friendById(@KeyPart('id') int userId);
}

dynamic userToJson(User user) {
  return User(user.name, 58).toJson();
}
```

## then run the generator

```shell
# dart
dart pub run build_runner build

# flutter	
flutter pub run build_runner build
```

## Use it

```dart
    Cache cache = Cache.instance;
    await cache.deviceId().set(['lol', 'ok']);
    print(await cache.deviceId().get());
    
    await cache.me().set(User('Someone', 26));
    print(await cache.me().get());
    
    await cache.friendById(12).set('joe');
    print(await cache.friendById(12).get());
```

## Additional information

If you find a bug or want a feature, please file an issue on github <a href="https://github.com/jeromecaudoux/cache_generator/issues">Here</a>.
