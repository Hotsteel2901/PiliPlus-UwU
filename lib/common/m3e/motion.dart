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

/// Material 3 Expressive motion tokens.
///
/// Durations are grouped into the four expressive "speed" buckets and the
/// curves come straight from the `Easing` token set so components move with
/// the same physics as the platform.
abstract final class M3EMotion {
  /// Small utility transitions, e.g. icon state changes.
  static const Duration fast = Duration(milliseconds: 175);

  /// Default component transitions, e.g. selection indicators.
  static const Duration medium = Duration(milliseconds: 300);

  /// Larger layout transitions, e.g. bottom sheets.
  static const Duration slow = Duration(milliseconds: 450);

  /// Shape morphing, e.g. loading indicators.
  static const Duration morph = Duration(milliseconds: 650);

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
