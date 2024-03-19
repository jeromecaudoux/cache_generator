// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache.dart';

// **************************************************************************
// LocalStoreCacheGenerator
// **************************************************************************

class _Cache with LocalStoreCacheMixIn implements Cache {
  _Cache();

  @override
  String get name => "my_local_store_cache";

  @override
  CacheEntry<Iterable<String>> deviceId() => SimpleCacheEntry(
        cache: this,
        key: 'device_id',
        id: null,
        isPersistent: true,
        maxAge: null,
        fromJson: (json) => (json as List).map((e) => e as String).toList(),
        toJson: null,
      );

  @override
  CacheEntry<User> me() => SimpleCacheEntry(
        cache: this,
        key: 'me',
        id: null,
        isPersistent: false,
        maxAge: null,
        fromJson: User.fromJson,
        toJson: userToJson,
      );

  @override
  CacheEntry<int> friends() => SimpleCacheEntry(
        cache: this,
        key: 'friends',
        id: null,
        isPersistent: false,
        maxAge: const Duration(microseconds: 2000000),
        fromJson: (json) => json as int,
        toJson: null,
      );

  @override
  CacheEntry<String> friendById(int userId) => SimpleCacheEntry(
        cache: this,
        key: 'friends/$userId',
        id: null,
        isPersistent: false,
        maxAge: null,
        fromJson: (json) => json as String,
        toJson: null,
      );
}
