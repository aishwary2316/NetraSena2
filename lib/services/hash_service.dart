// lib/services/hash_service.dart
import 'dart:convert'; // for utf8.encode
import 'package:crypto/crypto.dart'; // for sha256

class HashService {
  // STATIC SALT (PEPPER):
  // Hardcode a long, random string here.
  // WARNING: Keep this secret. If you change it, no one can log in until they reset their password.
  static const String _clientSalt = 'Abra_Ca_Dabra!_@616D7269736861@_#Khulja_Sim_Sim#_!@#';

  /// Hashes the password with the static salt using SHA-256
  String hashPassword(String plainPassword) {
    if (plainPassword.isEmpty) return "";

    // Combine password with salt
    final bytes = utf8.encode(plainPassword + _clientSalt);

    // Generate SHA-256 Hash
    final digest = sha256.convert(bytes);

    // Return as Hex String
    return digest.toString();
  }
}