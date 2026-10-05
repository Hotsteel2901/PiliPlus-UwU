/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliPlus.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:PiliPlus/common/m3e/motion.dart';
import 'package:PiliPlus/common/m3e/shapes.dart';
import 'package:material_ui/material_ui.dart';

/// Turns a classic Material 3 [ThemeData] into a Material 3 Expressive one.
///
/// The theme keeps whatever the caller has already configured and only layers
/// the expressive shape, motion and component tokens on top, so user choices
/// such as pure black mode, custom colors or font weights stay intact.
extension M3EThemeDataExt on ThemeData {
  ThemeData toM3ETheme() {
    final colors = colorScheme;

    const pillShape = WidgetStatePropertyAll<OutlinedBorder?>(M3EShape.full);

    ButtonStyle? mergePill(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(shape: pillShape);

    InputBorder inputBorder(BorderSide side) =>
        M3EShape.input.copyWith(borderSide: side);

    final enabledBorder = inputBorder(
      BorderSide(color: colors.outlineVariant),
    );
    final focusedBorder = inputBorder(
      BorderSide(color: colors.primary, width: 2),
    );
    final errorBorder = inputBorder(BorderSide(color: colors.error));
    final disabledBorder = inputBorder(
      BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
    );

    return copyWith(
      pageTransitionsTheme: M3EMotion.pageTransitions,
      // Cards use the low container tone, flat, with the expressive medium
      // corner. Elevation is expressed through surface tint instead of
      // shadows, which is the expressive default.
      cardTheme: cardTheme.copyWith(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        color: colors.surfaceContainerLow,
        shadowColor: Colors.transparent,
        surfaceTintColor: colors.surfaceTint,
        shape: M3EShape.lg,
      ),
      dialogTheme: dialogTheme.copyWith(
        elevation: 0,
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: colors.surfaceTint,
        shape: M3EShape.xxl,
      ),
      bottomSheetTheme: bottomSheetTheme.copyWith(
        elevation: 0,
        modalElevation: 0,
        backgroundColor: colors.surfaceContainerLow,
        modalBackgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: colors.surfaceTint,
        shape: M3EShape.top(M3ECorner.xxl),
      ),
      popupMenuTheme: popupMenuTheme.copyWith(
        elevation: 0,
        color: colors.surfaceContainer,
        surfaceTintColor: colors.surfaceTint,
        shape: M3EShape.md,
      ),
      menuTheme: MenuThemeData(
        style: (menuTheme.style ?? const MenuStyle()).copyWith(
          shape: const WidgetStatePropertyAll<OutlinedBorder?>(M3EShape.md),
        ),
      ),
      snackBarTheme: snackBarTheme.copyWith(
        elevation: 0,
        shape: M3EShape.sm,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
      tooltipTheme: tooltipTheme.copyWith(
        decoration: ShapeDecoration(
          color: colors.inverseSurface,
          shape: M3EShape.xs,
        ),
        textStyle: TextStyle(color: colors.onInverseSurface, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      chipTheme: chipTheme.copyWith(shape: M3EShape.sm),
      floatingActionButtonTheme: floatingActionButtonTheme.copyWith(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: M3EShape.lg,
      ),
      navigationBarTheme: navigationBarTheme.copyWith(
        elevation: 0,
        height: 64,
        backgroundColor: colors.surfaceContainer,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: M3EShape.full,
      ),
      navigationRailTheme: navigationRailTheme.copyWith(
        indicatorShape: M3EShape.full,
        useIndicator: true,
      ),
      navigationDrawerTheme: navigationDrawerTheme.copyWith(
        elevation: 0,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: M3EShape.full,
        tileHeight: 56,
      ),
      drawerTheme: drawerTheme.copyWith(
        elevation: 0,
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: colors.surfaceTint,
        endShape: M3EShape.of(
          const BorderRadius.horizontal(
            right: Radius.circular(M3ECorner.xxl),
          ),
        ),
      ),
      bottomAppBarTheme: bottomAppBarTheme.copyWith(
        elevation: 0,
        color: colors.surfaceContainer,
        surfaceTintColor: colors.surfaceTint,
      ),
      listTileTheme: listTileTheme.copyWith(shape: M3EShape.md),
      dividerTheme: dividerTheme.copyWith(
        color: colors.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      badgeTheme: badgeTheme.copyWith(
        backgroundColor: colors.error,
        textColor: colors.onError,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: mergePill(segmentedButtonTheme.style),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: mergePill(filledButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: mergePill(elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: mergePill(outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: mergePill(textButtonTheme.style),
      ),
      // Material 3 Expressive icon buttons ship with the new scale of shapes
      // and sizes, including the morphing pressed container.
      iconButtonTheme: IconButtonThemeData(
        style: iconButtonTheme.style,
        variant: StyleVariant.material3Expressive,
      ),
      inputDecorationTheme: inputDecorationTheme.copyWith(
        border: enabledBorder,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: inputBorder(
          BorderSide(color: colors.error, width: 2),
        ),
        disabledBorder: disabledBorder,
      ),
      progressIndicatorTheme: progressIndicatorTheme.copyWith(
        borderRadius: M3ERadius.full,
      ),
      searchBarTheme: searchBarTheme.copyWith(
        elevation: const WidgetStatePropertyAll<double?>(0),
        backgroundColor: WidgetStatePropertyAll<Color?>(
          colors.surfaceContainerHigh,
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder?>(M3EShape.full),
      ),
    );
  }
}
