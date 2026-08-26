import 'package:flutter/material.dart';
import 'data/api.dart';
import 'data/models.dart';
import 'data/widget_bridge.dart';
import 'ui/grid.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetBridge.init();
  runApp(const WidgetoApp());
}

class WidgetoApp extends StatelessWidget {
  const WidgetoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Widgeto',
        debugShowCheckedModeBanner: false,
        theme: widgetoTheme,
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controllers = {
    for (final p in WidgetoApi.platforms) p: TextEditingController(),
  };
  Activity? _activity;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _restore() async {
    final saved = await WidgetoApi.loadHandles();
    if (saved.isEmpty) return;
    saved.forEach((k, v) => _controllers[k]?.text = v);
    if (mounted) _refresh();
  }

  Future<void> _refresh() async {
    final handles = {
      for (final e in _controllers.entries) e.key: e.value.text.trim(),
    }..removeWhere((_, v) => v.isEmpty);

    if (handles.isEmpty) {
      setState(() => _error = 'Add at least one handle.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final activity = await WidgetoApi.fetch(handles);
      await WidgetoApi.saveHandles(handles);
      // Push to the home screen immediately so the widget is never staler
      // than the app the user is looking at.
      await WidgetBridge.push(activity);
      if (mounted) setState(() => _activity = activity);
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _activity;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: kGitHub,
          backgroundColor: kSurface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
            children: [
              Row(children: [
                const _Mark(),
                const SizedBox(width: 10),
                Text('Widgeto', style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 26),

              if (a != null) ...[
                _StreakHeader(summary: a.summary),
                const SizedBox(height: 22),
                ContributionGrid(days: a.heatmap),
                const SizedBox(height: 26),
                ...a.platforms.map((p) => _PlatformRow(result: p)),
                const SizedBox(height: 30),
                const Divider(height: 1),
                const SizedBox(height: 24),
              ],

              Text('Handles', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 12),
              ...WidgetoApi.platforms.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _controllers[p],
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: p,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: platformColor(p),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: kDanger, fontSize: 13)),
              ],

              const SizedBox(height: 14),
              FilledButton(
                onPressed: _loading ? null : _refresh,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Update my widget'),
              ),
              const SizedBox(height: 14),
              Text(
                'Public profiles only. Widgeto never asks for a password.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakHeader extends StatelessWidget {
  const _StreakHeader({required this.summary});
  final StreakSummary summary;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (summary.status) {
      'safe' => ('done today', kGitHub),
      'at-risk' => ('not yet today', kFlameHot),
      _ => ('streak broken', kDanger),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UNIFIED STREAK', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${summary.currentStreak}',
                style: const TextStyle(
                  fontSize: 68,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: kFlameHot,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 10),
              Text('days', style: Theme.of(context).textTheme.bodyMedium),
            ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: color, fontSize: 12.5)),
          const Spacer(),
          Text('longest ${summary.longestStreak}d',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ],
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({required this.result});
  final PlatformResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: result.ok ? platformColor(result.platform) : kDanger,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(result.handle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ),
        Expanded(
          child: Text(
            result.ok
                ? result.stats.take(2).map((s) => '${s.value} ${s.label}').join('  ·  ')
                : (result.error ?? 'unavailable'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: result.ok ? kTextFaint : kDanger,
            ),
          ),
        ),
      ]),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 22, height: 22,
        child: CustomPaint(painter: _MarkPainter()),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void square(double x, double y, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 8, 8), const Radius.circular(2)),
        Paint()..color = c,
      );
    }
    square(1, 12, kGitHub);
    square(12, 12, kLeetCode);
    square(6.5, 1.5, kCodeforces);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
