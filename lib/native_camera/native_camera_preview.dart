import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 原生相机预览 PlatformView
class NativeCameraPreview extends StatelessWidget {
  const NativeCameraPreview({super.key});

  static const viewType = 'native-camera-preview';

  @override
  Widget build(BuildContext context) {
    final params = const StandardMessageCodec().encodeMessage(null);

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        layoutDirection: TextDirection.ltr,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        layoutDirection: TextDirection.ltr,
      );
    }

    return const ColoredBox(color: Colors.black);
  }
}
