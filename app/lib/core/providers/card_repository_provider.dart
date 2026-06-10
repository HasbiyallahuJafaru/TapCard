/// Riverpod providers for CardRepository and the current ContactCard.
/// All feature code that needs card data must read from these providers —
/// never instantiate CardRepository directly outside of this file.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/contact_card.dart';
import '../../data/repositories/card_repository.dart';

/// Provides the single [CardRepository] instance.
///
/// The repository itself is synchronous (Hive is already open at app start).
/// Any screen that reads or writes card data depends on this provider.
final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository();
});

/// Provides the currently saved [ContactCard], or [null] if none has been saved.
///
/// This provider is intentionally not reactive via a stream — the card changes
/// rarely (only on editor save). Screens that need fresh data after a save
/// should call [ref.invalidate(contactCardProvider)] to force a re-read,
/// or simply navigate away and back (which rebuilds the widget tree).
final contactCardProvider = Provider<ContactCard?>((ref) {
  return ref.watch(cardRepositoryProvider).read();
});
