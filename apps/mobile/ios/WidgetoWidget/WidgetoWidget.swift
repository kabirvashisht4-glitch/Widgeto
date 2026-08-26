//
//  WidgetoWidget.swift
//  The iOS home-screen face.
//
//  This extension deliberately does no work. It never calls the network, never
//  parses JSON and never computes a streak — the Flutter app has already
//  written a finished payload into the shared App Group container, and all
//  this does is read and draw. Widget extensions run under a very small memory
//  budget and can be killed for overrunning it, so "dumb renderer" is the only
//  design that stays reliable.
//

import WidgetKit
import SwiftUI

// Must match WidgetBridge.iosAppGroup in the Flutter app.
let appGroup = "group.me.widgeto.shared"

// MARK: - Palette (mirrors the web and app tokens)

extension Color {
    static let wBg       = Color(red: 0.03, green: 0.04, blue: 0.05)
    static let wEmpty    = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let wText     = Color(red: 0.93, green: 0.93, blue: 0.95)
    static let wDim      = Color(red: 0.60, green: 0.63, blue: 0.68)
    static let wGitHub   = Color(red: 0.22, green: 0.83, blue: 0.33)
    static let wCodef    = Color(red: 0.29, green: 0.64, blue: 0.88)
    static let wLeet     = Color(red: 1.00, green: 0.63, blue: 0.09)
    static let wFlame    = Color(red: 1.00, green: 0.71, blue: 0.24)
    static let wDanger   = Color(red: 1.00, green: 0.36, blue: 0.36)
}

// MARK: - Model

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let longest: Int
    let status: String      // safe | at-risk | broken
    let cells: [(level: Int, platform: Character)]

    /// Shown in the widget gallery, before any real data exists.
    static let placeholder: StreakEntry = {
        let palette: [Character] = ["g", "c", "l", "-"]
        let cells = (0..<140).map { i in
            (level: (i * 7) % 5, platform: palette[i % palette.count])
        }
        return StreakEntry(date: Date(), streak: 57, longest: 80,
                           status: "at-risk", cells: cells)
    }()
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = read()

        // iOS grants a widget only a few dozen refreshes a day, so we do not
        // ask for more than we can use. Refresh sooner when the streak is at
        // risk — that is the state where a stale number actually costs the
        // user something.
        let minutes = entry.status == "at-risk" ? 30 : 60
        let next = Calendar.current.date(byAdding: .minute, value: minutes, to: Date())!

        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func read() -> StreakEntry {
        let store = UserDefaults(suiteName: appGroup)
        return StreakEntry(
            date: Date(),
            streak: store?.integer(forKey: "streak") ?? 0,
            longest: store?.integer(forKey: "longest") ?? 0,
            status: store?.string(forKey: "status") ?? "broken",
            cells: decodeGrid(store?.string(forKey: "grid") ?? "")
        )
    }

    /// Grid arrives as `LP` pairs: L is intensity 0-4, P is the dominant
    /// platform (g/c/l) or `-` for an idle day.
    private func decodeGrid(_ raw: String) -> [(level: Int, platform: Character)] {
        let chars = Array(raw)
        var out: [(level: Int, platform: Character)] = []
        var i = 0
        while i + 1 < chars.count {
            out.append((level: chars[i].wholeNumberValue ?? 0, platform: chars[i + 1]))
            i += 2
        }
        return out
    }
}

// MARK: - Rendering

func platformColor(_ p: Character) -> Color {
    switch p {
    case "g": return .wGitHub
    case "c": return .wCodef
    case "l": return .wLeet
    default:  return .wEmpty
    }
}

func cellColor(level: Int, platform: Character) -> Color {
    guard level > 0 else { return .wEmpty }
    // Match the web's intensity floor so a light day is still visible.
    let t = 0.25 + 0.75 * (Double(level) / 4.0)
    return Color.wEmpty.mix(with: platformColor(platform), amount: t)
}

extension Color {
    /// Simple sRGB interpolation — enough for 11pt squares.
    func mix(with other: Color, amount: Double) -> Color {
        let a = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let b = UIColor(other).cgColor.components ?? [0, 0, 0, 1]
        return Color(
            red:   a[0] + (b[0] - a[0]) * amount,
            green: a[1] + (b[1] - a[1]) * amount,
            blue:  a[2] + (b[2] - a[2]) * amount
        )
    }
}

struct MiniGrid: View {
    let cells: [(level: Int, platform: Character)]
    let weeks: Int
    var cell: CGFloat = 8
    var gap: CGFloat = 2

    var body: some View {
        let shown = Array(cells.suffix(weeks * 7))
        HStack(alignment: .top, spacing: gap) {
            ForEach(0..<(shown.count / 7), id: \.self) { col in
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { row in
                        let c = shown[col * 7 + row]
                        RoundedRectangle(cornerRadius: 1.8)
                            .fill(cellColor(level: c.level, platform: c.platform))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }
}

struct StatusDot: View {
    let status: String

    var color: Color {
        switch status {
        case "safe":    return .wGitHub
        case "at-risk": return .wFlame
        default:        return .wDanger
        }
    }

    var label: String {
        switch status {
        case "safe":    return "done today"
        case "at-risk": return "not yet today"
        default:        return "broken"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
        }
    }
}

struct WidgetoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("UNIFIED STREAK")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.wDim)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(entry.streak)")
                    .font(.system(size: family == .systemSmall ? 44 : 54,
                                  weight: .bold, design: .rounded))
                    .foregroundStyle(Color.wFlame)
                Text("days").font(.system(size: 12)).foregroundStyle(Color.wDim)
            }
            .padding(.top, 2)

            StatusDot(status: entry.status).padding(.top, 3)

            Spacer(minLength: 8)

            MiniGrid(
                cells: entry.cells,
                weeks: family == .systemSmall ? 7 : 20,
                cell: family == .systemSmall ? 8 : 9
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color.wBg, for: .widget)
    }
}

@main
struct WidgetoWidget: Widget {
    let kind = "WidgetoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Unified streak")
        .description("Your GitHub, Codeforces and LeetCode activity as one streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
