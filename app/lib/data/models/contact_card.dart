/// ContactCard model and its Hive TypeAdapter.
/// This is the single data object TapCard stores locally.
/// The Hive adapter is written manually — no code generation — to avoid
/// source_gen version conflicts with other dev dependencies.
library;

import 'package:hive/hive.dart';

/// Type identifier for [ContactCardAdapter] in the Hive type registry.
/// Must never be changed once the app has shipped — Hive uses it to deserialise
/// existing boxes.
const int _kContactCardTypeId = 0;

/// The single contact card a user configures in TapCard.
///
/// All fields except [fullName] and [cellPhone] are optional.
/// [photo] is intentionally excluded from the vCard / share URL — it is
/// display-only within the app (see PROJECT.md critical constraint #2).
///
/// Persisted to a Hive box named [AppConstants.contactCardBoxName].
class ContactCard {
  /// Creates a [ContactCard].
  ///
  /// [fullName] and [cellPhone] are required; all other fields default to null.
  const ContactCard({
    required this.fullName,
    required this.cellPhone,
    this.email,
    this.company,
    this.jobTitle,
    this.note,
    this.photoPath,
  });

  /// Full display name — maps to vCard FN field.
  final String fullName;

  /// Primary mobile phone number — maps to vCard TEL;TYPE=CELL.
  final String cellPhone;

  /// Email address — maps to vCard EMAIL (optional).
  final String? email;

  /// Organisation / company name — maps to vCard ORG (optional).
  final String? company;

  /// Job title / role — maps to vCard TITLE (optional).
  final String? jobTitle;

  /// Short note — maps to vCard NOTE (optional).
  final String? note;

  /// Absolute path to a locally-stored avatar image.
  /// Never included in the share URL — app-side display only.
  final String? photoPath;

  /// Returns a copy of this card with any provided fields replaced.
  ContactCard copyWith({
    String? fullName,
    String? cellPhone,
    String? email,
    String? company,
    String? jobTitle,
    String? note,
    String? photoPath,
    bool clearEmail = false,
    bool clearCompany = false,
    bool clearJobTitle = false,
    bool clearNote = false,
    bool clearPhotoPath = false,
  }) {
    return ContactCard(
      fullName: fullName ?? this.fullName,
      cellPhone: cellPhone ?? this.cellPhone,
      email: clearEmail ? null : (email ?? this.email),
      company: clearCompany ? null : (company ?? this.company),
      jobTitle: clearJobTitle ? null : (jobTitle ?? this.jobTitle),
      note: clearNote ? null : (note ?? this.note),
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
    );
  }

  @override
  String toString() => 'ContactCard(fullName: $fullName, cellPhone: $cellPhone)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactCard &&
        other.fullName == fullName &&
        other.cellPhone == cellPhone &&
        other.email == email &&
        other.company == company &&
        other.jobTitle == jobTitle &&
        other.note == note &&
        other.photoPath == photoPath;
  }

  @override
  int get hashCode => Object.hash(
        fullName,
        cellPhone,
        email,
        company,
        jobTitle,
        note,
        photoPath,
      );
}

/// Hive TypeAdapter for [ContactCard].
///
/// Written manually to avoid source_gen version conflicts.
/// Field indices are fixed — never reorder or reuse an index once shipped.
///
/// Index map:
///   0 → fullName
///   1 → cellPhone
///   2 → email
///   3 → company
///   4 → jobTitle
///   5 → note
///   6 → photoPath
class ContactCardAdapter extends TypeAdapter<ContactCard> {
  @override
  final int typeId = _kContactCardTypeId;

  @override
  ContactCard read(BinaryReader reader) {
    // Read field count, then iterate by field index.
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContactCard(
      fullName: fields[0] as String,
      cellPhone: fields[1] as String,
      email: fields[2] as String?,
      company: fields[3] as String?,
      jobTitle: fields[4] as String?,
      note: fields[5] as String?,
      photoPath: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ContactCard obj) {
    writer
      ..writeByte(7) // total field count
      ..writeByte(0)
      ..write(obj.fullName)
      ..writeByte(1)
      ..write(obj.cellPhone)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.company)
      ..writeByte(4)
      ..write(obj.jobTitle)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.photoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactCardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
