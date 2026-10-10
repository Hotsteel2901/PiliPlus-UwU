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

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

/// The official Material 3 Expressive duration tokens.
///
/// M3E groups motion into four speed buckets — short, medium, long and
/// extraLong — each with four steps. Components pick the token that matches
/// the size/distance of the motion rather than inventing ad-hoc millisecond
/// values, so the whole app moves on one consistent rhythm.
///
/// See the Material 3 Expressive motion spec (2026): the ladder below is the
/// canonical set.
abstract final class M3EDurations {
  // Short: tiny, local state changes (icon swaps, checkmarks, ripple settle).
  static const Duration short1 = Duration(milliseconds: 50);
  static const Duration short2 = Duration(milliseconds: 100);
  static const Duration short3 = Duration(milliseconds: 150);
  static const Duration short4 = Duration(milliseconds: 200);

  // Medium: default component transitions (selection, expansion, fades).
  static const Duration medium1 = Duration(milliseconds: 250);
  static const Duration medium2 = Duration(milliseconds: 300);
  static const Duration medium3 = Duration(milliseconds: 350);
  static const Duration medium4 = Duration(milliseconds: 400);

  // Long: larger layout/container moves (sheets, dialogs, container transform).
  static const Duration long1 = Duration(milliseconds: 450);
  static const Duration long2 = Duration(milliseconds: 500);
  static const Duration long3 = Duration(milliseconds: 550);
  static const Duration long4 = Duration(milliseconds: 600);

  // Extra long: full-screen, expressive shape morphs and hero flights.
  static const Duration extraLong1 = Duration(milliseconds: 700);
  static const Duration extraLong2 = Duration(milliseconds: 800);
  static const Duration extraLong3 = Duration(milliseconds: 900);
  static const Duration extraLong4 = Duration(milliseconds: 1000);
}

/// Material 3 Expressive motion tokens.
///
/// Durations are grouped into the four expressive "speed" buckets and the
/// curves come straight from the `Easing` token set so components move with
/// the same physics as the platform.
abstract final class M3EMotion {
  /// Small utility transitions, e.g. icon state changes.
  ///
  /// Maps to the M3E [M3EDurations.short4] token (200ms).
  static const Duration fast = M3EDurations.short4;

  /// Default component transitions, e.g. selection indicators.
  ///
  /// Maps to the M3E [M3EDurations.medium2] token (300ms).
  static const Duration medium = M3EDurations.medium2;

  /// Larger layout transitions, e.g. bottom sheets.
  ///
  /// Maps to the M3E [M3EDurations.long1] token (450ms).
  static const Duration slow = M3EDurations.long1;

  /// Shape morphing, e.g. loading indicators.
  ///
  /// Maps to the M3E [M3EDurations.long4] token (600ms).
  static const Duration morph = M3EDurations.long4;

  /// Emphasized easing used for both entering and exiting hero elements.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  static const Curve emphasizedDecelerate = Easing.emphasizedDecelerate;
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;

  static const Curve standard = Easing.standard;
  static const Curve standardDecelerate = Easing.standardDecelerate;
  static const Curve standardAccelerate = Easing.standardAccelerate;

  /// The Material 3 Expressive page transition set.
  ///
  /// Android (and desktop) use the predictive-back aware fade forwards
  /// transition that ships with Material 3 Expressive, while Apple platforms
  /// keep their native horizontal slide.
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
