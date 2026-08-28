import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../ui/theme.dart';

/// The blended contribution grid.
///
/// Each square takes the colour of the platform the work happened on, and days
/// spent across several platforms blend. A one-colour grid can only say "you
/// did something"; this says what — which is the whole argument for merging
/// platforms in the first place.
///
/// The squares animate in column by column, oldest to newest, so the year
/// assembles the way it accumulated. On the actual home screen the OS renders
/// a still frame, so this motion only ever happens inside the app — which is
/// exactly why the app is worth opening.
class ContributionGrid extends StatefulWidget {
  const ContributionGrid({
    super.key,
    required this.days,
    this.skin,
    this.cell = 11,
    this.gap = 3,
    this.animate = true,
    this.weeks,
  });

  final List<AttributedDay> days;
  final Skin? skin;
  final double cell;
  final double gap;
  final bool animate;

  /// Trim to the most recent N weeks. Null shows everything given.
  final int? weeks;

  @override
  State<ContributionGrid> createState() => ContributionGridState();
}

class ContributionGridState extends State<ContributionGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(ContributionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New data deserves a fresh reveal; the same data redrawn does not.
    if (widget.days.length != oldWidget.days.length && widget.animate) replay();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Play the reveal again. Wired to a button on the preview screen.
  void replay() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin ?? Skin.of(Theme.of(context).brightness);
    var days = widget.days;
    if (widget.weeks != null && days.length > widget.weeks! * 7) {
      days = days.sublist(days.length - widget.weeks! * 7);
    }
    if (days.isEmpty) return const SizedBox.shrink();

    var peak = 1;
    for (final d in days) {
      if (d.count > peak) peak = d.count;
    }

    // Pad so each column starts on a Sunday, matching every contribution grid
    // people already know how to read.
    final pad = DateTime.parse(days.first.date).weekday % 7;
    final total = days.length + pad;
    final columns = (total / 7).ceil();

    // Inside a fixed-height widget face there is exactly as much room as
    // there is; deriving the square size from it means the grid always fits,
    // rather than relying on numbers hand-tuned per face and overflowing the
    // moment one of them changes.
    return LayoutBuilder(builder: (context, constraints) {
      var cell = widget.cell;
      if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite) {
        final fitted = (constraints.maxHeight - 6 * widget.gap) / 7;
        if (fitted > 0 && fitted < cell) cell = fitted;
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // opens on the most recent weeks
        physics: const BouncingScrollPhysics(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size(
              columns * (cell + widget.gap),
              7 * cell + 6 * widget.gap,
            ),
            painter: _GridPainter(
              days: days,
              pad: pad,
              columns: columns,
              peak: peak,
              cell: cell,
              gap: widget.gap,
              skin: skin,
              progress: _controller.value,
            ),
          ),
        ),
      );
    });
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.days,
    required this.pad,
    required this.columns,
    required this.peak,
    required this.cell,
    required this.gap,
    required this.skin,
    required this.progress,
  });

  final List<AttributedDay> days;
  final int pad;
  final int columns;
  final int peak;
  final double cell;
  final double gap;
  final Skin skin;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final step = cell + gap;

    for (var i = 0; i < days.length; i++) {
      final index = i + pad;
      final col = index ~/ 7;
      final row = index % 7;

      // Each column starts a little after the one before it, so the reveal
      // sweeps left to right instead of everything popping at once.
      final start = columns <= 1 ? 0.0 : (col / columns) * 0.55;
      final t = ((progress - start) / 0.45).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final eased = Curves.easeOutBack.transform(t);
      final scale = 0.35 + 0.65 * eased;
      final inset = cell * (1 - scale) / 2;

      paint.color = _cellColor(days[i]).withValues(alpha: t.clamp(0.0, 1.0));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(col * step + inset, row * step + inset, cell * scale, cell * scale),
          // Proportional, not fixed: a 2.5pt radius on a 6pt square is very
          // nearly a circle, and a grid of circles reads as dots rather than
          // as a contribution calendar.
          Radius.circular(cell * 0.24),
        ),
        paint,
      );
    }
  }

  Color _cellColor(AttributedDay day) {
    if (day.count <= 0) return skin.empty;

    // Weighted blend of every platform active that day. sqrt weighting so a
    // 40-commit day does not erase the two problems solved alongside it.
    double r = 0, g = 0, b = 0, total = 0;
    day.byPlatform.forEach((platform, count) {
      if (count <= 0) return;
      final w = math.sqrt(count.toDouble());
      final c = platformColor(platform);
      r += c.r * 255 * w;
      g += c.g * 255 * w;
      b += c.b * 255 * w;
      total += w;
    });
    if (total == 0) return skin.empty;

    final blended = Color.fromARGB(
      255,
      (r / total).round(),
      (g / total).round(),
      (b / total).round(),
    );
    // Floor the mix so a single-contribution day is visible, not a smudge.
    final t = 0.25 + 0.75 * math.sqrt(day.count / peak).clamp(0.0, 1.0);
    return Color.lerp(skin.empty, blended, t)!;
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.progress != progress || old.days != days || old.skin != skin;
}
