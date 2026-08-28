import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/widget_bridge.dart';
import '../../data/widget_config.dart';
import '../../ui/theme.dart';
import '../../widgets/faces/widget_face.dart';

/// Your widgets.
///
/// A person can keep several — a minimal number on the lock-adjacent page, a
/// full grid elsewhere, a GitHub-only one for work. Each is previewed at true
/// size, because a list of names would tell you nothing about which is which.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({
    super.key,
    required this.configs,
    required this.activity,
    required this.onEdit,
    required this.onCreate,
    required this.onRefresh,
  });

  final List<WidgetConfig> configs;
  final Activity activity;
  final ValueChanged<WidgetConfig> onEdit;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(Theme.of(context).brightness);
    final s = activity.summary;
    final (statusLabel, statusColor) = switch (s.status) {
      'safe' => ('done today', kGitHub),
      'at-risk' => ('not yet today', kFlameHot),
      _ => ('streak broken', kDanger),
    };

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: kGitHub,
      backgroundColor: skin.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('UNIFIED STREAK',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${s.currentStreak}',
                      style: TextStyle(
                          fontSize: 56,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -2.5,
                          color: s.status == 'broken' ? kDanger : kFlameHot)),
                  const SizedBox(width: 8),
                  Text('days', style: TextStyle(color: skin.dim, fontSize: 14)),
                ],
              ),
            ]),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 12)),
              ]),
            ),
          ]),

          const SizedBox(height: 30),
          Row(children: [
            Text('YOUR WIDGETS',
                style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New'),
              style: TextButton.styleFrom(
                foregroundColor: kGitHub,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          for (final config in configs)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _GalleryCard(
                config: config,
                activity: activity,
                skin: skin,
                onEdit: () => onEdit(config),
              ),
            ),

          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await WidgetBridge.requestPin();
              if (!ok) {
                messenger.showSnackBar(const SnackBar(
                  content: Text(
                      'Add it yourself: long-press your home screen → Widgets → Widgeto.'),
                  duration: Duration(seconds: 5),
                ));
              }
            },
            icon: const Icon(Icons.add_to_home_screen_rounded, size: 19),
            label: const Text('Add to home screen'),
          ),
          const SizedBox(height: 14),
          Text('Days counted in ${s.timezone}. Today is ${s.today}.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.config,
    required this.activity,
    required this.skin,
    required this.onEdit,
  });

  final WidgetConfig config;
  final Activity activity;
  final Skin skin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            color: skin.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: skin.line),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              // The face is drawn at true size; a card narrower than a medium
              // widget scrolls rather than squashing the preview into a lie.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                physics: const BouncingScrollPhysics(),
                child: WidgetFace(
                  activity: activity,
                  config: config,
                  animate: false,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: skin.line)),
              ),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: config.accent.color,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: skin.text,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${config.template.label} · ${config.size.label}'
                        '${config.platforms.isEmpty ? '' : ' · ${config.platforms.length} sources'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: skin.faint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: skin.faint, size: 22),
              ]),
            ),
          ]),
        ),
      );
}
