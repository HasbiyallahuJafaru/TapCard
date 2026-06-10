/// Riverpod provider for the NfcChannel platform wrapper.
/// All feature code that interacts with NFC must go through this provider —
/// never construct NfcChannel directly in a widget.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/nfc_channel.dart';

/// Provides the single [NfcChannel] instance used throughout the app.
///
/// [NfcChannel] is stateless — it is a thin typed wrapper around a
/// [MethodChannel]. A single instance is safe to share across the app.
final nfcChannelProvider = Provider<NfcChannel>((ref) {
  return NfcChannel();
});
