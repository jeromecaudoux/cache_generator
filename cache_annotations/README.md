This package is a type conversion generator using source_gen and inspired by Retrofit 
to help you manage persistent cache.

## Usage

Add the annotations and generators to your dependencies
```yaml 
dependencies:
  cache_annotations: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.8
  cache_generators: ^1.0.0
```

## Define your cache

```dart
import 'package:cache_annotations/annotations.dart';
import 'package:cache_generator_example/user.dart';

part 'cache.g.dart';

@LocalStoreCache('my_local_store_cache')
abstract class Cache implements BaseCache {
  static final Cache _instance = _Cache();
  static Cache get instance => _instance;

  @persistent
  @CacheKey(path: 'device_id')
  CacheEntry<Iterable<String>> deviceId();

  @CacheKey(fromJson: User.fromJson, toJson: userToJson)
  CacheEntry<User> me();

  @MaxAge(Duration(seconds: 2))
  @CacheKey(path: 'friends')
  CacheEntry<int> friends();

  @CacheKey(path: 'friends/{id}')
  CacheEntry<String> friendById(
      @Path('id') int userId,
  );

  @CacheKey(path: 'likes/{date}')
  CacheEntry<String> likes(
      @Path('date', convert: keyDateConvertor) DateTime date,
      @SortBy(convert: keyDateConvertor) DateTime sortBy,
      @sortBy int test,
  );
}
```

## Run the generator

```shell
# dart
dart pub run build_runner build

# flutter	
flutter pub run build_runner build
```

## Use it

```dart
    Cache cache = Cache.instance;
    await cache.deviceId().set(['dummy', 'ok']);
    print(await cache.deviceId().get());
    
    await cache.me().set(User('Someone', 26));
    print(await cache.me().get());
    
    await cache.friendById(12).set('Joe');
    print(await cache.friendById(12).get());
```

## Additional information

If you find a bug or want a feature, please file an issue on github <a href="https://github.com/jeromecaudoux/cache_generator/issues">Here</a>.
