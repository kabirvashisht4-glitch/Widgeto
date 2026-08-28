import 'package:flutter/material.dart';

import 'data/api.dart';
import 'data/models.dart';
import 'data/widget_bridge.dart';
import 'data/widget_config.dart';
import 'features/connect/connect_screen.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/studio/studio_screen.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Best-effort: init() swallows its own failures so a missing or unhappy
  // widget plugin can never stop the app from starting.
  await WidgetBridge.init();
  runApp(const WidgetoApp());
}

class WidgetoApp extends StatelessWidget {
  const WidgetoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Widgeto',
        debugShowCheckedModeBanner: false,
        theme: widgetoTheme(Brightness.light),
        darkTheme: widgetoTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      );
}

/// What the app is doing right now. Modelled explicitly so every state gets a
/// designed screen instead of a spinner standing in for three different things.
enum _Phase { loading, connect, ready, failed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _Phase _phase = _Phase.loading;
  int _tab = 0;

  Map<String, String> _handles = {};
  List<WidgetConfig> _configs = [];
  Activity? _activity;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = await WidgetoApi.loadHandles();
    final configs = await WidgetStore.load();
    if (!mounted) return;

    _configs = configs;
    if (saved.isEmpty) {
      setState(() => _phase = _Phase.connect);
      return;
    }
    _handles = saved;
    await _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final activity = await WidgetoApi.fetch(_handles);
      await WidgetoApi.saveHandles(_handles);
      // Push immediately, so the home screen is never staler than the app the
      // user is looking at.
      await WidgetBridge.push(activity);
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _phase = _Phase.ready;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = '$err';
        // Keep the last good data if we have it; a failed refresh is no reason
        // to throw away a working screen.
        _phase = _activity == null ? _Phase.failed : _Phase.ready;
      });
    }
  }

  Future<void> _persistConfigs(List<WidgetConfig> next) async {
    setState(() => _configs = next);
    await WidgetStore.save(next);
  }

  Future<void> _openStudio(WidgetConfig config, {required bool isNew}) async {
    final activity = _activity;
    if (activity == null) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (routeContext) => StudioScreen(
        config: config,
        activity: activity,
        connected: _handles.keys.toList(),
        onSave: (saved) {
          final next = [..._configs];
          final index = next.indexWhere((c) => c.id == saved.id);
          if (index >= 0) {
            next[index] = saved;
          } else {
            next.add(saved);
          }
          _persistConfigs(next);
          Navigator.of(routeContext).pop();
        },
        // A brand-new widget has nothing to delete yet, and the last one is
        // not removable — an empty gallery is a dead end.
        onDelete: isNew || _configs.length <= 1
            ? null
            : () {
                _persistConfigs(
                    _configs.where((c) => c.id != config.id).toList());
                Navigator.of(routeContext).pop();
              },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.loading) return const _Splash();

    if (_phase == _Phase.connect) {
      return ConnectScreen(
        initial: _handles,
        onDone: (handles) {
          _handles = handles;
          setState(() => _phase = _Phase.loading);
          _load();
        },
      );
    }

    if (_phase == _Phase.failed) {
      return _Failed(
        message: _error ?? 'Something went wrong.',
        onRetry: _load,
        onEditHandles: () => setState(() => _phase = _Phase.connect),
      );
    }

    final activity = _activity!;
    final skin = Skin.of(Theme.of(context).brightness);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            GalleryScreen(
              configs: _configs,
              activity: activity,
              onRefresh: _load,
              onEdit: (config) => _openStudio(config, isNew: false),
              onCreate: () => _openStudio(WidgetStore.blank(), isNew: true),
            ),
            InsightsScreen(activity: activity, onRefresh: _load),
            ConnectScreen(
              initial: _handles,
              embedded: true,
              onDone: (handles) {
                _handles = handles;
                setState(() => _tab = 0);
                _load();
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: skin.surface,
        indicatorColor: kGitHub.withValues(alpha: 0.18),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets_rounded),
            label: 'Widgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.link_outlined),
            selectedIcon: Icon(Icons.link_rounded),
            label: 'Sources',
          ),
        ],
      ),
    );
  }
}

/// A quiet first frame: the mark, and nothing else claiming to know anything.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: WidgetoMark(size: 34)));
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.onRetry,
    required this.onEditHandles,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onEditHandles;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(Theme.of(context).brightness);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WidgetoMark(size: 28),
              const SizedBox(height: 22),
              Text("Couldn't reach your streak.",
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 12),
              // The real reason, not a generic apology — it is usually a typo
              // or a dropped connection, and both are the user's to fix.
              Text(message, style: const TextStyle(color: kDanger, fontSize: 13.5)),
              const SizedBox(height: 30),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onEditHandles,
                child: Text('Check my handles',
                    style:
                        TextStyle(color: skin.dim, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three squares: the contribution grid reduced to its atom.
class WidgetoMark extends StatelessWidget {
  const WidgetoMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MarkPainter(size)),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.size);

  final double size;

  @override
  void paint(Canvas canvas, Size s) {
    final unit = size / 22;
    void square(double x, double y, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * unit, y * unit, 8 * unit, 8 * unit),
          Radius.circular(2 * unit),
        ),
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
