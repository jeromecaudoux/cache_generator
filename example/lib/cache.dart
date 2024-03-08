import 'package:annotations/annotations.dart';
import 'package:example/user.dart';

part 'cache.g.dart';

@LocalStoreCache('my_local_store_cache')
abstract class Cache implements BaseCache {
  static final Cache _instance = _Cache();
  static Cache get instance => _instance;

  @persistent
  @CacheKey(name: 'device_id')
  CacheEntry<Iterable<String>> deviceId();

  CacheEntry<User> me();

  @CacheKey(name: 'friends')
  CacheEntry<Iterable<User>> friends();

  @CacheKey(name: 'age_of_friend-{id}-{name}')
  CacheEntry<double> ageOfFriend(
    @KeyPart('id') int userId,
    @KeyPart('name') String friendName,
  );

  @CacheKey(name: 'users-{test}')
  CacheEntry<double?> users(
    @KeyPart('test') int testId,
    @sortBy int userId,
  );
}
