import 'dart:io';

import 'package:flutter/material.dart';

/// Resolves a captured-card image from whichever source is available: a
/// local file (captured on this device) takes priority over a remote URL
/// (fetched from the backend — e.g. a lead captured on another
/// device/session, which has no local file here) over [placeholder].
class CardImageView extends StatelessWidget {
  const CardImageView({
    super.key,
    required this.fit,
    this.localPath,
    this.remoteUrl,
    this.placeholder,
  });

  final String? localPath;
  final String? remoteUrl;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (localPath != null) {
      return Image.file(File(localPath!), fit: fit);
    }
    if (remoteUrl != null) {
      return Image.network(
        remoteUrl!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder ?? const SizedBox.shrink(),
      );
    }
    return placeholder ?? const SizedBox.shrink();
  }
}
