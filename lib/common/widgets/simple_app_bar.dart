import 'package:PiliPlus/common/widgets/haze/haze.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

class SimpleAppBar extends StatelessWidget {
  const SimpleAppBar({
    super.key,
    required this.height,
    required this.brightness,
    this.statusBarBrightness = .dark,
    this.statusBarIconBrightness = .light,
    this.backgroundColor = Colors.black,
  });

  final double height;
  final Brightness brightness;
  final Brightness statusBarBrightness;
  final Brightness statusBarIconBrightness;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final Widget bar = Pref.enableHaze && Pref.hazeScrollEdge
        ? HazeProgressiveBlur(
            edge: .top,
            span: height,
            sigma: 22,
            tint: backgroundColor.withValues(alpha: 0.35),
            child: SizedBox(height: height, width: .infinity),
          )
        : ColoredBox(
            color: backgroundColor,
            child: SizedBox(height: height, width: .infinity),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: statusBarBrightness,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: brightness.reverse,
      ),
      child: bar,
    );
  }
}
