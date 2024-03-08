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
        key: 'deviceId',
        id: null,
        isPersistent: true,
        fromJson: (json) => (json as List).map((e) => e as String).toList(),
        toJson: null,
      );

  @override
  CacheEntry<User> me() => SimpleCacheEntry(
        cache: this,
        key: 'me',
        id: null,
        isPersistent: false,
        fromJson: User.fromJson,
        toJson: null,
      );

  @override
  CacheEntry<Iterable<User>> friends() => SimpleCacheEntry(
        cache: this,
        key: 'friends',
        id: null,
        isPersistent: false,
        fromJson: (json) => (json as List).map(User.fromJson).toList(),
        toJson: null,
      );

  @override
  CacheEntry<double> ageOfFriend(int userId, String friendName) =>
      SimpleCacheEntry(
        cache: this,
        key: 'ageOfFriend',
        id: null,
        isPersistent: false,
        fromJson: (json) => json as double,
        toJson: null,
      );

  @override
  CacheEntry<double?> users(int testId, int userId) => SimpleCacheEntry(
        cache: this,
        key: 'users',
        id: '$userId',
        isPersistent: false,
        fromJson: (json) => json as double?,
        toJson: null,
      );
}
