import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// Defines an interface for serializing and deserializing data.
/// This allows for different serialization formats to be used (e.g., JSON, XML).
abstract class SerializationAdapter {
  /// Serializes the given [data] map into a string representation.
  ///
  /// - [data]: A map containing key-value pairs to be serialized.
  /// - Returns: A string representing the serialized data.
  Uint8List serialize(Map<String, dynamic> data);

  /// Deserializes the given [json] string into a map.
  ///
  /// - [json]: The string representation of the data to be deserialized.
  /// - Returns: A map containing the deserialized key-value pairs.
  Map<String, dynamic> deserialize<T>(Uint8List raw);
}

class JsonSerializationAdapter implements SerializationAdapter {
  @override
  Uint8List serialize(Map<String, dynamic> data) {
    final String json = jsonEncode(data);
    return utf8.encode(json);
  }

  @override
  Map<String, dynamic> deserialize<T>(Uint8List raw) {
    final String json = utf8.decode(raw);
    return jsonDecode(json) as Map<String, dynamic>;
  }
}

/// A [SerializationAdapter] that encrypts and decrypts data using AES encryption.
///
/// This adapter first serializes the data to JSON, then encrypts the JSON string.
/// When deserializing, it decrypts the data and then parses the JSON string.
class CryptoSerializationAdapter implements SerializationAdapter {
  late final Encrypter _encrypter;

  /// Creates a [CryptoSerializationAdapter] with the given [encryptionKey].
  ///
  /// The [encryptionKey] must be a 32-byte string.
  /// An [AssertionError] will be thrown if the [encryptionKey] is not 32 bytes.
  ///
  /// - [encryptionKey]: The key used for AES encryption and decryption.
  CryptoSerializationAdapter({required String encryptionKey}) {
    assert(
      utf8.encode(encryptionKey).length == 32,
      'Encryption key must be 32 bytes long.',
    );
    _encrypter = Encrypter(AES(Key.fromUtf8(encryptionKey)));
  }

  /// Creates a [CryptoSerializationAdapter] with an encryption key derived from [any] object.
  ///
  /// The `toString()` representation of [any] is used.
  /// It is padded with '_' or truncated to ensure it's 32 bytes long.
  /// This constructor is useful for scenarios where a key needs to be generated
  /// from arbitrary input.
  ///
  /// - [any]: The object from which to derive the encryption key.
  CryptoSerializationAdapter.any(Object any) {
    String encryptionKey = any.toString().padLeft(32, '_').substring(0, 32);
    _encrypter = Encrypter(AES(Key.fromUtf8(encryptionKey)));
  }

  @override
  Uint8List serialize(Map<String, dynamic> data) {
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(jsonEncode(data), iv: iv);
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  @override
  Map<String, dynamic> deserialize<T>(Uint8List raw) {
    final iv = IV(raw.sublist(0, 16));
    final cipher = Encrypted(raw.sublist(16));
    final jsonStr = _encrypter.decrypt(cipher, iv: iv);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
