import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:cache_annotations/generators.dart';
import 'package:source_gen/source_gen.dart';

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
    if (sortBy.isEmpty) {
      return null;
    }
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
    for (String key in keyParts.keys) {
      result = result.replaceAll('{$key}', '\$${keyParts[key]}');
    }
    return result;
  }
}

class Visitor extends SimpleElementVisitor<void> {
  final String name;
  String className = '';
  List<CacheEntryMetadata> methods = [];

  Visitor(this.name);

  DartObject? _methodHasAnnotation(Type annotationType, MethodElement element) {
    final Iterable<DartObject> annotations =
        TypeChecker.fromRuntime(annotationType).annotationsOf(element);
    return annotations.firstOrNull;
  }

  @override
  void visitMethodElement(MethodElement element) {
    String returnType =
        element.returnType.getDisplayString(withNullability: true);
    RegExpMatch? match = _cacheEntryReturnRegExp.firstMatch(returnType);
    if (element.isAbstract && match != null) {
      methods.add(
        CacheEntryMetadata(
          type: match.namedGroup('type')!,
          name: element.name,
          parameters: _getParameters(element),
          sortBy: _getSortBy(element),
          key: _getKeyOfMethod(element),
          maxAge: _getMaxAge(element),
          isPersistent: _methodHasAnnotation(Persistent, element) != null,
        ),
      );
    }
    super.visitMethodElement(element);
  }

  Map<String, String> _getParameters(MethodElement element) {
    Map<String, String> parameters = {};
    for (ParameterElement parameter in element.parameters) {
      // Store every parameters to override the method
      parameters[parameter.name] = parameter.type.toString();
    }
    return parameters;
  }

  Iterable<String> _getSortBy(MethodElement element) {
    List<String> sortBy = [];
    for (ParameterElement parameter in element.parameters) {
      // Look for the key parts
      for (ElementAnnotation annotation in parameter.metadata) {
        DartObject obj = annotation.computeConstantValue()!;
        if (obj.type!
            .getDisplayString(withNullability: true)
            .startsWith('SortBy<')) {
          String? convert =
              obj.getField('convert')?.toFunctionValue()?.displayName;
          String name = convert == null
              ? parameter.name
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
    DartObject? maxAge = _methodHasAnnotation(MaxAge, element);
    Duration? duration;
    if (maxAge != null) {
      dynamic microseconds =
          maxAge.getField('maxAge')?.getField('_duration')?.toIntValue();
      if (microseconds != null) {
        duration = Duration(microseconds: microseconds);
      }
    }
    return duration;
  }

  KeyMetadata _getKeyOfMethod(MethodElement element) {
    DartObject? cacheKey = _methodHasAnnotation(CacheKey, element);
    String path = element.name;
    String? fromJson;
    String? toJson;
    if (cacheKey != null) {
      // Look for a key in the method name
      String? keyName = cacheKey.getField('path')?.toStringValue();
      if (keyName != null) {
        path = keyName;
      }

      // Look for the fromJson and toJson
      fromJson = cacheKey.getField('fromJson')?.toFunctionValue()?.displayName;
      toJson = cacheKey.getField('toJson')?.toFunctionValue()?.displayName;
    }
    Map<String, String> keyParts = {};
    for (ParameterElement parameter in element.parameters) {
      // Look for the path parts
      for (ElementAnnotation annotation in parameter.metadata) {
        DartObject obj = annotation.computeConstantValue()!;
        if (obj.type!
            .getDisplayString(withNullability: true)
            .startsWith('Path<')) {
          String name = obj.getField('name')!.toStringValue()!;
          String? convert =
              obj.getField('convert')?.toFunctionValue()?.displayName;
          if (keyParts.containsKey(name)) {
            throw Exception('The path part $name is already defined');
          }
          if (!path.contains('{$name}')) {
            throw Exception('The path part $name is not defined in: $path');
          }
          keyParts[name] = convert == null
              ? parameter.name
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
  void visitConstructorElement(ConstructorElement element) {
    className = element.returnType.toString();
  }
}
