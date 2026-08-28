import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/streak.dart';
import '../../data/widget_config.dart';
import '../../ui/theme.dart';
import '../contribution_grid.dart';

/// Renders a [WidgetConfig] at true home-screen proportions.
///
/// One renderer, six layouts, driven entirely by configuration — which is the
/// only way a "make your widget anything" product can work on a phone. A
/// widget extension cannot run user code, so what the user builds has to be
/// data this interprets.
class WidgetFace extends StatelessWidget {
  const WidgetFace({
    super.key,
    required this.activity,
    required this.config,
    this.gridKey,
    this.animate = true,
  });

  final Activity activity;
  final WidgetConfig config;
  final Key? gridKey;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final skin = switch (config.skin) {
      WidgetSkin.dark => Skin.dark,
      WidgetSkin.light => Skin.light,
      WidgetSkin.system => Skin.of(MediaQuery.platformBrightnessOf(context)),
    };
    final scoped = ScopedActivity.scoped(activity, config.platforms);

    return Container(
      width: config.size.width,
      height: config.size.height,
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
      child: _FaceBody(
        scoped: scoped,
        config: config,
        skin: skin,
        gridKey: gridKey,
        animate: animate,
      ),
    );
  }
}

class _FaceBody extends StatelessWidget {
  const _FaceBody({
    required this.scoped,
    required this.config,
    required this.skin,
    required this.gridKey,
    required this.animate,
  });

  final ScopedActivity scoped;
  final WidgetConfig config;
  final Skin skin;
  final Key? gridKey;
  final bool animate;

  StreakSummary get s => scoped.summary;
  Color get accent => s.status == 'broken' ? kDanger : config.accent.color;

  (String, Color) get status => switch (s.status) {
        'safe' => ('done today', kGitHub),
        'at-risk' => ('not yet today', config.accent.color),
        _ => ('streak broken', kDanger),
      };

  @override
  Widget build(BuildContext context) => switch (config.template) {
        FaceTemplate.grid => _grid(),
        FaceTemplate.flame => _flame(),
        FaceTemplate.minimal => _minimal(),
        FaceTemplate.stats => _stats(),
        FaceTemplate.split => _split(),
        FaceTemplate.ring => _ring(),
      };

  // ---------------------------------------------------------------- grid ---

  /// The contribution calendar. On the wide face the numbers sit beside the
  /// grid rather than above it: stacked, a 158pt-tall widget leaves the grid
  /// about four points per square and the right third empty.
  Widget _grid() {
    final grid = ContributionGrid(
      key: gridKey,
      days: scoped.heatmap,
      skin: skin,
      weeks: config.size.isLarge ? 26 : 13,
      cell: config.size == FaceSize.small ? 9 : 11,
      gap: 2,
      animate: animate,
    );

    if (config.size.isWide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 108,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_headline()],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: grid)),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _headline(),
      if (config.size.isLarge) ...[
        const SizedBox(height: 14),
        _legend(),
        const SizedBox(height: 18),
        _totals(),
      ],
      const SizedBox(height: 14),
      Expanded(child: Align(alignment: Alignment.bottomLeft, child: grid)),
    ]);
  }

  // --------------------------------------------------------------- flame ---

  /// Urgency, made visual. The bar is how much of today is gone — the one
  /// thing that actually decides whether the streak survives.
  Widget _flame() {
    final now = DateTime.now();
    final dayGone = (now.hour * 60 + now.minute) / (24 * 60);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _headline(showCaption: config.showCaption),
      const Spacer(),
      if (!s.activeToday) ...[
        Text(
          s.status == 'broken' ? 'start a new one' : 'today is still open',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: skin.dim, fontSize: 10.5),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: dayGone,
            minHeight: 6,
            backgroundColor: skin.empty,
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
        // At 158pt square the bar already says how much of the day is gone;
        // spelling it out again costs more height than the widget has.
        if (config.size != FaceSize.small) ...[
          const SizedBox(height: 6),
          Text('${((1 - dayGone) * 24).round()}h left today',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: skin.faint, fontSize: 9.5)),
        ],
      ] else ...[
        Row(children: [
          const Icon(Icons.check_circle_rounded, size: 15, color: kGitHub),
          const SizedBox(width: 6),
          Flexible(
            child: Text('Safe until midnight',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: skin.dim, fontSize: 11)),
          ),
        ]),
      ],
    ]);
  }

  // ------------------------------------------------------------- minimal ---

  /// One number, centred, nothing else. The whole point is that nothing
  /// competes with it.
  Widget _minimal() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The number is the entire layout, so it scales to whatever room
            // the chosen size leaves rather than being tuned per size and
            // overflowing the first time a digit is added.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${s.currentStreak}',
                  style: TextStyle(
                    fontSize: config.size.isLarge ? 128 : (config.size.isWide ? 76 : 68),
                    height: 0.95,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -4,
                    color: accent,
                  ),
                ),
              ),
            ),
            if (config.showCaption) ...[
              const SizedBox(height: 6),
              Text(
                'DAY STREAK',
                style: TextStyle(
                  color: skin.faint,
                  fontSize: 9.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );

  // --------------------------------------------------------------- stats ---

  Widget _stats() {
    final tiles = [
      ('${s.currentStreak}', 'STREAK', accent),
      ('${s.longestStreak}', 'LONGEST', skin.text),
      ('${s.totalActiveDays}', 'ACTIVE DAYS', skin.text),
      (_compact(s.totalContributions), 'TOTAL', skin.text),
    ];

    Widget tile((String, String, Color) t) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(t.$1,
                  style: TextStyle(
                      color: t.$3,
                      fontSize: config.size.isLarge ? 34 : 26,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1)),
            ),
            const SizedBox(height: 3),
            Text(t.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: skin.faint, fontSize: 8.5, letterSpacing: 1.1)),
          ],
        );

    // A wide, short widget gets one row; a square one gets a 2×2.
    if (config.size.isWide) {
      return Row(children: [for (final t in tiles) Expanded(child: tile(t))]);
    }
    return Column(children: [
      for (var row = 0; row < 2; row++) ...[
        Expanded(
          child: Row(children: [
            Expanded(child: tile(tiles[row * 2])),
            Expanded(child: tile(tiles[row * 2 + 1])),
          ]),
        ),
      ],
    ]);
  }

  // --------------------------------------------------------------- split ---

  /// Where the streak came from. This is the view no single-platform widget
  /// can offer, so it is the one that most justifies merging at all.
  Widget _split() {
    final totals = <String, int>{};
    for (final day in scoped.heatmap) {
      day.byPlatform.forEach((p, c) => totals[p] = (totals[p] ?? 0) + c);
    }
    final sum = totals.values.fold(0, (a, b) => a + b);
    final ordered = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _headline(compact: true),
      const SizedBox(height: 12),
      if (sum == 0)
        Text('Nothing yet', style: TextStyle(color: skin.faint, fontSize: 11))
      else ...[
        // A single stacked bar reads faster than four separate ones.
        //
        // Two constraints here are load-bearing, and both fail silently. The
        // parent Column aligns to start, so without an explicit infinite width
        // the Expanded segments collapse to zero. And a childless ColoredBox
        // takes the *smallest* height it is offered, so without stretch every
        // segment is 8pt wide and 0pt tall — a bar that is simply not there.
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in ordered)
                  Expanded(
                    flex: math.max(1, (e.value / sum * 1000).round()),
                    child: ColoredBox(color: platformColor(e.key)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              if (config.size.isLarge) const SizedBox(height: 4),
              // Medium is the same height as small but carries a caption, so
              // it has room for one row fewer.
              for (final e in ordered.take(switch (config.size) {
                FaceSize.large => 4,
                FaceSize.medium => 2,
                FaceSize.small => 3,
              }))
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: platformColor(e.key),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(platformLabel(e.key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: skin.dim, fontSize: 11)),
                    ),
                    Text('${(e.value / sum * 100).round()}%',
                        style: TextStyle(
                            color: skin.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              // The large face has room left over; spend it on the totals
              // rather than leaving a third of the widget blank.
              if (config.size.isLarge) ...[
                const SizedBox(height: 10),
                _totals(),
              ],
            ],
          ),
        ),
      ],
    ]);
  }

  // ---------------------------------------------------------------- ring ---

  /// Progress toward the next milestone, which turns a streak from a number
  /// you hold into a target you approach.
  Widget _ring() {
    final next = _nextMilestone(s.currentStreak);
    final progress = next == 0 ? 0.0 : (s.currentStreak / next).clamp(0.0, 1.0);

    final diameter = switch (config.size) {
      FaceSize.large => 150.0,
      FaceSize.medium => 104.0,
      FaceSize.small => 92.0,
    };

    final ring = SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          accent: accent,
          track: skin.empty,
          stroke: config.size.isLarge ? 13 : 10,

        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${s.currentStreak}',
                  style: TextStyle(
                      color: skin.text,
                      fontSize: config.size.isLarge ? 44 : 30,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5)),
              const SizedBox(height: 2),
              Text('of $next',
                  style: TextStyle(color: skin.faint, fontSize: 10)),
            ],
          ),
        ),
      ),
    );

    if (config.size.isWide) {
      return Row(children: [
        ring,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${next - s.currentStreak} days',
                  style: TextStyle(
                      color: skin.text, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('to your next milestone',
                  style: TextStyle(color: skin.dim, fontSize: 11)),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: status.$2, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(status.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: status.$2, fontSize: 10)),
                ),
              ]),
            ],
          ),
        ),
      ]);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: ring)),
          // The small face has no room for both a ring and a caption, and the
          // ring already carries the number.
          if (config.showCaption && config.size != FaceSize.small) ...[
            const SizedBox(height: 12),
            Text('${next - s.currentStreak} days to go',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: skin.dim, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  static int _nextMilestone(int streak) {
    for (final m in [7, 14, 30, 50, 100, 150, 200, 250, 365, 500, 730, 1000]) {
      if (m > streak) return m;
    }
    return ((streak ~/ 500) + 1) * 500;
  }

  // ------------------------------------------------------------- shared ---

  Widget _headline({bool showCaption = true, bool compact = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCaption && config.showCaption && config.size != FaceSize.small) ...[
            Text('UNIFIED STREAK',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: skin.faint,
                    fontSize: 8.5,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${s.currentStreak}',
                  style: TextStyle(
                      fontSize: compact
                          ? 30
                          : (config.size.isLarge
                              ? 52
                              : (config.size == FaceSize.small ? 36 : 44)),
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                      color: accent)),
              const SizedBox(width: 4),
              Flexible(
                child: Text('days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: skin.dim, fontSize: 11)),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 5),
            Row(children: [
              Container(
                width: 5,
                height: 5,
                decoration:
                    BoxDecoration(color: status.$2, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(status.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: status.$2, fontSize: 9.5)),
              ),
            ]),
          ],
        ],
      );

  Widget _legend() => Wrap(
        spacing: 12,
        runSpacing: 6,
        children: scoped.platforms
            .where((p) => p.ok)
            .map((p) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: platformColor(p.platform),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 5),
                  Text(p.handle,
                      style: TextStyle(color: skin.dim, fontSize: 10.5)),
                ]))
            .toList(),
      );

  Widget _totals() => Row(children: [
        _totalTile('${s.longestStreak}', 'LONGEST'),
        _totalTile('${s.totalActiveDays}', 'ACTIVE DAYS'),
        _totalTile(_compact(s.totalContributions), 'CONTRIBUTIONS'),
      ]);

  Widget _totalTile(String value, String label) => Expanded(
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

  static String _compact(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k'
      : '$n';
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.accent,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color accent;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    if (progress <= 0) return;
    // Start at 12 o'clock, so a nearly-full ring reads as nearly-there.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      base..color = accent,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent || old.track != track;
}
