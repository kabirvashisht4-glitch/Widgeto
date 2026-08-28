import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/models.dart';
import 'theme.dart';

/// The blended contribution grid, in-app.
///
/// Same colour language as the web: each square takes the colour of the
/// platform the work happened on, and multi-platform days blend.
class ContributionGrid extends StatelessWidget {
  const ContributionGrid({super.key, required this.days, this.cell = 10, this.gap = 3});

  final List<AttributedDay> days;
  final double cell;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    var peak = 1;
    for (final d in days) {
      if (d.count > peak) peak = d.count;
    }

    final columns = <List<AttributedDay?>>[];
    // Pad so weeks start on Sunday, matching every contribution grid people
    // already know how to read.
    final firstDow = DateTime.parse(days.first.date).weekday % 7;
    final padded = <AttributedDay?>[...List.filled(firstDow, null), ...days];
    for (var i = 0; i < padded.length; i += 7) {
      columns.add(padded.sublist(i, (i + 7).clamp(0, padded.length)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // open on the most recent weeks
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns
            .map((col) => Padding(
                  padding: EdgeInsets.only(right: gap),
                  child: Column(
                    children: List.generate(7, (row) {
                      final day = row < col.length ? col[row] : null;
                      return Padding(
                        padding: EdgeInsets.only(bottom: gap),
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: _cellColor(day, peak),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      );
                    }),
                  ),
                ))
            .toList(),
      ),
    );
  }

  static const _empty = Color(0xFF1A1E26);

  Color _cellColor(AttributedDay? day, int peak) {
    if (day == null || day.count <= 0) return _empty;

    // Weighted blend of every platform active that day.
    double r = 0, g = 0, b = 0, total = 0;
    day.byPlatform.forEach((platform, count) {
      if (count <= 0) return;
      // sqrt weighting so a 40-commit day does not erase two solved problems.
      final w = math.sqrt(count.toDouble());
      final c = platformColor(platform);
      // Flutter's Color channels are 0-1 doubles; scale to 0-255 for the mix.
      r += c.r * 255 * w;
      g += c.g * 255 * w;
      b += c.b * 255 * w;
      total += w;
    });
    if (total == 0) return _empty;

    final blended = Color.fromARGB(255, (r / total).round(), (g / total).round(), (b / total).round());
    // Floor the mix so a single-contribution day stays visible.
    final t = 0.25 + 0.75 * math.sqrt(day.count / peak).clamp(0.0, 1.0);
    return Color.lerp(kBg, blended, t)!;
  }
}
