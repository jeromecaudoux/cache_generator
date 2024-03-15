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

  @CacheKey(fromJson: User.fromJson, toJson: userToJson)
  CacheEntry<User> me();

  @MaxAge(Duration(seconds: 2))
  @CacheKey(name: 'friends')
  CacheEntry<int> friends();

  @CacheKey(name: 'age_of_friend-{id}/{name}')
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

dynamic userToJson(User user) {
  return User(user.name, 58).toJson();
}
