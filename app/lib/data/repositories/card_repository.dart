/// Repository for persisting and reading the single ContactCard.
/// All Hive box access for contact card data goes through this class.
/// Feature code must never access Hive directly.
library;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/contact_card.dart';
import '../../core/constants.dart';

/// Provides read/write access to the locally-stored [ContactCard].
///
/// TapCard stores exactly one contact card at Hive key [_kCardKey].
/// All methods are safe to call from any isolate because Hive handles
/// serialisation internally.
///
/// Throws [HiveError] on storage failure — callers must handle this.
class CardRepository {
  /// The Hive key under which the single card is stored.
  static const String _kCardKey = 'card';

  /// Opens the Hive box. Must be called once during app initialisation,
  /// after [Hive.initFlutter()] and adapter registration.
  ///
  /// Returns the opened box for convenience, but callers should not
  /// hold a reference — use the repository methods instead.
  static Future<Box<ContactCard>> openBox() {
    return Hive.openBox<ContactCard>(AppConstants.contactCardBoxName);
  }

  Box<ContactCard> get _box =>
      Hive.box<ContactCard>(AppConstants.contactCardBoxName);

  // ─── Queries ─────────────────────────────────────────────────────────────────

  /// Returns [true] if the user has saved a contact card.
  bool hasCard() => _box.containsKey(_kCardKey);

  /// Returns the saved [ContactCard], or [null] if none exists.
  ContactCard? read() => _box.get(_kCardKey);

  // ─── Mutations ───────────────────────────────────────────────────────────────

  /// Saves [card], replacing any previously stored card.
  ///
  /// Throws [HiveError] if the write fails (disk full, box closed, etc.).
  Future<void> save(ContactCard card) async {
    try {
      await _box.put(_kCardKey, card);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CardRepository] save failed: $e');
      }
      rethrow;
    }
  }

  /// Deletes the stored card. Safe to call when no card exists (idempotent).
  Future<void> delete() async {
    try {
      await _box.delete(_kCardKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CardRepository] delete failed: $e');
      }
      rethrow;
    }
  }

  /// Returns a [ValueListenable] that emits the box whenever the card changes.
  /// Use with [ValueListenableBuilder] for reactive UI updates.
  ValueListenable<Box<ContactCard>> listenable() => _box.listenable();
}
