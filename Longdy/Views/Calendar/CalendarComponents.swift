import SwiftUI

struct EventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppViewModel
    @ObservedObject var viewModel: CalendarViewModel
    private let event: CoupleEvent?
    @State private var title: String
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var type: EventType
    @State private var memo: String
    @State private var isAllDay: Bool

    init(viewModel: CalendarViewModel, initialDate: Date = Date()) {
        self.viewModel = viewModel
        let calendar = Calendar.current
        let hour = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: initialDate) ?? initialDate
        event = nil
        _title = State(initialValue: "")
        _startAt = State(initialValue: hour)
        _endAt = State(initialValue: hour.addingTimeInterval(3600))
        _type = State(initialValue: .mine)
        _memo = State(initialValue: "")
        _isAllDay = State(initialValue: false)
    }

    init(viewModel: CalendarViewModel, event: CoupleEvent) {
        self.viewModel = viewModel
        self.event = event
        _title = State(initialValue: event.title)
        _startAt = State(initialValue: event.startAt)
        _endAt = State(initialValue: event.endAt)
        _type = State(initialValue: event.type)
        _memo = State(initialValue: event.memo)
        _isAllDay = State(initialValue: Self.isAllDayEvent(startAt: event.startAt, endAt: event.endAt))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event == nil ? "일정 추가" : "일정 수정")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(CalendarPalette.primary)
                        Text("둘만의 시간표에 조용히 남겨둘 일정을 적어요.")
                            .font(.callout)
                            .foregroundStyle(CalendarPalette.muted)
                    }

                    editorCard {
                        TextField("제목", text: $title)
                            .font(.headline)
                        Divider().opacity(0.35)
                        Picker("타입", selection: $type) {
                            ForEach(EventType.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .tint(CalendarPalette.primary)
                    }

                    editorCard {
                        Toggle("하루종일", isOn: $isAllDay)
                            .tint(CalendarPalette.primary)
                            .onChange(of: isAllDay) { _, enabled in
                                if enabled {
                                    applyAllDayRange(for: startAt)
                                }
                            }

                        Divider().opacity(0.35)

                        if isAllDay {
                            DatePicker("날짜", selection: $startAt, displayedComponents: .date)
                                .onChange(of: startAt) { _, newValue in
                                    applyAllDayRange(for: newValue)
                                }
                        } else {
                            DatePicker("시작", selection: $startAt)
                                .onChange(of: startAt) { _, newValue in
                                    endAt = newValue
                                }
                            Divider().opacity(0.35)
                            DatePicker("끝", selection: $endAt)
                        }
                    }

                    editorCard {
                        Text("메모")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CalendarPalette.muted)
                        TextField("짧은 메모", text: $memo, axis: .vertical)
                            .lineLimit(2...5)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            let saveStartAt = normalizedStartAt
                            let saveEndAt = normalizedEndAt
                            if let event {
                                if let updatedEvent = await viewModel.updateEvent(coupleId: appState.coupleId, currentUserId: appState.userId, event: event, title: title, startAt: saveStartAt, endAt: saveEndAt, type: type, memo: memo) {
                                    appState.applySavedEvent(updatedEvent)
                                    dismiss()
                                }
                            } else {
                                guard let localEvent = viewModel.makeLocalEvent(userId: appState.userId, title: title, startAt: saveStartAt, endAt: saveEndAt, type: type, memo: memo) else { return }
                                appState.applySavedEvent(localEvent, protectFromRemote: true)
                                dismiss()
                                if let savedEvent = await viewModel.persistEvent(coupleId: appState.coupleId, event: localEvent) {
                                    appState.removeEvent(localEvent)
                                    appState.applySavedEvent(savedEvent)
                                } else {
                                    appState.removeEvent(localEvent)
                                    appState.errorMessage = viewModel.errorMessage ?? "일정을 저장하지 못했어요. 다시 시도해 주세요."
                                }
                            }
                        }
                    } label: {
                        Text("저장")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(CalendarPalette.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(CalendarPalette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(CalendarPalette.primary)
                }
            }
        }
    }

    private var normalizedStartAt: Date {
        isAllDay ? Calendar.current.startOfDay(for: startAt) : startAt
    }

    private var normalizedEndAt: Date {
        guard isAllDay else { return endAt }
        return Calendar.current.date(byAdding: .day, value: 1, to: normalizedStartAt) ?? normalizedStartAt
    }

    private func applyAllDayRange(for date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        startAt = startOfDay
        endAt = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    }

    private static func isAllDayEvent(startAt: Date, endAt: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startAt)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let legacyEndOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startAt)
            ?? calendar.date(bySettingHour: 23, minute: 0, second: 0, of: startAt)
            ?? startAt
        return calendar.isDate(startAt, equalTo: startOfDay, toGranularity: .minute)
            && (
                calendar.isDate(endAt, equalTo: nextDay, toGranularity: .minute)
                || calendar.isDate(endAt, equalTo: legacyEndOfDay, toGranularity: .minute)
            )
    }

    private func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CalendarPalette.surface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let eventTypes: [EventType]

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundStyle(textColor)
                .frame(width: 34, height: 30)
                .background(dayBackground)
                .clipShape(Capsule())

            HStack(spacing: 3) {
                ForEach(Array(eventTypes.prefix(3)), id: \.rawValue) { type in
                    Circle()
                        .fill(color(for: type))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 46)
        .opacity(isCurrentMonth ? 1 : 0.28)
    }

    private var textColor: Color {
        if isSelected {
            return CalendarPalette.heroInk
        }
        if Calendar.current.component(.weekday, from: date) == 1 {
            return CalendarPalette.primary.opacity(0.82)
        }
        return CalendarPalette.ink
    }

    @ViewBuilder
    private var dayBackground: some View {
        if isSelected {
            CalendarPalette.hero.opacity(0.42)
        } else if isToday {
            CalendarPalette.tertiaryContainer.opacity(0.34)
        } else {
            Color.clear
        }
    }

    private func color(for type: EventType) -> Color {
        CalendarPalette.eventColor(for: type)
    }
}

struct CalendarEventRow: View {
    let event: CoupleEvent
    let owner: LongdyUser?
    let ownerName: String

    var body: some View {
        HStack(spacing: 14) {
            BridgeAvatar(
                user: owner,
                fallback: ownerName.first.map(String.init) ?? "?",
                size: 48,
                strokeColor: CalendarPalette.eventColor(for: event.type)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CalendarPalette.ink)
                    .lineLimit(1)
                Text(timeText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CalendarPalette.muted)
                if !event.memo.isEmpty {
                    Text(event.memo)
                        .font(.caption)
                        .foregroundStyle(CalendarPalette.muted)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(CalendarPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CalendarPalette.surfaceVariant.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: CalendarPalette.primary.opacity(0.05), radius: 10, y: 4)
    }

    private var timeText: String {
        let calendar = Calendar.current
        let sameDay = calendar.isDate(event.startAt, inSameDayAs: event.endAt)
        let startOfDay = calendar.startOfDay(for: event.startAt)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let wholeDay = calendar.isDate(event.startAt, equalTo: startOfDay, toGranularity: .minute) &&
            (
                calendar.isDate(event.endAt, equalTo: nextDay, toGranularity: .minute) ||
                (
                    calendar.isDate(event.startAt, inSameDayAs: event.endAt) &&
                    calendar.component(.hour, from: event.endAt) == 23
                )
            )
        if wholeDay {
            return "\(event.type.rawValue) · 종일"
        }
        if sameDay {
            return "\(event.type.rawValue) · \(event.startAt.formatted(date: .omitted, time: .shortened))"
        }
        return "\(event.type.rawValue) · \(event.startAt.formatted(date: .abbreviated, time: .shortened))"
    }

}

extension View {
    @ViewBuilder
    func swipeActionsIfAvailable(isEnabled: Bool = true, deleteAction: @escaping () -> Void) -> some View {
        if #available(iOS 15.0, *), isEnabled {
            self.swipeActions {
                Button("삭제", role: .destructive) {
                    deleteAction()
                }
            }
        } else {
            self
        }
    }
}
