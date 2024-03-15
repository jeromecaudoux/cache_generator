class LocalStoreCache {
  final String name;

  const LocalStoreCache(this.name);
}

class CacheKey<T> {
  final String? name;
  final CacheFromJson<T>? fromJson;
  final CacheToJson<T>? toJson;

  const CacheKey({this.name, this.fromJson, this.toJson});
}

class KeyPart {
  final String name;

  const KeyPart(this.name);
}

class MaxAge {
  final Duration maxAge;

  const MaxAge(this.maxAge);
}

class SortBy {
  const SortBy();
}

class Persistent {
  const Persistent();
}

const sortBy = SortBy();
const persistent = Persistent();

typedef CacheFromJson<T> = T? Function(dynamic json);
typedef CacheToJson<T> = dynamic Function(T value);
