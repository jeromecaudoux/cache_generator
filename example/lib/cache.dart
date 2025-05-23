import 'dart:io';

import 'package:cache_annotations/annotations.dart';
import 'package:cache_generator_example/user.dart';
import 'package:path_provider/path_provider.dart';

part 'cache.g.dart';

@LocalStoreCache('my_local_store_cache')
abstract class Cache with LocalStoreCacheMixIn {
  static final Cache _instance = _Cache();

  static Cache get instance => _instance;

  @override
  Future<Directory> get directory => getApplicationDocumentsDirectory();

  @persistent
  @Cached(path: 'device_id')
  CacheEntry<Iterable<String>> deviceId();

  @Cached(fromJson: User.fromJson, toJson: userToJson)
  CacheEntry<User> me();

  @Cached(path: 'users')
  CacheEntry<List<User>> users();

  @MaxAge(Duration(seconds: 2))
  @Cached(path: 'all-friends')
  CacheEntry<int> friends();

  @Cached(path: 'friends/{id}')
  CacheEntry<String> friendById(
    @Path('id') int userId,
  );

  @Cached(path: 'likes/{date}')
  CacheEntry<String> likes(
    @Path('date', convert: keyDateConvertor) DateTime date,
  );
}

dynamic userToJson(User user) {
  return user.toJson();
}

String keyDateConvertor(DateTime date) {
  return '${date.year}-${date.month}';
}
