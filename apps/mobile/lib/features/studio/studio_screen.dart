import 'package:flutter/material.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../data/widget_config.dart';
import '../../ui/theme.dart';
import '../../widgets/contribution_grid.dart';
import '../../widgets/faces/widget_face.dart';

/// The widget editor.
///
/// Everything changes under a live preview at true size, because the only
/// question that matters — does this look right on my home screen — cannot be
/// answered by a list of settings. Nothing is committed until Save, so people
/// can try the loud options without consequence.
class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    required this.config,
    required this.activity,
    required this.connected,
    required this.onSave,
    required this.onDelete,
  });

  final WidgetConfig config;
  final Activity activity;

  /// Platforms the user actually connected — you cannot scope a widget to a
  /// source that isn't there.
  final List<String> connected;

  final ValueChanged<WidgetConfig> onSave;
  final VoidCallback? onDelete;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  late WidgetConfig _draft = widget.config;
  final _gridKey = GlobalKey<ContributionGridState>();
  late final _nameController = TextEditingController(text: _draft.name);

  bool get _dirty => _draft != widget.config;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _update(WidgetConfig next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: skin.ground,
        elevation: 0,
        title: Text(widget.config.name == 'New widget' ? 'New widget' : 'Edit widget',
            style: Theme.of(context).textTheme.titleMedium),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
              color: skin.faint,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: skin.surface,
                    title: const Text('Delete this widget?'),
                    content: Text('“${_draft.name}” will be removed.',
                        style: TextStyle(color: skin.dim)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Keep')),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Delete',
                            style: TextStyle(color: kDanger)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) widget.onDelete!();
              },
            ),
          TextButton(
            onPressed: _dirty ? () => widget.onSave(_draft) : null,
            child: Text('Save',
                style: TextStyle(
                    color: _dirty ? kGitHub : skin.faint,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ---- the preview, at true size ----
          Container(
            padding: const EdgeInsets.symmetric(vertical: 26),
            decoration: BoxDecoration(
              color: skin.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: skin.line),
            ),
            child: Column(children: [
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: WidgetFace(
                    activity: widget.activity,
                    config: _draft,
                    gridKey: _gridKey,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () => _gridKey.currentState?.replay(),
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Replay'),
                style: TextButton.styleFrom(foregroundColor: skin.faint),
              ),
            ]),
          ),

          const SizedBox(height: 26),
          _label('LAYOUT', skin),
          const SizedBox(height: 12),
          _TemplatePicker(
            value: _draft.template,
            skin: skin,
            accent: _draft.accent.color,
            onChanged: (t) => _update(_draft.copyWith(template: t)),
          ),

          const SizedBox(height: 24),
          _label('SIZE', skin),
          const SizedBox(height: 10),
          _Segmented<FaceSize>(
            skin: skin,
            value: _draft.size,
            options: FaceSize.values,
            labelOf: (f) => f.label,
            onChanged: (f) => _update(_draft.copyWith(size: f)),
          ),

          const SizedBox(height: 20),
          _label('PALETTE', skin),
          const SizedBox(height: 10),
          _Segmented<WidgetSkin>(
            skin: skin,
            value: _draft.skin,
            options: WidgetSkin.values,
            labelOf: (m) => switch (m) {
              WidgetSkin.dark => 'Dark',
              WidgetSkin.light => 'Light',
              WidgetSkin.system => 'Auto',
            },
            onChanged: (m) => _update(_draft.copyWith(skin: m)),
          ),

          const SizedBox(height: 24),
          _label('ACCENT', skin),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final accent in Accent.values)
                _Swatch(
                  accent: accent,
                  selected: _draft.accent == accent,
                  skin: skin,
                  onTap: () => _update(_draft.copyWith(accent: accent)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The grid keeps each platform’s own colour — those mean something.',
            style: TextStyle(color: skin.faint, fontSize: 12),
          ),

          if (widget.connected.length > 1) ...[
            const SizedBox(height: 24),
            _label('SOURCES', skin),
            const SizedBox(height: 12),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final platform in widget.connected)
                  _SourceChip(
                    platform: platform,
                    selected: _draft.includes(platform),
                    skin: skin,
                    onTap: () {
                      // An empty set means "all", so the first deselection has
                      // to materialise the full set before removing one.
                      final current = _draft.platforms.isEmpty
                          ? widget.connected.toSet()
                          : {..._draft.platforms};
                      if (current.contains(platform)) {
                        if (current.length == 1) return; // never zero sources
                        current.remove(platform);
                      } else {
                        current.add(platform);
                      }
                      _update(_draft.copyWith(
                        platforms: current.length == widget.connected.length
                            ? <String>{}
                            : current,
                      ));
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _draft.showCaption,
            activeThumbColor: kGitHub,
            title: Text('Show caption',
                style: TextStyle(color: skin.text, fontSize: 15)),
            subtitle: Text('The small label above the number',
                style: TextStyle(color: skin.faint, fontSize: 12.5)),
            onChanged: (v) => _update(_draft.copyWith(showCaption: v)),
          ),

          const SizedBox(height: 14),
          _label('NAME', skin),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'My widget'),
            onChanged: (v) =>
                _update(_draft.copyWith(name: v.trim().isEmpty ? 'My widget' : v.trim())),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Skin skin) => Text(text,
      style: TextStyle(
          color: skin.faint, fontSize: 10.5, letterSpacing: 1.8, fontWeight: FontWeight.w500));
}

/// Layout choices shown as cards, since the difference between them is visual
/// and a dropdown of six words would tell you nothing.
class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.value,
    required this.skin,
    required this.accent,
    required this.onChanged,
  });

  final FaceTemplate value;
  final Skin skin;
  final Color accent;
  final ValueChanged<FaceTemplate> onChanged;

  static const _icons = {
    FaceTemplate.grid: Icons.grid_on_rounded,
    FaceTemplate.flame: Icons.local_fire_department_rounded,
    FaceTemplate.minimal: Icons.numbers_rounded,
    FaceTemplate.stats: Icons.dashboard_rounded,
    FaceTemplate.split: Icons.pie_chart_rounded,
    FaceTemplate.ring: Icons.donut_large_rounded,
  };

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.98,
        children: [
          for (final template in FaceTemplate.values)
            GestureDetector(
              onTap: () => onChanged(template),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: template == value
                      ? Color.alphaBlend(accent.withValues(alpha: 0.12), skin.surface)
                      : skin.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: template == value
                        ? accent.withValues(alpha: 0.65)
                        : skin.line,
                    width: template == value ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icons[template],
                        size: 20,
                        color: template == value ? accent : skin.faint),
                    const Spacer(),
                    Text(template.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: skin.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.selected,
    required this.skin,
    required this.onTap,
  });

  final Accent accent;
  final bool selected;
  final Skin skin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label: accent.label,
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? skin.text : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded,
                    size: 20, color: Colors.black.withValues(alpha: 0.75))
                : null,
          ),
        ),
      );
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.platform,
    required this.selected,
    required this.skin,
    required this.onTap,
  });

  final String platform;
  final bool selected;
  final Skin skin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = platformColor(platform);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(tint.withValues(alpha: 0.14), skin.surface)
              : skin.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: selected ? tint.withValues(alpha: 0.6) : skin.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: selected ? tint : skin.faint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(platformLabel(platform),
              style: TextStyle(
                  color: selected ? skin.text : skin.dim, fontSize: 13)),
        ]),
      ),
    );
  }
}

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
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? skin.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: selected ? skin.line : Colors.transparent),
                  ),
                  child: Text(labelOf(option),
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? skin.text : skin.dim)),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

/// Exposed so the gallery can offer the same hint text when nothing is set up.
String studioHintFor(String platform) => WidgetoApi.hintFor(platform);
