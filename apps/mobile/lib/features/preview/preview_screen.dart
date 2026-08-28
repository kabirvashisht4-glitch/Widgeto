import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/widget_bridge.dart';
import '../../ui/theme.dart';
import '../../widgets/contribution_grid.dart';
import '../../widgets/widget_face.dart';

/// The widget, before you commit to it.
///
/// Size and palette are chosen here and previewed at true proportions, because
/// the alternative — place it, look at your home screen, come back, change it,
/// place it again — is the worst loop in widget apps. The palette is a separate
/// choice from the app's own theme: people theme a home screen to match a
/// wallpaper, not to match the app they configured it in.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.activity,
    required this.onEditHandles,
    required this.onRefresh,
    required this.refreshing,
  });

  final Activity activity;
  final VoidCallback onEditHandles;
  final Future<void> Function() onRefresh;
  final bool refreshing;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _gridKey = GlobalKey<ContributionGridState>();
  FaceSize _size = FaceSize.medium;
  WidgetSkin _skinChoice = WidgetSkin.dark;
  bool _pinning = false;

  Skin _resolveSkin(BuildContext context) => switch (_skinChoice) {
        WidgetSkin.dark => Skin.dark,
        WidgetSkin.light => Skin.light,
        WidgetSkin.system =>
          Skin.of(MediaQuery.platformBrightnessOf(context)),
      };

  Future<void> _addToHome() async {
    setState(() => _pinning = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await WidgetBridge.requestPin();
    if (!mounted) return;
    setState(() => _pinning = false);

    if (!ok) {
      // Not every launcher supports programmatic pinning, and iOS never does.
      // Tell people the manual route instead of failing silently.
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Add it yourself: long-press your home screen → Widgets → Widgeto.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(Theme.of(context).brightness);
    final faceSkin = _resolveSkin(context);
    final s = widget.activity.summary;
    final live = widget.activity.platforms.where((p) => p.ok).toList();
    final failed = widget.activity.platforms.where((p) => !p.ok).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          color: kGitHub,
          backgroundColor: skin.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 44),
            children: [
              Row(children: [
                Text('Widgeto', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  onPressed: () => _gridKey.currentState?.replay(),
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  tooltip: 'Replay',
                  color: skin.faint,
                ),
                IconButton(
                  onPressed: widget.onEditHandles,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: 'Edit handles',
                  color: skin.faint,
                ),
              ]),

              const SizedBox(height: 18),

              // ---- the widget itself ----
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: WidgetFace(
                    activity: widget.activity,
                    size: _size,
                    skin: faceSkin,
                    gridKey: _gridKey,
                  ),
                ),
              ),

              const SizedBox(height: 26),
              _Segmented<FaceSize>(
                skin: skin,
                value: _size,
                options: FaceSize.values,
                labelOf: (f) => f.label,
                onChanged: (f) => setState(() => _size = f),
              ),
              const SizedBox(height: 10),
              _Segmented<WidgetSkin>(
                skin: skin,
                value: _skinChoice,
                options: WidgetSkin.values,
                labelOf: (m) => switch (m) {
                  WidgetSkin.dark => 'Dark',
                  WidgetSkin.light => 'Light',
                  WidgetSkin.system => 'Auto',
                },
                onChanged: (m) => setState(() => _skinChoice = m),
              ),

              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _pinning ? null : _addToHome,
                icon: _pinning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.add_to_home_screen_rounded, size: 19),
                label: const Text('Add to home screen'),
              ),

              const SizedBox(height: 30),
              Divider(color: skin.line, height: 1),
              const SizedBox(height: 22),

              // ---- the numbers behind the number ----
              Row(children: [
                _Stat(label: 'longest', value: '${s.longestStreak}', skin: skin),
                _Stat(label: 'active days', value: '${s.totalActiveDays}', skin: skin),
                _Stat(
                    label: 'contributions',
                    value: _compact(s.totalContributions),
                    skin: skin),
              ]),

              const SizedBox(height: 26),
              Text('SOURCES', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 14),
              ...live.map((p) => _SourceRow(result: p, skin: skin)),
              ...failed.map((p) => _FailedRow(result: p, skin: skin)),

              const SizedBox(height: 22),
              Text(
                'Days counted in ${s.timezone}. Today is ${s.today}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _compact(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k'
      : '$n';
}

/// A pill-style segmented control. Written by hand rather than using
/// SegmentedButton so the selected pill can carry the product's own accent.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.skin,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final Skin skin;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: skin.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: skin.line),
        ),
        child: Row(
          children: options.map((option) {
            final selected = option == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? skin.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected ? skin.line : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    labelOf(option),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? skin.text : skin.dim,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.skin});

  final String label;
  final String value;
  final Skin skin;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: skin.text, fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: skin.faint, fontSize: 9.5, letterSpacing: 1.2)),
          ],
        ),
      );
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.result, required this.skin});

  final PlatformResult result;
  final Skin skin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: platformColor(result.platform),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(platformLabel(result.platform),
                    style: TextStyle(
                        color: skin.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(result.handle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: skin.faint, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 5),
              Text(
                result.stats.take(3).map((s) => '${s.value} ${s.label}').join('  ·  '),
                style: TextStyle(color: skin.dim, fontSize: 12.5),
              ),
            ]),
          ),
        ]),
      );
}

class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.result, required this.skin});

  final PlatformResult result;
  final Skin skin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, size: 15, color: kDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${platformLabel(result.platform)} · ${result.handle}',
                  style: TextStyle(
                      color: skin.text, fontSize: 13.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              // The reason is shown, not swallowed — usually it is a typo the
              // user can fix in one tap.
              Text(result.error ?? 'unavailable',
                  style: const TextStyle(color: kDanger, fontSize: 12)),
            ]),
          ),
        ]),
      );
}
