import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage

final class FirebaseService {
    static let shared = FirebaseService()

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private init() {}

    var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    func listenToAuth(_ handler: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle? {
        guard isConfigured else {
            handler(nil)
            return nil
        }
        return Auth.auth().addStateDidChangeListener { _, user in
            handler(user)
        }
    }

    func removeAuthListener(_ handle: AuthStateDidChangeListenerHandle?) {
        guard let handle else { return }
        Auth.auth().removeStateDidChangeListener(handle)
    }

    func signIn(email: String, password: String) async throws {
        guard isConfigured else { throw LongdyError.firebaseNotConfigured }
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(email: String, password: String, displayName: String, nickname: String, cityName: String, timezoneId: String) async throws {
        guard isConfigured else { throw LongdyError.firebaseNotConfigured }
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        try await upsertUserProfile(
            userId: result.user.uid,
            email: email,
            displayName: displayName,
            nickname: nickname,
            cityName: cityName,
            timezoneId: timezoneId
        )
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func upsertUserProfile(userId: String, email: String, displayName: String, nickname: String, cityName: String, timezoneId: String) async throws {
        let ref = db.collection("users").document(userId)
        let existing = try? await ref.getDocument()
        var data: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "nickname": nickname,
            "cityName": cityName,
            "timezoneId": timezoneId
        ]
        if existing?.exists != true {
            data["createdAt"] = Timestamp(date: Date())
        }
        try await ref.setData(data, merge: true)
    }

    func listenToUser(userId: String, handler: @escaping (LongdyUser?) -> Void) -> ListenerRegistration {
        db.collection("users").document(userId).addSnapshotListener { snapshot, _ in
            handler(snapshot.flatMap { Self.decodeUser(id: userId, data: $0.data()) })
        }
    }

    func listenToCouple(coupleId: String, handler: @escaping (Couple?) -> Void) -> ListenerRegistration {
        db.collection("couples").document(coupleId).addSnapshotListener { snapshot, _ in
            handler(snapshot.flatMap { Self.decodeCouple(id: coupleId, data: $0.data()) })
        }
    }

    func createCouple(for userId: String) async throws -> Couple {
        let coupleRef = db.collection("couples").document()
        let inviteCode = Self.makeInviteCode()
        let now = Date()
        try await coupleRef.setData([
            "memberIds": [userId],
            "inviteCode": inviteCode,
            "createdAt": Timestamp(date: now)
        ])
        try await db.collection("inviteCodes").document(inviteCode).setData([
            "coupleId": coupleRef.documentID,
            "createdAt": Timestamp(date: now)
        ])
        try await db.collection("users").document(userId).setData(["partnerCoupleId": coupleRef.documentID], merge: true)
        return Couple(id: coupleRef.documentID, memberIds: [userId], inviteCode: inviteCode, nextMeetDate: nil, anniversaryDate: nil, createdAt: now)
    }

    func joinCouple(inviteCode: String, userId: String) async throws {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let codeDoc = try await db.collection("inviteCodes").document(code).getDocument()
        guard let coupleId = codeDoc.data()?["coupleId"] as? String else {
            throw LongdyError.invalidInviteCode
        }

        let coupleRef = db.collection("couples").document(coupleId)
        let coupleDoc = try await coupleRef.getDocument()
        guard var memberIds = coupleDoc.data()?["memberIds"] as? [String] else {
            throw LongdyError.invalidInviteCode
        }
        if !memberIds.contains(userId) {
            guard memberIds.count < 2 else { throw LongdyError.coupleFull }
            memberIds.append(userId)
        }
        try await coupleRef.setData(["memberIds": memberIds], merge: true)
        try await db.collection("users").document(userId).setData(["partnerCoupleId": coupleId], merge: true)
    }

    func listenToUsers(userIds: [String], handler: @escaping ([LongdyUser]) -> Void) -> ListenerRegistration? {
        guard !userIds.isEmpty else {
            handler([])
            return nil
        }
        return db.collection("users")
            .whereField(FieldPath.documentID(), in: Array(userIds.prefix(10)))
            .addSnapshotListener { snapshot, _ in
                handler(snapshot?.documents.compactMap { Self.decodeUser(id: $0.documentID, data: $0.data()) } ?? [])
            }
    }

    func saveCheckIn(coupleId: String, userId: String, mood: Mood, fatigue: Int, missLevel: Int, status: LongdyStatus, canCall: CallIntent, note: String) async throws {
        let ref = db.collection("couples").document(coupleId).collection("checkIns").document()
        try await ref.setData([
            "userId": userId,
            "mood": mood.rawValue,
            "fatigue": fatigue,
            "missLevel": missLevel,
            "status": status.rawValue,
            "canCall": canCall.rawValue,
            "note": note,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func listenToCheckIns(coupleId: String, handler: @escaping ([CheckIn]) -> Void) -> ListenerRegistration {
        db.collection("couples").document(coupleId).collection("checkIns")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, _ in
                handler(snapshot?.documents.compactMap { Self.decodeCheckIn(id: $0.documentID, data: $0.data()) } ?? [])
            }
    }

    func saveAvailability(coupleId: String, userId: String, startAt: Date, endAt: Date, label: String) async throws {
        try await db.collection("couples").document(coupleId).collection("availabilities").document().setData([
            "userId": userId,
            "startAt": Timestamp(date: startAt),
            "endAt": Timestamp(date: endAt),
            "label": label,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func listenToAvailabilities(coupleId: String, handler: @escaping ([Availability]) -> Void) -> ListenerRegistration {
        db.collection("couples").document(coupleId).collection("availabilities")
            .order(by: "startAt", descending: false)
            .limit(to: 100)
            .addSnapshotListener { snapshot, _ in
                handler(snapshot?.documents.compactMap { Self.decodeAvailability(id: $0.documentID, data: $0.data()) } ?? [])
            }
    }

    func saveEvent(coupleId: String, ownerUserId: String, title: String, startAt: Date, endAt: Date, type: EventType, memo: String) async throws {
        let eventRef = db.collection("couples").document(coupleId).collection("events").document()
        try await eventRef.setData([
            "ownerUserId": ownerUserId,
            "title": title,
            "startAt": Timestamp(date: startAt),
            "endAt": Timestamp(date: endAt),
            "type": type.rawValue,
            "memo": memo
        ])
        if type == .meet {
            try await db.collection("couples").document(coupleId).setData(["nextMeetDate": Timestamp(date: startAt)], merge: true)
        }
    }

    func updateEvent(coupleId: String, eventId: String, title: String, startAt: Date, endAt: Date, type: EventType, memo: String) async throws {
        try await db.collection("couples").document(coupleId).collection("events").document(eventId).setData([
            "title": title,
            "startAt": Timestamp(date: startAt),
            "endAt": Timestamp(date: endAt),
            "type": type.rawValue,
            "memo": memo
        ], merge: true)
        if type == .meet {
            try await db.collection("couples").document(coupleId).setData(["nextMeetDate": Timestamp(date: startAt)], merge: true)
        }
    }

    func deleteEvent(coupleId: String, eventId: String) async throws {
        try await db.collection("couples").document(coupleId).collection("events").document(eventId).delete()
    }

    func listenToEvents(coupleId: String, handler: @escaping ([CoupleEvent]) -> Void) -> ListenerRegistration {
        db.collection("couples").document(coupleId).collection("events")
            .order(by: "startAt", descending: false)
            .limit(to: 100)
            .addSnapshotListener { snapshot, _ in
                handler(snapshot?.documents.compactMap { Self.decodeEvent(id: $0.documentID, data: $0.data()) } ?? [])
            }
    }

    func saveQuestionAnswer(coupleId: String, dateKey: String, question: String, userId: String, answer: String) async throws {
        let ref = db.collection("couples").document(coupleId).collection("questionAnswers").document(dateKey)
        try await ref.setData([
            "question": question,
            "answersByUserId.\(userId)": answer,
            "createdAt": Timestamp(date: Date())
        ], merge: true)
    }

    func listenToQuestionAnswer(coupleId: String, dateKey: String, handler: @escaping (QuestionAnswer?) -> Void) -> ListenerRegistration {
        db.collection("couples").document(coupleId).collection("questionAnswers").document(dateKey)
            .addSnapshotListener { snapshot, _ in
                handler(snapshot.flatMap { Self.decodeQuestionAnswer(id: dateKey, data: $0.data()) })
            }
    }

    func saveMemory(coupleId: String, userId: String, type: MemoryType, text: String, fileData: Data?, fileExtension: String?) async throws {
        var storageURL: String?
        if let fileData, let fileExtension {
            let ref = storage.reference().child("couples/\(coupleId)/memories/\(UUID().uuidString).\(fileExtension)")
            _ = try await ref.putDataAsync(fileData)
            storageURL = try await ref.downloadURL().absoluteString
        }
        try await db.collection("couples").document(coupleId).collection("memories").document().setData([
            "userId": userId,
            "type": type.rawValue,
            "text": text,
            "storageURL": storageURL as Any,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func listenToMemories(coupleId: String, handler: @escaping ([MemoryNote]) -> Void) -> ListenerRegistration {
        db.collection("couples").document(coupleId).collection("memories")
            .order(by: "createdAt", descending: true)
            .limit(to: 80)
            .addSnapshotListener { snapshot, _ in
                handler(snapshot?.documents.compactMap { Self.decodeMemory(id: $0.documentID, data: $0.data()) } ?? [])
            }
    }

    static func decodeUser(id: String, data: [String: Any]?) -> LongdyUser? {
        guard let data else { return nil }
        return LongdyUser(
            id: id,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            nickname: data["nickname"] as? String ?? "",
            timezoneId: data["timezoneId"] as? String ?? TimeZone.current.identifier,
            cityName: data["cityName"] as? String ?? "Seoul",
            partnerCoupleId: data["partnerCoupleId"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    static func decodeCouple(id: String, data: [String: Any]?) -> Couple? {
        guard let data else { return nil }
        return Couple(
            id: id,
            memberIds: data["memberIds"] as? [String] ?? [],
            inviteCode: data["inviteCode"] as? String ?? "",
            nextMeetDate: (data["nextMeetDate"] as? Timestamp)?.dateValue(),
            anniversaryDate: (data["anniversaryDate"] as? Timestamp)?.dateValue(),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    static func decodeCheckIn(id: String, data: [String: Any]) -> CheckIn? {
        guard let userId = data["userId"] as? String else { return nil }
        return CheckIn(
            id: id,
            userId: userId,
            mood: Mood(rawValue: data["mood"] as? String ?? "") ?? .calm,
            fatigue: data["fatigue"] as? Int ?? 3,
            missLevel: data["missLevel"] as? Int ?? 3,
            status: LongdyStatus(rawValue: data["status"] as? String ?? "") ?? .resting,
            canCall: CallIntent(rawValue: data["canCall"] as? String ?? "") ?? .later,
            note: data["note"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    static func decodeAvailability(id: String, data: [String: Any]) -> Availability? {
        guard let userId = data["userId"] as? String,
              let startAt = (data["startAt"] as? Timestamp)?.dateValue(),
              let endAt = (data["endAt"] as? Timestamp)?.dateValue() else { return nil }
        return Availability(id: id, userId: userId, startAt: startAt, endAt: endAt, label: data["label"] as? String ?? "통화 가능", createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
    }

    static func decodeEvent(id: String, data: [String: Any]) -> CoupleEvent? {
        guard let ownerUserId = data["ownerUserId"] as? String,
              let title = data["title"] as? String,
              let startAt = (data["startAt"] as? Timestamp)?.dateValue(),
              let endAt = (data["endAt"] as? Timestamp)?.dateValue() else { return nil }
        return CoupleEvent(id: id, ownerUserId: ownerUserId, title: title, startAt: startAt, endAt: endAt, type: EventType(rawValue: data["type"] as? String ?? "") ?? .mine, memo: data["memo"] as? String ?? "")
    }

    static func decodeQuestionAnswer(id: String, data: [String: Any]?) -> QuestionAnswer? {
        guard let data else { return nil }
        return QuestionAnswer(id: id, question: data["question"] as? String ?? QuestionBank.question(), answersByUserId: data["answersByUserId"] as? [String: String] ?? [:], createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
    }

    static func decodeMemory(id: String, data: [String: Any]) -> MemoryNote? {
        guard let userId = data["userId"] as? String else { return nil }
        return MemoryNote(id: id, userId: userId, type: MemoryType(rawValue: data["type"] as? String ?? "") ?? .text, text: data["text"] as? String ?? "", storageURL: data["storageURL"] as? String, createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
    }

    static func makeInviteCode() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
    }
}
