import SwiftUI

/// Month grid with a dot for each day that has entries.
struct JournalCalendarView: View {
    let entries: [JournalEntry]
    @State private var month = DateMath.startOfMonth(Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @EnvironmentObject private var router: AppRouter

    private var cal: Calendar { Calendar.current }

    private var entriesByDay: [Date: [JournalEntry]] {
        Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(spacing: Theme.Spacing.m) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous month")
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(Typo.title3)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next month")
                }
                .padding(.horizontal, 4)

                let symbols = cal.veryShortStandaloneWeekdaySymbols
                let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
                HStack {
                    ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                        Text(s).font(Typo.caption).foregroundStyle(Theme.textTertiary).frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 40)
                        }
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)
            .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                if v.translation.width < -40 { shiftMonth(1) } else if v.translation.width > 40 { shiftMonth(-1) }
            })

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Text(selectedDay.formatted(date: .complete, time: .omitted))
                        .font(Typo.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        router.open(NewEntryRoute(date: selectedDay))
                    } label: {
                        Label("Write", systemImage: "plus")
                    }
                    .font(Typo.callout.weight(.medium))
                }
                let dayEntries = entriesByDay[selectedDay] ?? []
                if dayEntries.isEmpty {
                    Text("No entries on this day.")
                        .font(Typo.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, Theme.Spacing.m)
                } else {
                    ForEach(dayEntries.sorted { $0.date < $1.date }) { entry in
                        NavigationLink(value: entry) { JournalEntryCard(entry: entry) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let count = entriesByDay[day]?.count ?? 0
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(.callout, design: .rounded).weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Theme.accent : Theme.textPrimary))
                Circle()
                    .fill(count > 0 ? (isSelected ? Color.white : Theme.gold) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(count) entries")
    }

    private var daysInGrid: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: month)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: month))
        }
        return days
    }

    private func shiftMonth(_ delta: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            month = cal.date(byAdding: .month, value: delta, to: month) ?? month
        }
    }
}

/// Route that opens the editor pre-set to a specific date.
struct NewEntryRoute: Hashable {
    let date: Date
}

/// Month-by-month summary: number of entries, words, moods and photos.
struct JournalMonthlyOverview: View {
    let entries: [JournalEntry]

    private var months: [(month: Date, entries: [JournalEntry])] {
        let grouped = Dictionary(grouping: entries) { DateMath.startOfMonth($0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!) }
    }

    var body: some View {
        LazyVStack(spacing: Theme.Spacing.m) {
            if months.isEmpty {
                EmptyStateView(symbol: "calendar", title: "No months yet", message: "Your monthly overview appears once you've written entries.")
            }
            ForEach(months, id: \.month) { group in
                MonthSummaryCard(month: group.month, entries: group.entries)
            }
        }
        .padding(.horizontal)
    }
}

struct MonthSummaryCard: View {
    let month: Date
    let entries: [JournalEntry]
    @State private var expanded = false

    private var words: Int { entries.reduce(0) { $0 + $1.wordCount } }
    private var photos: [JournalAttachment] { entries.flatMap(\.photoAttachments) }
    private var moodCounts: [(Mood, Int)] {
        let counts = Dictionary(grouping: entries.compactMap(\.mood), by: { $0 }).mapValues(\.count)
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Button { withAnimation { expanded.toggle() } } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(month.formatted(.dateTime.month(.wide).year()))
                            .font(Typo.title3)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(entries.count) entries · \(words) words · \(photos.count) photos")
                            .font(Typo.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if !moodCounts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(moodCounts.prefix(4), id: \.0) { mood, count in
                        Chip(text: "\(mood.label) \(count)", symbol: mood.symbol, color: mood.tint)
                    }
                }
            }

            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(photos.prefix(8)) { p in
                            MediaThumbnail(fileName: p.fileName, maxPixel: 200, cornerRadius: 8)
                                .frame(width: 56, height: 56)
                        }
                    }
                }
            }

            if expanded {
                ForEach(entries.sorted { $0.date > $1.date }) { e in
                    NavigationLink(value: e) {
                        HStack {
                            Text(e.date.formatted(.dateTime.day().weekday(.abbreviated)))
                                .font(Typo.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 56, alignment: .leading)
                            Text(e.displayTitle).font(Typo.callout).foregroundStyle(Theme.textPrimary).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }
}
