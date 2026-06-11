/// Builds a vCard 3.0 string from a ContactCard model.
/// This file is NOT responsible for URL encoding — see url_codec.dart.
/// Escaping rules follow RFC 2426 §5 and the spec in .claude/NFC_SPEC.md.
library;

import '../data/models/contact_card.dart';

/// Builds vCard 3.0 strings from [ContactCard] instances.
///
/// The vCard format is used as the payload for NFC sharing and QR codes.
/// All fields are escaped according to RFC 2426 before insertion.
/// Lines are terminated with CRLF (\r\n) as required by the spec.
///
/// Escaping order (CRITICAL — must be applied in sequence):
///   1. Backslash → \\
///   2. Semicolons → \;
///   3. Commas → \,
///   4. Newlines → \n  (literal backslash + n, not a newline character)
abstract final class VCardBuilder {
  VCardBuilder._();

  /// Builds a complete vCard 3.0 string from [card].
  ///
  /// Required fields (always present): FN, TEL;TYPE=CELL.
  /// Optional fields (included only when non-null and non-empty):
  ///   ORG, TITLE, EMAIL, NOTE.
  ///
  /// Returns the full vCard string with CRLF line endings.
  ///
  /// Throws [ArgumentError] if [card.fullName] or [card.cellPhone] is empty
  /// after trimming.
  static String build(ContactCard card) {
    final name = card.fullName.trim();
    final phone = card.cellPhone.trim();

    if (name.isEmpty) {
      throw ArgumentError.value(card.fullName, 'card.fullName', 'must not be empty');
    }
    if (phone.isEmpty) {
      throw ArgumentError.value(card.cellPhone, 'card.cellPhone', 'must not be empty');
    }

    final buffer = StringBuffer();

    buffer.write('BEGIN:VCARD\r\n');
    buffer.write('VERSION:3.0\r\n');
    buffer.write('FN:${_escape(name)}\r\n');

    // N: is required by iOS — without it the contact is silently dropped.
    // Split on last space for given/family; fall back to name as family name only.
    final spaceIdx = name.lastIndexOf(' ');
    final familyName = spaceIdx >= 0 ? _escape(name.substring(spaceIdx + 1)) : _escape(name);
    final givenName  = spaceIdx >= 0 ? _escape(name.substring(0, spaceIdx))  : '';
    buffer.write('N:$familyName;$givenName;;;\r\n');

    // Optional fields — include only when non-null and non-empty after trimming.
    final company = card.company?.trim();
    if (company != null && company.isNotEmpty) {
      buffer.write('ORG:${_escape(company)}\r\n');
    }

    final title = card.jobTitle?.trim();
    if (title != null && title.isNotEmpty) {
      buffer.write('TITLE:${_escape(title)}\r\n');
    }

    buffer.write('TEL;TYPE=CELL:${_escape(phone)}\r\n');

    final email = card.email?.trim();
    if (email != null && email.isNotEmpty) {
      buffer.write('EMAIL:${_escape(email)}\r\n');
    }

    final note = card.note?.trim();
    if (note != null && note.isNotEmpty) {
      buffer.write('NOTE:${_escape(note)}\r\n');
    }

    final linkedIn = card.linkedIn?.trim();
    if (linkedIn != null && linkedIn.isNotEmpty) {
      buffer.write('URL;TYPE=LinkedIn:${_escape(linkedIn)}\r\n');
    }

    buffer.write('END:VCARD\r\n');

    return buffer.toString();
  }

  /// Escapes a single field value for safe inclusion in a vCard property.
  ///
  /// Escape order is load-bearing — backslash must be escaped first to avoid
  /// double-escaping characters that were already backslashes.
  ///
  ///   1. `\`  → `\\`
  ///   2. `;`  → `\;`
  ///   3. `,`  → `\,`
  ///   4. `\n` (newline, 0x0A) → `\n` (literal two chars: backslash + n)
  ///   5. `\r` (carriage return, 0x0D) → stripped (CRLF in field values
  ///      would break the vCard line structure)
  ///
  /// Returns the escaped string.
  static String escape(String value) => _escape(value);

  // Private implementation — called internally by build().
  static String _escape(String value) {
    // Step 1 — escape backslashes FIRST (must come before all other replacements)
    String result = value.replaceAll(r'\', r'\\');

    // Step 2 — escape semicolons
    result = result.replaceAll(';', r'\;');

    // Step 3 — escape commas
    result = result.replaceAll(',', r'\,');

    // Step 4 — strip carriage returns to avoid corrupting CRLF line endings
    result = result.replaceAll('\r', '');

    // Step 5 — replace newline characters with the literal two-char sequence \n
    result = result.replaceAll('\n', r'\n');

    return result;
  }
}
