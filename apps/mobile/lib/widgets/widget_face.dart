import 'package:flutter/material.dart';

import '../data/models.dart';
import '../ui/theme.dart';
import 'contribution_grid.dart';

/// The home-screen widget, drawn at true proportions.
///
/// This is the app's centrepiece: what you see here is what lands on the home
/// screen, in the palette you picked, before you commit to placing it. The
/// native SwiftUI and Kotlin faces render the same payload with the same
/// colour rules.
///
/// Each size gets its own layout rather than one stack that is squeezed to
/// fit. A medium widget is wide and short, so stacking the streak above the
/// grid leaves the grid a few pixels tall and the right half empty; side by
/// side, both get room.
enum FaceSize {
  small(158, 158),
  medium(338, 158),
  large(338, 338);

  const FaceSize(this.width, this.height);

  final double width;
  final double height;

  String get label => switch (this) {
        FaceSize.small => 'Small',
        FaceSize.medium => 'Medium',
        FaceSize.large => 'Large',
      };

  /// How much history fits without the squares becoming dots.
  int get weeks => switch (this) {
        FaceSize.small => 13,
        FaceSize.medium => 13,
        FaceSize.large => 26,
      };

  double get cell => switch (this) {
        FaceSize.small => 9,
        FaceSize.medium => 11,
        FaceSize.large => 12,
      };

  double get streakSize => switch (this) {
        FaceSize.small => 36,
        FaceSize.medium => 44,
        FaceSize.large => 52,
      };

  /// At 158pt square there is not enough height for both a caption and a
  /// legible grid, and the grid is the part worth keeping — a home-screen
  /// widget does not need to announce what it is every time you glance at it.
  bool get showsCaption => this != FaceSize.small;
}

class WidgetFace extends StatelessWidget {
  const WidgetFace({
    super.key,
    required this.activity,
    required this.size,
    required this.skin,
    this.gridKey,
    this.animate = true,
  });

  final Activity activity;
  final FaceSize size;
  final Skin skin;
  final Key? gridKey;
  final bool animate;

  (String, Color) get _status => switch (activity.summary.status) {
        'safe' => ('done today', kGitHub),
        'at-risk' => ('not yet today', kFlameHot),
        _ => ('streak broken', kDanger),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: skin.ground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: skin.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: switch (size) {
        FaceSize.medium => _wide(),
        _ => _tall(),
      },
    );
  }

  /// Small and large: the streak on top, the grid filling what is left.
  ///
  /// The large face earns its size by carrying more, not by floating the same
  /// content in more space — so it also names its sources and shows the totals
  /// behind the streak.
  Widget _tall() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          if (size == FaceSize.large) ...[
            const SizedBox(height: 14),
            _legend(),
            const SizedBox(height: 18),
            _totals(),
          ],
          const SizedBox(height: 14),
          Expanded(child: _grid(alignment: Alignment.bottomLeft)),
        ],
      );

  Widget _totals() {
    final s = activity.summary;
    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                      color: skin.text, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: skin.faint, fontSize: 8.5, letterSpacing: 1.1)),
            ],
          ),
        );

    final total = s.totalContributions;
    return Row(children: [
      stat('${s.longestStreak}', 'LONGEST'),
      stat('${s.totalActiveDays}', 'ACTIVE DAYS'),
      stat(
        total >= 1000
            ? '${(total / 1000).toStringAsFixed(total >= 10000 ? 0 : 1)}k'
            : '$total',
        'CONTRIBUTIONS',
      ),
    ]);
  }

  /// Medium: a stat column beside a full-height grid. The grid takes the
  /// remaining width instead of leaving a third of the widget blank.
  Widget _wide() => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_header()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _grid(alignment: Alignment.centerLeft)),
        ],
      );

  Widget _header() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (size.showsCaption) ...[
            Text(
              'UNIFIED STREAK',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: skin.faint,
                fontSize: 8.5,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${activity.summary.currentStreak}',
                style: TextStyle(
                  fontSize: size.streakSize,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                  color: activity.summary.status == 'broken' ? kDanger : kFlameHot,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text('days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: skin.dim, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: _status.$2, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _status.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _status.$2, fontSize: 9.5),
              ),
            ),
          ]),
        ],
      );

  /// Only the large face has room to name the sources — the thing a
  /// single-platform widget structurally cannot show.
  Widget _legend() => Wrap(
        spacing: 12,
        runSpacing: 6,
        children: activity.platforms
            .where((p) => p.ok)
            .map((p) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: platformColor(p.platform),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(p.handle, style: TextStyle(color: skin.dim, fontSize: 10.5)),
                ]))
            .toList(),
      );

  Widget _grid({required Alignment alignment}) => Align(
        alignment: alignment,
        child: ContributionGrid(
          key: gridKey,
          days: activity.heatmap,
          skin: skin,
          weeks: size.weeks,
          cell: size.cell,
          gap: 2,
          animate: animate,
        ),
      );
}
