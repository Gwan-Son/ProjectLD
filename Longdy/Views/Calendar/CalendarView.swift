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
                        bridgeHeader
                        monthHeader
                        monthGrid
                        selectedDayEvents
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
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

    private var bridgeHeader: some View {
        HStack {
            avatar(for: appState.currentProfile, fallback: "나", stroke: CalendarPalette.hero)
            Spacer()
            Text("Our Bridge")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(CalendarPalette.primary)
            Spacer()
            avatar(for: appState.partner, fallback: "?", stroke: CalendarPalette.secondaryContainer)
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
                                Task { await viewModel.deleteEvent(coupleId: appState.coupleId, event: event) }
                            }
                        }
                        .swipeActionsIfAvailable {
                            Task { await viewModel.deleteEvent(coupleId: appState.coupleId, event: event) }
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

    private func avatar(for user: LongdyUser?, fallback: String, stroke: Color) -> some View {
        Text(user?.friendlyName.first.map(String.init) ?? fallback)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(CalendarPalette.primary)
            .frame(width: 40, height: 40)
            .background(CalendarPalette.surface)
            .clipShape(Circle())
            .overlay(Circle().stroke(stroke, lineWidth: 2))
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
    }

    init(viewModel: CalendarViewModel, event: CoupleEvent) {
        self.viewModel = viewModel
        self.event = event
        _title = State(initialValue: event.title)
        _startAt = State(initialValue: event.startAt)
        _endAt = State(initialValue: event.endAt)
        _type = State(initialValue: event.type)
        _memo = State(initialValue: event.memo)
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
                        DatePicker("시작", selection: $startAt)
                        Divider().opacity(0.35)
                        DatePicker("끝", selection: $endAt)
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
                            if let event {
                                if await viewModel.updateEvent(coupleId: appState.coupleId, event: event, title: title, startAt: startAt, endAt: endAt, type: type, memo: memo) {
                                    dismiss()
                                }
                            } else {
                                if await viewModel.saveEvent(userId: appState.userId, coupleId: appState.coupleId, title: title, startAt: startAt, endAt: endAt, type: type, memo: memo) {
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
        let wholeDay = calendar.component(.hour, from: event.startAt) == 0 &&
            calendar.component(.minute, from: event.startAt) == 0 &&
            calendar.component(.hour, from: event.endAt) == 23
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

private enum CalendarPalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.98)
    static let surface = Color(red: 1.00, green: 0.98, blue: 0.98)
    static let surfaceVariant = Color(red: 0.98, green: 0.85, blue: 0.91)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let hero = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let heroInk = Color(red: 0.44, green: 0.18, blue: 0.16)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let secondaryContainer = Color(red: 0.99, green: 0.78, blue: 0.68)
    static let tertiary = Color(red: 0.45, green: 0.35, blue: 0.25)
    static let tertiaryContainer = Color(red: 0.80, green: 0.67, blue: 0.55)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)

    static func eventColor(for type: EventType) -> Color {
        switch type {
        case .mine: primary
        case .partner: secondary
        case .meet: tertiary
        case .anniversary: Color(red: 0.70, green: 0.36, blue: 0.52)
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
