/// Typed Dart wrapper for the tapcard/widget platform channel.
///
/// Registers the [armFromWidget] reverse handler so the Kotlin Glance widget
/// can notify the Flutter app when it arms NFC directly (without launching the app).
/// See .claude/PLATFORM_CHANNEL.md §Channel: tapcard/widget.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/arm_state_provider.dart';

/// CHANNEL_VERSION must match the value in TapCardWidgetReceiver.kt.
const int _widgetChannelVersion = 1;

/// Sets up the [tapcard/widget] channel reverse handler.
///
/// Must be called once after the Riverpod [ProviderContainer] is ready (called
/// from [main.dart] after [runApp]). Listens for [armFromWidget] calls from Kotlin
/// and updates [armStateProvider] when the app is in the foreground.
void registerWidgetChannelHandler(WidgetRef ref) {
  _WidgetChannel._instance._register(ref);
}

class _WidgetChannel {
  _WidgetChannel._();

  static final _WidgetChannel _instance = _WidgetChannel._();

  static const _channel = MethodChannel('tapcard/widget');

  // ignore: unused_field
  static const int channelVersion = _widgetChannelVersion;

  void _register(WidgetRef ref) {
    _channel.setMethodCallHandler((call) async {
      if (kDebugMode) debugPrint('[WidgetChannel] ← ${call.method}');
      switch (call.method) {
        case 'armFromWidget':
          // Widget armed NFC directly — sync Flutter state if in foreground.
          final remainingSec = (call.arguments as Map?)?.cast<String, dynamic>()['remainingSec'] as int? ?? 60;
          _onArmFromWidget(ref, remainingSec);
        default:
          throw MissingPluginException('Unknown widget channel method: ${call.method}');
      }
    });
  }

  void _onArmFromWidget(WidgetRef ref, int remainingSec) {
    // Widget already armed HCE in Kotlin — just update Flutter's view of the state.
    // We don't call arm() again (that would double-arm). Instead, directly set state.
    if (kDebugMode) debugPrint('[WidgetChannel] armFromWidget remainingSec=$remainingSec');
    ref.read(armStateProvider.notifier).syncArmFromWidget(remainingSec);
  }
}
