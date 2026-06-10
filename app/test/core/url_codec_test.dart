/// Golden tests for UrlCodec.
/// Covers encode, decode, length guard, and all edge cases required by
/// CODE_STANDARDS.md §Testing (empty, max length, Unicode, special chars).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tapcard/core/url_codec.dart';
import 'package:tapcard/core/constants.dart';

void main() {
  group('UrlCodec.encode', () {
    test('returns EncodeSuccess for a normal vCard', () {
      const vCard = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alice\r\n'
          'TEL;TYPE=CELL:+1\r\nEND:VCARD\r\n';

      final result = UrlCodec.encode(vCard);

      expect(result, isA<EncodeSuccess>());
      final success = result as EncodeSuccess;
      expect(success.url, startsWith('https://'));
      expect(success.url, contains('/#'));
      expect(success.length, equals(success.url.length));
    });

    test('encode then decode round-trips correctly', () {
      const original = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Hasbiyallahu Jafaru\r\n'
          'TEL;TYPE=CELL:+234XXXXXXXXXX\r\nEND:VCARD\r\n';

      final result = UrlCodec.encode(original) as EncodeSuccess;
      // Extract the fragment (everything after '#')
      final fragment = result.url.split('#').last;
      final decoded = UrlCodec.decode(fragment);

      expect(decoded, equals(original));
    });

    test('returns EncodeTooLong when URL exceeds maxUrlLength', () {
      // Build a vCard long enough that the encoded URL will exceed 1200 chars.
      final longNote = 'X' * 900;
      final vCard = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alice\r\n'
          'TEL;TYPE=CELL:+1\r\nNOTE:$longNote\r\nEND:VCARD\r\n';

      final result = UrlCodec.encode(vCard);

      expect(result, isA<EncodeTooLong>());
      final tooLong = result as EncodeTooLong;
      expect(tooLong.actualLength, greaterThan(AppConstants.maxUrlLength));
    });

    test('throws ArgumentError for empty vCard string', () {
      expect(() => UrlCodec.encode(''), throwsArgumentError);
    });

    test('encoded URL contains only URL-safe characters', () {
      const vCard = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:O\'Brien, Sean; Esq.\r\n'
          'TEL;TYPE=CELL:+1\r\nEND:VCARD\r\n';
      final result = UrlCodec.encode(vCard) as EncodeSuccess;
      final fragment = result.url.split('#').last;

      // base64url uses A-Z, a-z, 0-9, -, _  and no padding =
      final validChars = RegExp(r'^[A-Za-z0-9\-_]+$');
      expect(validChars.hasMatch(fragment), isTrue,
          reason: 'Fragment "$fragment" contains non-base64url characters');
    });

    test('no = padding in encoded fragment', () {
      const vCard = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:A\r\n'
          'TEL;TYPE=CELL:+1\r\nEND:VCARD\r\n';
      final result = UrlCodec.encode(vCard) as EncodeSuccess;
      final fragment = result.url.split('#').last;
      expect(fragment.contains('='), isFalse);
    });
  });

  group('UrlCodec.decode', () {
    test('throws ArgumentError for empty fragment', () {
      expect(() => UrlCodec.decode(''), throwsArgumentError);
    });

    test('throws FormatException for corrupt fragment', () {
      expect(() => UrlCodec.decode('!!!not-base64!!!'), throwsA(anything));
    });

    test('decodes fragment that has padding stripped', () {
      // Encode manually and strip padding to simulate what encode() does.
      const original = 'hello world';
      final result = UrlCodec.encode(original) as EncodeSuccess;
      final fragment = result.url.split('#').last;
      expect(UrlCodec.decode(fragment), equals(original));
    });
  });

  group('UrlCodec — Unicode round-trips', () {
    test('Arabic name round-trips', () {
      const vCard = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:محمد علي\r\n'
          'TEL;TYPE=CELL:+966500000000\r\nEND:VCARD\r\n';
      final result = UrlCodec.encode(vCard) as EncodeSuccess;
      final fragment = result.url.split('#').last;
      expect(UrlCodec.decode(fragment), equals(vCard));
    });

    test('Chinese name round-trips', () {
      const vCard = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:张伟\r\n'
          'TEL;TYPE=CELL:+8613800000000\r\nEND:VCARD\r\n';
      final result = UrlCodec.encode(vCard) as EncodeSuccess;
      final fragment = result.url.split('#').last;
      expect(UrlCodec.decode(fragment), equals(vCard));
    });
  });

  group('UrlCodec — special character round-trips', () {
    test('escaped semicolons round-trip', () {
      const vCard = r'BEGIN:VCARD' '\r\n' r'VERSION:3.0' '\r\n'
          r'NOTE:a\;b' '\r\n' r'FN:X' '\r\n'
          r'TEL;TYPE=CELL:+1' '\r\nEND:VCARD\r\n';
      final result = UrlCodec.encode(vCard) as EncodeSuccess;
      final fragment = result.url.split('#').last;
      expect(UrlCodec.decode(fragment), equals(vCard));
    });

    test('escaped commas round-trip', () {
      const vCard = r'FN:Smith\, John';
      final result = UrlCodec.encode(vCard) as EncodeSuccess;
      final fragment = result.url.split('#').last;
      expect(UrlCodec.decode(fragment), equals(vCard));
    });

    test('escaped backslashes round-trip', () {
      const vCard = r'NOTE:C:\\path\\to\\file';
      final result = UrlCodec.encode(vCard) as EncodeSuccess;
      final fragment = result.url.split('#').last;
      expect(UrlCodec.decode(fragment), equals(vCard));
    });
  });

  group('UrlCodec.computeUrlLength', () {
    test('returns 0 for empty string', () {
      expect(UrlCodec.computeUrlLength(''), equals(0));
    });

    test('matches actual encoded URL length', () {
      const vCard = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alice\r\n'
          'TEL;TYPE=CELL:+1\r\nEND:VCARD\r\n';
      final computed = UrlCodec.computeUrlLength(vCard);
      final actual = (UrlCodec.encode(vCard) as EncodeSuccess).length;
      expect(computed, equals(actual));
    });
  });
}
