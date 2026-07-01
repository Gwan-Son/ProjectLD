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
        .onAppear {
            appState.markCalendarViewedToday()
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
                            owner: eventOwner(for: event),
                            ownerName: viewModel.ownerName(for: event, currentUserId: appState.userId, members: appState.members)
                        )
                        .onTapGesture {
                            if isMyEvent(event) {
                                viewModel.editingEvent = event
                            }
                        }
                        .contextMenu {
                            if isMyEvent(event) {
                                Button("수정") {
                                    viewModel.editingEvent = event
                                }
                                Button("삭제", role: .destructive) {
                                    Task {
                                        if await viewModel.deleteEvent(
                                            coupleId: appState.coupleId,
                                            currentUserId: appState.userId,
                                            event: event
                                        ) {
                                            appState.removeEvent(event)
                                        }
                                    }
                                }
                            }
                        }
                        .swipeActionsIfAvailable(isEnabled: isMyEvent(event)) {
                            Task {
                                if await viewModel.deleteEvent(
                                    coupleId: appState.coupleId,
                                    currentUserId: appState.userId,
                                    event: event
                                ) {
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

    private func isMyEvent(_ event: CoupleEvent) -> Bool {
        event.ownerUserId == appState.userId
    }

    private func eventOwner(for event: CoupleEvent) -> LongdyUser? {
        if event.ownerUserId == appState.userId {
            return appState.currentProfile
        }
        return appState.members.first { $0.id == event.ownerUserId }
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
