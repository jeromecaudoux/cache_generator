class LocalStoreCache {
  final String name;

  const LocalStoreCache(this.name);
}

class CacheKey {
  final String? name;
  final CacheFromJson? fromJson;
  final CacheToJson? toJson;

  const CacheKey({this.name, this.fromJson, this.toJson});
}

class KeyPart {
  final String name;

  const KeyPart(this.name);
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
