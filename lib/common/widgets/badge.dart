import 'package:PiliPlus/common/m3e/shapes.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:material_ui/material_ui.dart';

class PBadge extends StatelessWidget {
  final String? text;

  final bool isStack;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final EdgeInsets? padding;

  final PBadgeType type;
  final PBadgeSize size;

  final double fontSize;
  final bool isBold;
  final double? textScaleFactor;

  const PBadge({
    super.key,
    required this.text,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.type = PBadgeType.primary,
    this.size = PBadgeSize.medium,
    this.isStack = true,
    this.fontSize = 11,
    this.isBold = true,
    this.textScaleFactor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isNullOrEmpty) {
      return const SizedBox.shrink();
    }

    ColorScheme theme = Theme.of(context).colorScheme;

    Color bgColor;
    Color color;
    Color borderColor = Colors.transparent;

    switch (type) {
      case PBadgeType.primary:
        bgColor = theme.primary;
        color = theme.onPrimary;
      case PBadgeType.secondary:
        bgColor = theme.secondaryContainer.withValues(alpha: 0.5);
        color = theme.onSecondaryContainer;
      case PBadgeType.gray:
        bgColor = theme.scrim.withValues(alpha: 0.64);
        color = Colors.white;
      case PBadgeType.error:
        if (theme.isDark) {
          bgColor = theme.errorContainer;
          color = theme.onErrorContainer;
        } else {
          bgColor = theme.error;
          color = theme.onError;
        }
      case PBadgeType.line_primary:
        color = theme.primary;
        bgColor = Colors.transparent;
        borderColor = theme.primary;
      case PBadgeType.line_secondary:
        color = theme.secondary;
        bgColor = Colors.transparent;
        borderColor = theme.secondary;
      case PBadgeType.free:
        bgColor = theme.freeColor;
        color = Colors.white;
      case PBadgeType.shop:
        bgColor = theme.secondaryContainer.withValues(alpha: 0.5);
        color = theme.onSurfaceVariant;
    }

    late EdgeInsets paddingStyle = const .symmetric(vertical: 2, horizontal: 3);
    final RoundedSuperellipseBorder shape = M3EShape.all(
      size == .small ? M3ECorner.xs : 6,
    );

    Widget content = Container(
      padding: padding ?? paddingStyle,
      decoration: ShapeDecoration(
        shape: borderColor == Colors.transparent
            ? shape
            : shape.copyWith(side: BorderSide(color: borderColor)),
        color: bgColor,
      ),
      child: Text(
        text!,
        textScaler: textScaleFactor != null ? .linear(textScaleFactor!) : null,
        style: TextStyle(
          height: 1,
          fontSize: fontSize,
          color: color,
          fontWeight: isBold ? FontWeight.bold : null,
        ),
        strutStyle: StrutStyle(
          leading: 0,
          height: 1,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : null,
        ),
      ),
    );
    if (isStack) {
      return Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: content,
      );
    } else {
      return content;
    }
  }
}
