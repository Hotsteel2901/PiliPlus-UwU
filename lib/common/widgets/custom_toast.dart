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

import 'package:PiliPlus/common/m3e/shapes.dart';
import 'package:PiliPlus/common/widgets/haze/haze.dart';
import 'package:PiliPlus/common/widgets/loading_widget/m3e_loading_indicator.dart';
import 'package:PiliPlus/common/widgets/materialize.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

class CustomToast extends StatelessWidget {
  const CustomToast(this.msg, {super.key});

  final String msg;
  static double toastOpacity = Pref.defaultToastOp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Materialize(
      beginScale: 0.8,
      child: Padding(
        padding: .only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 30,
        ),
        child: HazeGlass(
          style: HazeGlassStyle.clear,
          tint: colorScheme.primaryContainer,
          tintOpacity: toastOpacity,
          highlight: false,
          shape: const RoundedSuperellipseBorder(
            borderRadius: M3ERadius.xl,
          ),
          shadows: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          child: Padding(
            padding: const .symmetric(horizontal: 17, vertical: 10),
            child: Text(
              msg,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget(this.msg, {super.key});

  ///loading msg
  final String msg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    return Materialize(
      beginScale: 0.9,
      child: HazeGlass(
        tint: theme.dialogTheme.backgroundColor,
        shape: const RoundedSuperellipseBorder(
          borderRadius: M3ERadius.xxl,
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
        child: Padding(
          padding: const .symmetric(horizontal: 30, vertical: 20),
          child: Column(
            spacing: 20,
            mainAxisSize: .min,
            children: [
              // Material 3 Expressive morphing loading indicator
              M3ELoadingIndicator(
                size: const Size.square(32),
                color: onSurfaceVariant,
              ),
              //msg
              Text(msg, style: TextStyle(color: onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class NotifyWarning extends StatelessWidget {
  const NotifyWarning(this.msg, {super.key});

  final String msg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    return Materialize(
      beginScale: 0.9,
      child: HazeGlass(
        style: HazeGlassStyle.clear,
        tint: theme.dialogTheme.backgroundColor,
        shape: const RoundedSuperellipseBorder(
          borderRadius: M3ERadius.lg,
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 20, vertical: 10),
          child: Column(
            spacing: 5,
            mainAxisSize: .min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 22,
                color: onSurfaceVariant,
              ),
              Text(msg, style: TextStyle(color: onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
