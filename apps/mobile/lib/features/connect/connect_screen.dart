import 'package:flutter/material.dart';

import '../../data/api.dart';
import '../../ui/theme.dart';

/// Pick platforms off a wall of tiles, one tap each.
///
/// Deliberately not a form. For every platform here, "connecting" is just
/// naming yourself — the data is on a public profile, so there is no OAuth
/// redirect and no password to hand over. That is the one structural advantage
/// Widgeto has over every connector product that must put a sign-in wall in
/// front of a first-run user, and the screen should feel like it.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.initial, required this.onDone});

  final Map<String, String> initial;
  final ValueChanged<Map<String, String>> onDone;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final Map<String, String> _handles = {...widget.initial};

  Future<void> _edit(String platform) async {
    final controller = TextEditingController(text: _handles[platform] ?? '');
    final skin = Skin.of(Theme.of(context).brightness);

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: skin.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        // Lift above the keyboard rather than hiding the field behind it.
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 22,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Mark(platform: platform, size: 34),
              const SizedBox(width: 12),
              Text(platformLabel(platform),
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ]),
            const SizedBox(height: 6),
            Text(
              'Your public username. No password, ever.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: WidgetoApi.hintFor(platform),
                prefixIcon: const Icon(Icons.alternate_email, size: 18),
              ),
              onSubmitted: (v) => Navigator.pop(sheetContext, v.trim()),
            ),
            const SizedBox(height: 14),
            Row(children: [
              if ((_handles[platform] ?? '').isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, ''),
                  child: const Text('Disconnect',
                      style: TextStyle(color: kDanger, fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 46)),
                onPressed: () => Navigator.pop(sheetContext, controller.text.trim()),
                child: const Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    );

    if (value == null) return; // dismissed without deciding
    setState(() {
      if (value.isEmpty) {
        _handles.remove(platform);
      } else {
        _handles[platform] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(Theme.of(context).brightness);
    final connected = _handles.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                children: [
                  Text('CONNECT',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 12),
                  Text('Where do you\ncode?',
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 14),
                  Text(
                    'Tap a platform and type your username. Everything here is '
                    'public profile data, so there is nothing to sign in to.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.32,
                    children: [
                      for (final p in WidgetoApi.platforms)
                        _Tile(
                          platform: p,
                          handle: _handles[p],
                          skin: skin,
                          onTap: () => _edit(p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Icon(Icons.lock_outline, size: 14, color: skin.faint),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Widgeto never asks for a password or a session cookie.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: FilledButton(
                onPressed: connected == 0 ? null : () => widget.onDone(_handles),
                child: Text(connected == 0
                    ? 'Add at least one'
                    : 'Build my streak  ·  $connected connected'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.platform,
    required this.handle,
    required this.skin,
    required this.onTap,
  });

  final String platform;
  final String? handle;
  final Skin skin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = (handle ?? '').isNotEmpty;
    final tint = platformColor(platform);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        // A connected tile is tinted with its own brand colour, so the wall
        // reads at a glance instead of needing checkmarks.
        color: on ? Color.alphaBlend(tint.withValues(alpha: 0.10), skin.surface) : skin.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: on ? tint.withValues(alpha: 0.55) : skin.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Mark(platform: platform, size: 32),
                const Spacer(),
                Text(platformLabel(platform),
                    style: TextStyle(
                        color: skin.text, fontSize: 14.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  on ? handle! : 'tap to add',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: on ? tint : skin.faint,
                    fontSize: 12,
                    fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.platform, required this.size});

  final String platform;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: platformColor(platform),
          borderRadius: BorderRadius.circular(size * 0.29),
        ),
        child: Text(
          platformMark(platform),
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.82),
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
