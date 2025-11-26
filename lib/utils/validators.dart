// lib/utils/validators.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
class Validators {
  // ... (Keep validateSafeText, validateReason, validateEmail as they were) ...

  static String? validateSafeText(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    final safeRegExp = RegExp(r"^[a-zA-Z0-9\s\-_,₹]+$");
    if (!safeRegExp.hasMatch(value)) {
      return 'Invalid characters in $fieldName. Only letters, numbers, spaces, and ( - _ , ₹ ) are allowed.';
    }
    return null;
  }

  static String? validateReason(String? value, {String fieldName = 'Reason'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    final reasonRegExp = RegExp(r"^[a-zA-Z0-9\s\-_,₹()]+$");
    if (!reasonRegExp.hasMatch(value)) {
      return 'Invalid characters. Only basic text and brackets ( ) are allowed.';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegExp.hasMatch(value)) return 'Enter a valid email address';
    if (value.contains("'") || value.contains('"') || value.contains(';') || value.contains('--')) {
      return 'Invalid characters in email';
    }
    return null;
  }

  /// STRICT IDs (DL, RC, etc.)
  /// Allowed: Alphanumeric, hyphens, spaces.
  static String? validateID(String? value, {String type = 'ID'}) {
    if (value == null || value.trim().isEmpty) {
      return '$type is required';
    }
    // Allow alphanumeric and hyphens/spaces (e.g. MH-12-AB-1234)
    final idRegExp = RegExp(r"^[a-zA-Z0-9\-\s]+$");

    if (!idRegExp.hasMatch(value)) {
      return 'Invalid format. Special characters are not allowed.';
    }
    return null;
  }

  // --- NEW: MAGIC BYTE VALIDATION ---

  /// Checks the ACTUAL file content (Magic Bytes), not just the extension.
  /// Returns true if the file is a real JPEG or PNG.
  static Future<bool> isValidImage(File file) async {
    if (!file.existsSync()) return false;

    try {
      // Read the first 12 bytes of the file
      final RandomAccessFile raf = await file.open(mode: FileMode.read);
      final Uint8List header = await raf.read(12);
      await raf.close();

      if (header.isEmpty) return false;

      // 1. Check for JPEG/JPG (Starts with FF D8 FF)
      if (header.length >= 3 &&
          header[0] == 0xFF &&
          header[1] == 0xD8 &&
          header[2] == 0xFF) {
        return true;
      }

      // 2. Check for PNG (Starts with 89 50 4E 47 0D 0A 1A 0A)
      if (header.length >= 8 &&
          header[0] == 0x89 &&
          header[1] == 0x50 &&
          header[2] == 0x4E &&
          header[3] == 0x47 &&
          header[4] == 0x0D &&
          header[5] == 0x0A &&
          header[6] == 0x1A &&
          header[7] == 0x0A) {
        return true;
      }

      // Add other formats (GIF, BMP) here if needed, but for high security
      // keeping it to just JPG/PNG is best.

      return false; // Not a recognized image
    } catch (e) {
      print("File Validation Error: $e");
      return false;
    }
  }
  static List<TextInputFormatter> get searchFormatters {
    return [
      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s\-_,₹]")),
    ];
  }
}