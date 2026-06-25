import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppViewModel
    @StateObject private var viewModel = CalendarViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                CalendarPalette.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        BridgeScreenHeader(
                            currentUser: appState.currentProfile,
                            partner: appState.partner,
                            eyebrow: "함께 바라보는 시간",
                            title: "우리 캘린더",
                            summary: calendarSummary,
                            primaryColor: CalendarPalette.primary,
                            secondaryColor: CalendarPalette.secondary,
                            inkColor: CalendarPalette.ink
                        )
                        monthHeader
                        monthGrid
                        selectedDayEvents
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 92)
                }

                Button {
                    viewModel.showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(CalendarPalette.heroInk)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [CalendarPalette.hero, CalendarPalette.secondaryContainer],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: CalendarPalette.primary.opacity(0.22), radius: 14, y: 7)
                }
                .accessibilityLabel("일정 추가")
                .padding(.trailing, 20)
                .padding(.bottom, 18)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $viewModel.showingAdd) {
                EventEditorView(viewModel: viewModel, initialDate: viewModel.selectedDate)
            }
            .sheet(item: $viewModel.editingEvent) { event in
                EventEditorView(viewModel: viewModel, event: event)
            }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 12) {
            monthButton("chevron.left") {
                viewModel.moveMonth(by: -1)
            }

            VStack(spacing: 2) {
                Text(yearTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CalendarPalette.muted)
                Text(monthTitle)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(CalendarPalette.primary)
            }
            .frame(maxWidth: .infinity)

            monthButton("chevron.right") {
                viewModel.moveMonth(by: 1)
            }
        }
        .padding(.top, 4)
    }

    private func monthButton(_ image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(CalendarPalette.primary)
                .frame(width: 36, height: 36)
                .background(CalendarPalette.hero.opacity(0.16))
                .clipShape(Circle())
        }
    }

    private var calendarSummary: String {
        let count = appState.events.count
        return count == 0 ? "다가올 일정을 천천히 채워요" : "함께 보는 일정 \(count)개"
    }

    private var monthGrid: some View {
        glassPanel {
            VStack(spacing: 12) {
                LazyVGrid(columns: calendarColumns, spacing: 0) {
                    ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(index == 0 || index == 6 ? CalendarPalette.primary.opacity(0.62) : CalendarPalette.muted)
                            .frame(height: 28)
                    }
                }

                LazyVGrid(columns: calendarColumns, spacing: 6) {
                    ForEach(viewModel.monthCalendarDates, id: \.self) { date in
                        CalendarDayCell(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            isCurrentMonth: Calendar.current.isDate(date, equalTo: viewModel.visibleMonth, toGranularity: .month),
                            eventTypes: viewModel.eventTypes(on: date, events: appState.events)
                        )
                        .onTapGesture {
                            viewModel.selectedDate = date
                        }
                    }
                }
            }
        }
    }

    private var selectedDayEvents: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.selectedDateTitle)
                    .font(.system(size: 23, weight: .medium, design: .serif))
                    .foregroundStyle(CalendarPalette.primary)
                Spacer()
                Text("\(eventsForSelectedDate.count)개 일정")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CalendarPalette.muted)
            }

            if eventsForSelectedDate.isEmpty {
                glassPanel {
                    EmptyStateView(
                        title: "이날은 아직 비어 있어요",
                        message: "만남, 기념일, 바쁜 일정을 추가해요.",
                        systemImage: "calendar.badge.plus"
                    )
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(eventsForSelectedDate) { event in
                        CalendarEventRow(
                            event: event,
                            ownerName: viewModel.ownerName(for: event, currentUserId: appState.userId, members: appState.members)
                        )
                        .onTapGesture {
                            viewModel.editingEvent = event
                        }
                        .contextMenu {
                            Button("수정") {
                                viewModel.editingEvent = event
                            }
                            Button("삭제", role: .destructive) {
                                Task {
                                    if await viewModel.deleteEvent(coupleId: appState.coupleId, event: event) {
                                        appState.removeEvent(event)
                                    }
                                }
                            }
                        }
                        .swipeActionsIfAvailable {
                            Task {
                                if await viewModel.deleteEvent(coupleId: appState.coupleId, event: event) {
                                    appState.removeEvent(event)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var monthTitle: String {
        viewModel.visibleMonth.formatted(.dateTime.month(.wide))
    }

    private var yearTitle: String {
        viewModel.visibleMonth.formatted(.dateTime.year())
    }

    private var eventsForSelectedDate: [CoupleEvent] {
        viewModel.eventsForSelectedDate(from: appState.events)
    }

    private func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CalendarPalette.surface.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(CalendarPalette.surfaceVariant.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: CalendarPalette.primary.opacity(0.05), radius: 12, y: 5)
    }

}

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

                    Button("저장") {
                        Task {
                            let saveStartAt = normalizedStartAt
                            let saveEndAt = normalizedEndAt
                            if let event {
                                if let updatedEvent = await viewModel.updateEvent(coupleId: appState.coupleId, event: event, title: title, startAt: saveStartAt, endAt: saveEndAt, type: type, memo: memo) {
                                    appState.applySavedEvent(updatedEvent)
                                    dismiss()
                                }
                            } else {
                                if let savedEvent = await viewModel.saveEvent(userId: appState.userId, coupleId: appState.coupleId, title: title, startAt: saveStartAt, endAt: saveEndAt, type: type, memo: memo) {
                                    appState.applySavedEvent(savedEvent)
                                    dismiss()
                                }
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(CalendarPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    let ownerName: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CalendarPalette.eventColor(for: event.type).opacity(0.16))
                Image(systemName: icon(for: event.type))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(CalendarPalette.eventColor(for: event.type))
            }
            .frame(width: 48, height: 48)

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

            Text(ownerInitial)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(CalendarPalette.primary)
                .frame(width: 32, height: 32)
                .background(CalendarPalette.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
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

    private var ownerInitial: String {
        ownerName.first.map(String.init) ?? "?"
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

    private func icon(for type: EventType) -> String {
        switch type {
        case .mine: "person.fill"
        case .partner: "person.2.fill"
        case .meet: "airplane.departure"
        case .anniversary: "sparkles"
        }
    }
}

extension View {
    @ViewBuilder
    func swipeActionsIfAvailable(deleteAction: @escaping () -> Void) -> some View {
        if #available(iOS 15.0, *) {
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
