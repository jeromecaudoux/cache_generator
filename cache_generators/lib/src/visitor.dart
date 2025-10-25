// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor2.dart';
import 'package:cache_annotations/generators.dart';

RegExp _cacheEntryReturnRegExp =
    RegExp(r'^CacheEntry<(?<type>[a-zA-Z<>]+\??)>$');

class CacheEntryMetadata {
  final String type;
  final String name;
  final Map<String, String> parameters;
  final Iterable<String> sortBy;
  final KeyMetadata key;
  final Duration? maxAge;
  final bool isPersistent;

  CacheEntryMetadata({
    required this.type,
    required this.name,
    required this.parameters,
    required this.sortBy,
    required this.key,
    required this.maxAge,
    required this.isPersistent,
  });

  String? formatSortBy() {
    if (sortBy.isEmpty) return null;
    return sortBy.map((e) => '\$$e').join('-');
  }

  @override
  String toString() {
    return 'CacheEntryMetadata{type: $type, name: $name, '
        'parameters: $parameters, sortBy: $sortBy, key: $key, '
        'isPersistent: $isPersistent}';
  }
}

class KeyMetadata {
  final String path;
  final Map<String, String> keyParts;
  final String? fromJson;
  final String? toJson;

  KeyMetadata(
    this.path, {
    this.keyParts = const {},
    this.fromJson,
    this.toJson,
  });

  String formatPath() {
    String result = path;
    for (final key in keyParts.keys) {
      result = result.replaceAll('{$key}', '\${safePath(${keyParts[key]})}');
    }
    return result;
  }
}

class Visitor extends SimpleElementVisitor2<Object?> {
  final String name;
  String className = '';
  List<CacheEntryMetadata> methods = [];

  Visitor(this.name);

  DartObject? _methodHasAnnotation(Type annotationType, MethodElement element) {
    final want = annotationType.toString().split('<').first;
    for (final a in element.metadata.annotations) {
      final obj = a.computeConstantValue();
      final typeName =
          obj?.type?.getDisplayString(withNullability: false).split('<').first;
      if (typeName == want) return obj;
    }
    return null;
  }

  @override
  Object? visitMethodElement(MethodElement element) {
    final returnType =
        element.returnType.getDisplayString(withNullability: true);
    final match = _cacheEntryReturnRegExp.firstMatch(returnType);

    if (element.isAbstract && match != null) {
      methods.add(
        CacheEntryMetadata(
          type: match.namedGroup('type')!,
          name: element.name!,
          parameters: _getParameters(element),
          sortBy: _getSortBy(element),
          key: _getKeyOfMethod(element),
          maxAge: _getMaxAge(element),
          isPersistent: _methodHasAnnotation(Persistent, element) != null,
        ),
      );
    }
    return null;
  }

  Map<String, String> _getParameters(MethodElement element) {
    final Map<String, String> parameters = {};
    for (final parameter in element.formalParameters) {
      parameters[parameter.name!] = parameter.type.toString();
    }
    return parameters;
  }

  Iterable<String> _getSortBy(MethodElement element) {
    final List<String> sortBy = [];
    for (final parameter in element.formalParameters) {
      for (final annotation in parameter.metadata.annotations) {
        final obj = annotation.computeConstantValue();
        if (obj == null) continue;

        final typeName =
            obj.type?.getDisplayString(withNullability: false) ?? '';
        if (typeName.startsWith('SortBy<')) {
          final convert =
              obj.getField('convert')?.toFunctionValue()?.displayName;
          final name = convert == null
              ? parameter.name!
              : '{$convert(${parameter.name})}';
          if (sortBy.contains(name)) {
            throw Exception('The sortBy $name is already defined');
          }
          sortBy.add(name);
        }
      }
    }
    return sortBy;
  }

  Duration? _getMaxAge(MethodElement element) {
    final maxAge = _methodHasAnnotation(MaxAge, element);
    Duration? duration;
    if (maxAge != null) {
      final microseconds =
          maxAge.getField('maxAge')?.getField('_duration')?.toIntValue();
      if (microseconds != null) {
        duration = Duration(microseconds: microseconds);
      }
    }
    return duration;
  }

  KeyMetadata _getKeyOfMethod(MethodElement element) {
    final cacheKey = _methodHasAnnotation(Cached, element) ??
        _methodHasAnnotation(CacheKey, element);

    String path = element.name!;
    String? fromJson;
    String? toJson;

    if (cacheKey != null) {
      final keyName = cacheKey.getField('path')?.toStringValue();
      if (keyName != null) path = keyName;
      fromJson = cacheKey.getField('fromJson')?.toFunctionValue()?.displayName;
      toJson = cacheKey.getField('toJson')?.toFunctionValue()?.displayName;
    }

    final Map<String, String> keyParts = {};
    for (final parameter in element.formalParameters) {
      for (final annotation in parameter.metadata.annotations) {
        final obj = annotation.computeConstantValue();
        if (obj == null) continue;

        final typeName =
            obj.type?.getDisplayString(withNullability: false) ?? '';
        if (typeName.startsWith('Path<')) {
          final name = obj.getField('name')!.toStringValue()!;
          final convert =
              obj.getField('convert')?.toFunctionValue()?.displayName;

          if (keyParts.containsKey(name)) {
            throw Exception('The path part $name is already defined');
          }
          if (!path.contains('{$name}')) {
            throw Exception('The path part "$name" is not defined in: "$path"');
          }

          keyParts[name] = convert == null
              ? parameter.name!
              : '{$convert(${parameter.name})}';
        }
      }
    }

    return KeyMetadata(
      path,
      keyParts: keyParts,
      fromJson: fromJson,
      toJson: toJson,
    );
  }

  @override
  Object? visitConstructorElement(ConstructorElement element) {
    className = element.returnType.getDisplayString(withNullability: true);
    return null;
  }
}
