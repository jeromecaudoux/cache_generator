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
    // @SortBy() int test,
  );
}

dynamic userToJson(User user) {
  return User(user.name, 58).toJson();
}

String keyDateConvertor(DateTime date) {
  return '${date.year}-${date.month}';
}
