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

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:material_ui/material_ui.dart';

/// The shared element shuttle shown while a video card cover flies into the
/// player and back.
///
/// The destination hero owns this builder, so it drives both the push (card to
/// player) and the pop (player back to the card) flight. It keeps the cover
/// visible across the morph and animates the corner radius from the card's
/// radius to the player's square corners, so the return lands exactly on the
/// card it started from.
class VideoHeroShuttle extends StatelessWidget {
  const VideoHeroShuttle({super.key, required this.animation, this.cover});

  final Animation<double> animation;
  final String? cover;

  static const BorderRadius _cardRadius = BorderRadius.all(
    Radius.circular(12),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double t = Curves.easeInOutCubicEmphasized.transform(
          animation.value.clamp(0.0, 1.0),
        );
        return ClipRRect(
          borderRadius: BorderRadius.lerp(_cardRadius, BorderRadius.zero, t)!,
          child: ColoredBox(
            color: Colors.black,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final src = cover;
                if (src == null || src.isEmpty) {
                  return const SizedBox.expand();
                }
                return NetworkImgLayer(
                  src: src,
                  width: constraints.hasBoundedWidth ? constraints.maxWidth : 1,
                  height: constraints.hasBoundedHeight
                      ? constraints.maxHeight
                      : 1,
                  borderRadius: BorderRadius.zero,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
