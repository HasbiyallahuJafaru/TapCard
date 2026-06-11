/// Golden tests for VCardBuilder.
/// Every function in vcard_builder.dart is tested here, including all
/// escaping edge cases. See CODE_STANDARDS.md §Testing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tapcard/core/vcard_builder.dart';
import 'package:tapcard/data/models/contact_card.dart';

void main() {
  group('VCardBuilder.build', () {
    test('minimal card — required fields only', () {
      final card = ContactCard(
        fullName: 'Alice Smith',
        cellPhone: '+2341234567890',
      );

      final vCard = VCardBuilder.build(card);

      expect(vCard, equals(
        'BEGIN:VCARD\r\n'
        'VERSION:3.0\r\n'
        'FN:Alice Smith\r\n'
        'TEL;TYPE=CELL:+2341234567890\r\n'
        'END:VCARD\r\n',
      ));
    });

    test('full card — all optional fields included', () {
      final card = ContactCard(
        fullName: 'Hasbiyallahu Jafaru',
        cellPhone: '+234XXXXXXXXXX',
        email: 'hello@tapcard.app',
        company: 'TapCard',
        jobTitle: 'Founder',
        note: 'Connect on LinkedIn',
        linkedIn: 'https://linkedin.com/in/hasbiyallahu',
      );

      final vCard = VCardBuilder.build(card);

      expect(vCard, equals(
        'BEGIN:VCARD\r\n'
        'VERSION:3.0\r\n'
        'FN:Hasbiyallahu Jafaru\r\n'
        'ORG:TapCard\r\n'
        'TITLE:Founder\r\n'
        'TEL;TYPE=CELL:+234XXXXXXXXXX\r\n'
        'EMAIL:hello@tapcard.app\r\n'
        'NOTE:Connect on LinkedIn\r\n'
        'URL;TYPE=LinkedIn:https://linkedin.com/in/hasbiyallahu\r\n'
        'END:VCARD\r\n',
      ));
    });

    test('linkedIn URL included when provided', () {
      final card = ContactCard(
        fullName: 'Alice',
        cellPhone: '+1',
        linkedIn: 'https://linkedin.com/in/alice',
      );
      final vCard = VCardBuilder.build(card);
      expect(vCard.contains('URL;TYPE=LinkedIn:https://linkedin.com/in/alice\r\n'), isTrue);
    });

    test('linkedIn omitted when null or empty', () {
      final card = ContactCard(fullName: 'Alice', cellPhone: '+1');
      expect(VCardBuilder.build(card).contains('URL'), isFalse);

      final cardEmpty = ContactCard(fullName: 'Alice', cellPhone: '+1', linkedIn: '   ');
      expect(VCardBuilder.build(cardEmpty).contains('URL'), isFalse);
    });

    test('optional fields omitted when null', () {
      final card = ContactCard(
        fullName: 'Bob',
        cellPhone: '+10000000000',
        email: null,
        company: null,
        jobTitle: null,
        note: null,
      );

      final vCard = VCardBuilder.build(card);

      expect(vCard.contains('ORG:'), isFalse);
      expect(vCard.contains('TITLE:'), isFalse);
      expect(vCard.contains('EMAIL:'), isFalse);
      expect(vCard.contains('NOTE:'), isFalse);
      expect(vCard.contains('URL'), isFalse);
    });

    test('optional fields omitted when empty string', () {
      final card = ContactCard(
        fullName: 'Bob',
        cellPhone: '+10000000000',
        email: '',
        company: '   ',
        jobTitle: '',
        note: '   ',
        linkedIn: '   ',
      );

      final vCard = VCardBuilder.build(card);

      expect(vCard.contains('ORG:'), isFalse);
      expect(vCard.contains('TITLE:'), isFalse);
      expect(vCard.contains('EMAIL:'), isFalse);
      expect(vCard.contains('NOTE:'), isFalse);
      expect(vCard.contains('URL'), isFalse);
    });

    test('throws ArgumentError for empty fullName', () {
      expect(
        () => VCardBuilder.build(ContactCard(fullName: '', cellPhone: '+1')),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for whitespace-only fullName', () {
      expect(
        () => VCardBuilder.build(ContactCard(fullName: '   ', cellPhone: '+1')),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for empty cellPhone', () {
      expect(
        () => VCardBuilder.build(ContactCard(fullName: 'Alice', cellPhone: '')),
        throwsArgumentError,
      );
    });

    test('all lines end with CRLF', () {
      final card = ContactCard(
        fullName: 'Alice',
        cellPhone: '+1',
        company: 'Corp',
      );
      final vCard = VCardBuilder.build(card);
      // Every line (split on \r\n) except the last empty string should be non-empty.
      final lines = vCard.split('\r\n');
      // Last element is an empty string after the trailing \r\n — expected.
      expect(lines.last, isEmpty);
      expect(lines.length, greaterThan(1));
    });

    test('photoPath is excluded from the vCard output', () {
      final card = ContactCard(
        fullName: 'Alice',
        cellPhone: '+1',
        photoPath: '/storage/photos/alice.jpg',
      );
      final vCard = VCardBuilder.build(card);
      expect(vCard.contains('PHOTO'), isFalse);
      expect(vCard.contains('alice.jpg'), isFalse);
    });

    // ── Unicode ───────────────────────────────────────────────────────────────

    test('unicode name — Arabic', () {
      final card = ContactCard(
        fullName: 'محمد علي',
        cellPhone: '+966500000000',
      );
      final vCard = VCardBuilder.build(card);
      expect(vCard.contains('FN:محمد علي\r\n'), isTrue);
    });

    test('unicode name — Chinese', () {
      final card = ContactCard(
        fullName: '张伟',
        cellPhone: '+8613800000000',
      );
      final vCard = VCardBuilder.build(card);
      expect(vCard.contains('FN:张伟\r\n'), isTrue);
    });
  });

  // ── VCardBuilder.escape (and the underlying _escape logic) ────────────────

  group('VCardBuilder.escape', () {
    test('plain text — unchanged', () {
      expect(VCardBuilder.escape('Hello World'), equals('Hello World'));
    });

    test('backslash is escaped to double-backslash', () {
      expect(VCardBuilder.escape(r'C:\path'), equals(r'C:\\path'));
    });

    test('semicolon is escaped', () {
      expect(VCardBuilder.escape('a;b'), equals(r'a\;b'));
    });

    test('comma is escaped', () {
      expect(VCardBuilder.escape('a,b'), equals(r'a\,b'));
    });

    test('newline (0x0A) becomes literal backslash-n', () {
      expect(VCardBuilder.escape('line1\nline2'), equals(r'line1\nline2'));
    });

    test('carriage return (0x0D) is stripped', () {
      expect(VCardBuilder.escape('line1\r\nline2'), equals(r'line1\nline2'));
    });

    test('escape order: backslash before semicolon avoids double-escape', () {
      // Input contains a literal backslash followed by a semicolon.
      // If semicolons were processed first: \; → \\; → \\\;  (wrong)
      // If backslashes processed first: \ → \\ then ; → \;  (correct → \\;)
      expect(VCardBuilder.escape(r'\;'), equals(r'\\\;'));
    });

    test('all special characters together', () {
      // Input chars: a \ b ; c , d \n(0x0A) e \r(0x0D) f
      // Step 1: \ → \\  → a\\b;c,d\ne\rf   (0x0A and 0x0D are not backslashes)
      // Step 2: ; → \;  → a\\b\;c,d\ne\rf
      // Step 3: , → \,  → a\\b\;c\,d\ne\rf
      // Step 4: strip \r → a\\b\;c\,d\nef   (0x0D removed, 'e' and 'f' collapse)
      // Step 5: \n → \n (literal) → a\\b\;c\,d\nef
      final input = 'a\\b;c,d\ne\rf';
      expect(VCardBuilder.escape(input), equals(r'a\\b\;c\,d\nef'));
    });

    test('empty string — unchanged', () {
      expect(VCardBuilder.escape(''), equals(''));
    });

    test('unicode is preserved through escape', () {
      expect(VCardBuilder.escape('张伟;محمد'), equals(r'张伟\;محمد'));
    });
  });
}
