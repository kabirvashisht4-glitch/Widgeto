import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/theme.dart';

/// What a widget *is*, in Widgeto: a small piece of configuration, not code.
///
/// This is the whole architecture of the product. A home-screen widget cannot
/// run user-written code — the App Store forbids downloading executables and
/// SwiftUI views must be compiled in — so a user's "custom widget" has to be
/// data that a fixed renderer interprets. Everything a person can change lives
/// in this object, and the app, the native iOS face and the native Android
/// face all read the same one.

/// The layouts a widget can take. Adding one means adding a renderer and a
/// case here; nothing else in the app changes.
enum FaceTemplate {
  grid('Grid', 'The contribution calendar, blended by platform'),
  flame('Flame', 'The streak, and how close it is to breaking'),
  minimal('Minimal', 'One number, nothing else'),
  stats('Stats', 'Streak, longest, active days, total'),
  split('Split', 'How the streak divides across platforms'),
  ring('Ring', 'Progress toward your next milestone');

  const FaceTemplate(this.label, this.blurb);

  final String label;
  final String blurb;
}

enum FaceSize {
  small('Small', 158, 158),
  medium('Medium', 338, 158),
  large('Large', 338, 338);

  const FaceSize(this.label, this.width, this.height);

  final String label;
  final double width;
  final double height;

  bool get isWide => this == FaceSize.medium;
  bool get isLarge => this == FaceSize.large;
}

/// The accent is the one colour a person picks, and it drives the streak
/// number, the status dot and the ring. The platform hues in the grid stay
/// fixed — they carry meaning, so they are not the user's to recolour.
enum Accent {
  flame('Flame', Color(0xFFFFB43D)),
  green('Green', Color(0xFF39D353)),
  ice('Ice', Color(0xFF4AA3E0)),
  ember('Ember', Color(0xFFFF7A45)),
  violet('Violet', Color(0xFFA78BFA)),
  rose('Rose', Color(0xFFFF6B9D));

  const Accent(this.label, this.color);

  final String label;
  final Color color;
}

@immutable
class WidgetConfig {
  const WidgetConfig({
    required this.id,
    this.name = 'My widget',
    this.template = FaceTemplate.grid,
    this.size = FaceSize.medium,
    this.skin = WidgetSkin.dark,
    this.accent = Accent.flame,
    this.platforms = const <String>{},
    this.showCaption = true,
  });

  final String id;
  final String name;
  final FaceTemplate template;
  final FaceSize size;
  final WidgetSkin skin;
  final Accent accent;

  /// Which sources feed this widget. Empty means every connected one — so a
  /// newly connected platform joins existing widgets instead of being silently
  /// left out.
  final Set<String> platforms;

  final bool showCaption;

  WidgetConfig copyWith({
    String? name,
    FaceTemplate? template,
    FaceSize? size,
    WidgetSkin? skin,
    Accent? accent,
    Set<String>? platforms,
    bool? showCaption,
  }) =>
      WidgetConfig(
        id: id,
        name: name ?? this.name,
        template: template ?? this.template,
        size: size ?? this.size,
        skin: skin ?? this.skin,
        accent: accent ?? this.accent,
        platforms: platforms ?? this.platforms,
        showCaption: showCaption ?? this.showCaption,
      );

  /// Does this widget include `platform`? An empty set means "all of them".
  bool includes(String platform) =>
      platforms.isEmpty || platforms.contains(platform);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'template': template.name,
        'size': size.name,
        'skin': skin.name,
        'accent': accent.name,
        'platforms': platforms.toList(),
        'showCaption': showCaption,
      };

  /// Every field falls back rather than throwing: a config written by an older
  /// or newer build must still open, or the user loses widgets to an upgrade.
  factory WidgetConfig.fromJson(Map<String, dynamic> json) => WidgetConfig(
        id: '${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
        name: json['name'] as String? ?? 'My widget',
        template: _byName(FaceTemplate.values, json['template'], FaceTemplate.grid),
        size: _byName(FaceSize.values, json['size'], FaceSize.medium),
        skin: _byName(WidgetSkin.values, json['skin'], WidgetSkin.dark),
        accent: _byName(Accent.values, json['accent'], Accent.flame),
        platforms: ((json['platforms'] as List?) ?? const [])
            .map((e) => '$e')
            .toSet(),
        showCaption: json['showCaption'] != false,
      );

  static T _byName<T extends Enum>(List<T> values, Object? raw, T fallback) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetConfig &&
      other.id == id &&
      other.name == name &&
      other.template == template &&
      other.size == size &&
      other.skin == skin &&
      other.accent == accent &&
      other.showCaption == showCaption &&
      other.platforms.length == platforms.length &&
      other.platforms.containsAll(platforms);

  @override
  int get hashCode => Object.hash(
      id, name, template, size, skin, accent, showCaption, platforms.length);
}

/// The user's saved widgets.
class WidgetStore {
  static const _key = 'widget_configs';

  static Future<List<WidgetConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [defaultConfig()];

    try {
      final list = jsonDecode(raw) as List;
      final configs = list
          .map((e) => WidgetConfig.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      // Never hand back an empty gallery; an empty list is indistinguishable
      // from a corrupt write, and a first-run widget is the better outcome.
      return configs.isEmpty ? [defaultConfig()] : configs;
    } catch (_) {
      return [defaultConfig()];
    }
  }

  static Future<void> save(List<WidgetConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(configs.map((c) => c.toJson()).toList()));
  }

  static WidgetConfig defaultConfig() =>
      WidgetConfig(id: '${DateTime.now().microsecondsSinceEpoch}');

  static WidgetConfig blank() => WidgetConfig(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: 'New widget',
      );
}
