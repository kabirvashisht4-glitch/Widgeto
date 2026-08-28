import 'package:flutter/material.dart';

import '../../data/insights.dart';
import '../../data/models.dart';
import '../../ui/theme.dart';
import '../../widgets/contribution_grid.dart';

/// The questions a streak number cannot answer.
///
/// The widget tells you whether today is safe. This tells you whether the
/// habit is actually going anywhere: is it speeding up or slowing down, when
/// do you really work, and what is the next number worth chasing.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({
    super.key,
    required this.activity,
    required this.onRefresh,
  });

  final Activity activity;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(Theme.of(context).brightness);
    final s = activity.summary;
    final insights = Insights.from(activity.heatmap, s);
    final momentum = insights.momentum;
    final toGo = insights.daysToMilestone(s.currentStreak);
    final progress = insights.nextMilestone == 0
        ? 0.0
        : (s.currentStreak / insights.nextMilestone).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: kGitHub,
      backgroundColor: skin.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text('INSIGHTS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          Text('How it’s actually going',
              style: Theme.of(context).textTheme.headlineLarge),

          // ---- next milestone ----
          const SizedBox(height: 26),
          _Card(
            skin: skin,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Next milestone',
                    style: TextStyle(
                        color: skin.text, fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${insights.nextMilestone} days',
                    style: const TextStyle(
                        color: kFlameHot, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: skin.empty,
                  valueColor: const AlwaysStoppedAnimation<Color>(kFlameHot),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                toGo <= 0
                    ? 'Milestone reached.'
                    : '$toGo more ${toGo == 1 ? 'day' : 'days'} at ${s.currentStreak} today.',
                style: TextStyle(color: skin.dim, fontSize: 13),
              ),
            ]),
          ),

          // ---- momentum ----
          const SizedBox(height: 14),
          _Card(
            skin: skin,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Momentum',
                  style: TextStyle(
                      color: skin.text, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${insights.last7}',
                    style: TextStyle(
                        color: skin.text,
                        fontSize: 34,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('this week',
                      style: TextStyle(color: skin.dim, fontSize: 13)),
                ),
                const Spacer(),
                if (momentum != null)
                  _Delta(value: momentum, skin: skin)
                else
                  Text('new', style: TextStyle(color: skin.faint, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Text(
                momentum == null
                    ? 'No earlier week to compare against yet.'
                    : '${insights.prev7} the week before.',
                style: TextStyle(color: skin.faint, fontSize: 12.5),
              ),
            ]),
          ),

          // ---- rhythm ----
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _Card(
                skin: skin,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Best day',
                      style: TextStyle(color: skin.faint, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Text(Insights.weekdayNames[insights.bestWeekday],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: skin.text, fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${insights.bestWeekdayCount} contributions',
                      style: TextStyle(color: skin.dim, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Card(
                skin: skin,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Busiest day',
                      style: TextStyle(color: skin.faint, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Text('${insights.busiestDayCount}',
                      style: TextStyle(
                          color: skin.text, fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(insights.busiestDay ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: skin.dim, fontSize: 12)),
                ]),
              ),
            ),
          ]),

          // ---- where the work happens ----
          if (insights.byPlatform.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Card(
              skin: skin,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Where the work happens',
                    style: TextStyle(
                        color: skin.text, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                for (final row in insights.byPlatform) ...[
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: platformColor(row.platform),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 9),
                    SizedBox(
                      width: 92,
                      child: Text(platformLabel(row.platform),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: skin.dim, fontSize: 13)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: row.share,
                          minHeight: 6,
                          backgroundColor: skin.empty,
                          valueColor:
                              AlwaysStoppedAnimation(platformColor(row.platform)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 38,
                      child: Text('${(row.share * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: skin.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
              ]),
            ),
          ],

          // ---- the year ----
          const SizedBox(height: 14),
          _Card(
            skin: skin,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('The year',
                  style: TextStyle(
                      color: skin.text, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Colour is the platform. Mixed days blend.',
                  style: TextStyle(color: skin.faint, fontSize: 12)),
              const SizedBox(height: 16),
              ContributionGrid(days: activity.heatmap, skin: skin, cell: 11, gap: 3),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.value, required this.skin});

  final double value;
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    final color = up ? kGitHub : kDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 13, color: color),
        const SizedBox(width: 4),
        Text('${value.abs().round()}%',
            style: TextStyle(
                color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.skin, required this.child});

  final Skin skin;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: skin.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: skin.line),
        ),
        child: child,
      );
}
