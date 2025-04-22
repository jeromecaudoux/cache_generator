// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache.dart';

// **************************************************************************
// LocalStoreCacheGenerator
// **************************************************************************

// ignore_for_file: unnecessary_string_interpolations
class _Cache extends Cache with LocalStoreCacheMixIn {
  _Cache();

  @override
  String get name => "my_local_store_cache";

  @override
  CacheEntry<Iterable<String>> deviceId() => SimpleCacheEntry(
        cache: this,
        path: 'device_id',
        name: null,
        isPersistent: true,
        maxAge: null,
        fromJson: (json) => (json as List).map((e) => e as String).toList(),
        toJson: null,
      );

  @override
  CacheEntry<User> me() => SimpleCacheEntry(
        cache: this,
        path: 'me',
        name: null,
        isPersistent: false,
        maxAge: null,
        fromJson: User.fromJson,
        toJson: userToJson,
      );

  @override
  CacheEntry<List<User>> users() => SimpleCacheEntry(
        cache: this,
        path: 'users',
        name: null,
        isPersistent: false,
        maxAge: null,
        fromJson: (json) => (json as List)
            .map((e) => User.fromJson(e as Map<String, dynamic>))
            .toList(),
        toJson: null,
      );

  @override
  CacheEntry<int> friends() => SimpleCacheEntry(
        cache: this,
        path: 'friends',
        name: null,
        isPersistent: false,
        maxAge: const Duration(microseconds: 2000000),
        fromJson: (json) => json as int,
        toJson: null,
      );

  @override
  CacheEntry<String> friendById(int userId) => SimpleCacheEntry(
        cache: this,
        path: 'friends/${safePath(userId)}',
        name: null,
        isPersistent: false,
        maxAge: null,
        fromJson: (json) => json as String,
        toJson: null,
      );

  @override
  CacheEntry<String> search(String? query) => SimpleCacheEntry(
        cache: this,
        path: 'search/${safePath(query)}',
        name: null,
        isPersistent: false,
        maxAge: null,
        fromJson: (json) => json as String,
        toJson: null,
      );

  @override
  CacheEntry<String> likes(DateTime date) => SimpleCacheEntry(
        cache: this,
        path: 'likes/${safePath({keyDateConvertor(date)})}',
        name: null,
        isPersistent: false,
        maxAge: null,
        fromJson: (json) => json as String,
        toJson: null,
      );
}
