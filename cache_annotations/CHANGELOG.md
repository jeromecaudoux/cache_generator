## 1.0.9

* Add new method `deleteCollection` to delete all elements in a specific path.
* Fix unit tests

## 1.0.8

* Fix issue with `directory` not being used correctly

* ## 1.0.7

* Downgrade some dependencies to avoid conflicts

## 1.0.5

* Bump build_runner to 2.4.15

## 1.0.4

* Fix deserialization of return type `List` (only `Iterable` was supported).
* Add support to `Windows` platform.
* Add new method `all` to get all elements in a specific path.

## 1.0.3

* `@CachedKey` is now deprecated, use `@Cahed` instead
* `@SortBy` is now deprecated, use the path's field on `@Cached` instead

## 1.0.2

* Fix issue with `@Path` when an empty string is passed as a value
* Fix cached values after calling deleteAll or delete

## 1.0.1

* Add new parameter 'convert' to @Path or @SortBy to allow more customization of the path or sort by value

## 1.0.0

* Initial release 
