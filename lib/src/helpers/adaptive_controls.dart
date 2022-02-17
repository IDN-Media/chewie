import 'package:chewie/src/material/material_desktop_controls.dart';
import 'package:flutter/material.dart';

class AdaptiveControls extends StatelessWidget {
  const AdaptiveControls({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Customised: Everything use MaterialDesktopControls
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return const MaterialDesktopControls();

      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return const MaterialDesktopControls();

      case TargetPlatform.iOS:
        return const MaterialDesktopControls();
      default:
        return const MaterialDesktopControls();
    }
  }
}
