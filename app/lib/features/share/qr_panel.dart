/// QR code bottom sheet for the share screen.
/// Slides up from below the fold, shows the share URL as a QR code,
/// and provides a "Copy link" button. Visual spec: UI_DIRECTION.md §QR Panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/colours.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../core/widgets/pressable_widget.dart';

/// Shows the QR panel as a modal bottom sheet.
///
/// [shareUrl] — the full `https://…/#…` URL to encode in the QR.
///
/// Slides up with [AppTokens.entrance] duration. Can be swiped down to dismiss.
void showQrPanel(BuildContext context, {required String shareUrl}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => _QrPanelContent(shareUrl: shareUrl),
  );
}

/// The content widget rendered inside the bottom sheet.
class _QrPanelContent extends StatelessWidget {
  const _QrPanelContent({required this.shareUrl});

  final String shareUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColours.bgSecondary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTokens.radiusLg),
          topRight: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            const SizedBox(height: AppTokens.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColours.textDisabled,
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              ),
            ),
            const SizedBox(height: AppTokens.xl),

            // QR code — white background, radius clipped.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.xxl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                child: QrImageView(
                  data: shareUrl,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  padding: const EdgeInsets.all(AppTokens.md),
                ),
              ),
            ),

            const SizedBox(height: AppTokens.md),

            // Caption.
            Text(
              'SCAN WITH ANY CAMERA',
              style: AppTypography.label(size: 10, uppercase: true),
            ),

            const SizedBox(height: AppTokens.xl),

            // Copy link button.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: _CopyLinkButton(shareUrl: shareUrl),
            ),

            const SizedBox(height: AppTokens.xxl),
          ],
        ),
      ),
    );
  }
}

/// Outlined "Copy link" button that copies the share URL to the clipboard.
class _CopyLinkButton extends StatefulWidget {
  const _CopyLinkButton({required this.shareUrl});

  final String shareUrl;

  @override
  State<_CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends State<_CopyLinkButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.shareUrl));
    if (!mounted) return;
    setState(() => _copied = true);
    // Reset label after 2 seconds.
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return PressableWidget(
      onTap: _copy,
      child: Container(
        width: double.infinity,
        height: AppTokens.minTouchTarget + 4,
        decoration: BoxDecoration(
          border: Border.all(color: AppColours.divider),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(
          _copied ? 'Copied!' : 'Copy Link',
          style: AppTypography.bodyMedium(size: 15).copyWith(
            color: _copied ? AppColours.success : AppColours.textPrimary,
          ),
        ),
      ),
    );
  }
}
