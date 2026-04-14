import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: .now)], policy: .never))
    }
}

struct RollWidgetEntryView: View {
    var body: some View {
        Image(systemName: "camera.fill")
            .font(.title3)
    }
}

@main
struct RollLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.roll.lockscreen",
            provider: Provider()
        ) { _ in
            RollWidgetEntryView()
                .containerBackground(.clear, for: .widget)
        }
        .supportedFamilies([.accessoryCircular])
        .configurationDisplayName("Roll")
        .description("Open Roll camera.")
    }
}
