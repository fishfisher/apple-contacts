import ArgumentParser
import Contacts
import Foundation

/// Service for interacting with Apple Contacts framework
final class ContactsService {
    private let store = CNContactStore()

    /// Keys to fetch for basic contact info (fast)
    static var basicKeys: [CNKeyDescriptor] {
        [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        ]
    }

    /// Keys for search and list: enough to match every filter and to return
    /// phones and emails without a `show` per contact.
    static var summaryKeys: [CNKeyDescriptor] {
        basicKeys + [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
        ]
    }

    /// Keys to fetch for full contact info
    /// Note: CNContactNoteKey is excluded because it requires special entitlements
    static var fullKeys: [CNKeyDescriptor] {
        [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactDepartmentNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactDatesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactSocialProfilesKey as CNKeyDescriptor,
            CNContactInstantMessageAddressesKey as CNKeyDescriptor,
            CNContactRelationsKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        ]
    }

    /// Keys needed for vCard export
    static var vCardKeys: [CNKeyDescriptor] {
        [CNContactVCardSerialization.descriptorForRequiredKeys()]
    }

    init() {}

    // MARK: - Access

    /// Exit code for missing Contacts access, so wrappers can tell it apart
    /// from "not found" (1) and usage errors (64).
    static let accessDeniedExitCode: Int32 = 77

    /// Ensures Contacts access, asking once when it was never requested.
    /// Every command calls this first.
    static func requireAccess() throws {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return
        case .notDetermined:
            if requestAccess(timeout: 60) { return }
        default:
            break
        }
        FileHandle.standardError.write(Data("Error: \(ContactsError.accessDenied.description)\n".utf8))
        throw ExitCode(accessDeniedExitCode)
    }

    /// Shows the system prompt and waits for the answer (or the timeout,
    /// when no prompt can be shown, e.g. from a headless session).
    static func requestAccess(timeout: TimeInterval) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var granted = false
        CNContactStore().requestAccess(for: .contacts) { success, _ in
            granted = success
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut { return false }
        return granted
    }

    // MARK: - Search

    /// All contacts matching every given criterion (AND), in the user's sort order.
    /// One pass over the address book, whatever the number of filters.
    func search(_ criteria: SearchCriteria) throws -> [CNContact] {
        var results: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: Self.summaryKeys)
        request.sortOrder = .userDefault
        try store.enumerateContacts(with: request) { contact, _ in
            if criteria.matches(contact) {
                results.append(contact)
            }
        }
        return results
    }

    // MARK: - Get Operations

    /// Get a contact by identifier
    func getContact(id: String) throws -> CNContact? {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [id])
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: Self.fullKeys)
        return contacts.first
    }

    /// Get the one contact a name refers to. An exact full-name match wins;
    /// otherwise the name must match exactly one contact, or this throws
    /// `ambiguous` with the candidates so nobody acts on the wrong person.
    func getContact(name: String) throws -> CNContact {
        let candidates = try search(SearchCriteria(term: name))
        let wanted = Match.fold(name)
        let exact = candidates.filter { Match.fold($0.fullName) == wanted }

        let chosen: CNContact
        if exact.count == 1 {
            chosen = exact[0]
        } else if candidates.count == 1 {
            chosen = candidates[0]
        } else if candidates.isEmpty {
            throw ContactsError.contactNotFound
        } else {
            throw ContactsError.ambiguous((exact.isEmpty ? candidates : exact).map { c in
                let org = c.organizationName.isEmpty ? "" : " (\(c.organizationName))"
                return "\(c.fullName)\(org)  --id \(c.identifier)"
            })
        }

        guard let full = try getContact(id: chosen.identifier) else {
            throw ContactsError.contactNotFound
        }
        return full
    }

    // MARK: - List Operations

    /// List all contacts
    func listContacts(limit: Int? = nil) throws -> [CNContact] {
        var results: [CNContact] = []

        let request = CNContactFetchRequest(keysToFetch: Self.summaryKeys)
        request.sortOrder = .userDefault

        try store.enumerateContacts(with: request) { contact, stop in
            if let limit, results.count >= limit {
                stop.pointee = true
                return
            }
            results.append(contact)
        }

        return results
    }

    /// List all groups
    func listGroups() throws -> [CNGroup] {
        try store.groups(matching: nil)
    }

    /// List contacts in a group
    func listContactsInGroup(_ group: CNGroup) throws -> [CNContact] {
        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
        return try store.unifiedContacts(matching: predicate, keysToFetch: Self.summaryKeys)
            .sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }

    /// Get a group by name (case-insensitive) or identifier
    func getGroup(name: String?, id: String?) throws -> CNGroup {
        let groups = try listGroups()
        if let id {
            guard let group = groups.first(where: { $0.identifier == id }) else { throw ContactsError.groupNotFound }
            return group
        }
        let matches = groups.filter { $0.name.compare(name ?? "", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        if matches.count > 1 {
            throw ContactsError.ambiguousGroup(matches.map { "\($0.name)  \($0.identifier)" })
        }
        guard let group = matches.first else { throw ContactsError.groupNotFound }
        return group
    }

    // MARK: - Export Operations

    /// Export contact as vCard data
    func exportVCard(contact: CNContact) throws -> Data {
        // Refetch with vCard keys
        let predicate = CNContact.predicateForContacts(withIdentifiers: [contact.identifier])
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: Self.vCardKeys)
        guard let fullContact = contacts.first else {
            throw ContactsError.contactNotFound
        }
        return try CNContactVCardSerialization.data(with: [fullContact])
    }

    /// Export contact as vCard string
    func exportVCardString(contact: CNContact) throws -> String {
        let data = try exportVCard(contact: contact)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ContactsError.exportFailed
        }
        return string
    }
}

// MARK: - Search criteria

struct SearchCriteria {
    var term: String?
    var email: String?
    var phone: String?
    var org: String?
    var address: String?
    var any: String?
    var birthday: BirthdayFilter?
    var birthdayMonth: Int?

    var isEmpty: Bool {
        term == nil && email == nil && phone == nil && org == nil && address == nil && any == nil
            && birthday == nil && birthdayMonth == nil
    }

    func matches(_ c: CNContact) -> Bool {
        if let term, !Match.name(c, term) { return false }
        if let email, !Match.email(c, email) { return false }
        if let phone, !Match.phone(c, phone) { return false }
        if let org, !Match.text(c.organizationName, org) { return false }
        if let address, !Match.address(c, address) { return false }
        if let any, !Match.any(c, any) { return false }
        if let birthday, !birthday.matches(c.birthday) { return false }
        if let birthdayMonth, c.birthday?.month != birthdayMonth { return false }
        return true
    }
}

struct BirthdayFilter {
    let month: Int
    let day: Int
    let year: Int?

    /// Accepts MM-DD, M-D, MM/DD, DD.MM, --MM-DD and YYYY-MM-DD.
    init(parsing input: String) throws {
        let s = input.trimmingCharacters(in: .whitespaces)
        var year: Int?
        var month: Int?
        var day: Int?
        let dash = s.hasPrefix("--") ? String(s.dropFirst(2)) : s
        if dash.contains(".") {
            let p = dash.split(separator: ".")
            if p.count == 2 { day = Int(p[0]); month = Int(p[1]) }
        } else {
            let p = dash.split(whereSeparator: { $0 == "-" || $0 == "/" })
            if p.count == 3, p[0].count == 4 { year = Int(p[0]); month = Int(p[1]); day = Int(p[2]) }
            else if p.count == 2 { month = Int(p[0]); day = Int(p[1]) }
        }
        guard let month, let day, (1...12).contains(month), (1...31).contains(day) else {
            throw ValidationError("Invalid --birthday \"\(input)\". Use MM-DD (e.g. 01-25), DD.MM or YYYY-MM-DD.")
        }
        self.month = month
        self.day = day
        self.year = year
    }

    func matches(_ birthday: DateComponents?) -> Bool {
        guard let birthday, birthday.month == month, birthday.day == day else { return false }
        if let year, let theirs = birthday.year { return theirs == year }
        return true
    }
}

/// Text matching that ignores case and accents and treats the ASCII
/// spellings of æ/ø/å ("ae", "o"/"oe", "a"/"aa") as equal to the letters.
enum Match {
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "ø", with: "o")
            .replacingOccurrences(of: "oe", with: "o")
            .replacingOccurrences(of: "aa", with: "a")
    }

    static func text(_ haystack: String, _ needle: String) -> Bool {
        !haystack.isEmpty && fold(haystack).contains(fold(needle))
    }

    static func name(_ c: CNContact, _ q: String) -> Bool {
        let names = [
            c.fullName,
            "\(c.givenName) \(c.familyName)",
            "\(c.familyName) \(c.givenName)",
            "\(c.givenName) \(c.middleName) \(c.familyName)",
            c.nickname,
        ]
        return names.contains { text($0, q) }
    }

    static func email(_ c: CNContact, _ q: String) -> Bool {
        c.emailAddresses.contains { text($0.value as String, q) }
    }

    static func address(_ c: CNContact, _ q: String) -> Bool {
        c.postalAddresses.contains {
            text(CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress), q)
        }
    }

    /// Digits only, with an international "00" prefix dropped.
    static func digits(_ s: String) -> String {
        var d = s.filter(\.isASCII).filter(\.isNumber)
        if d.hasPrefix("00") { d.removeFirst(2) }
        return d
    }

    /// Matches regardless of spaces, "+47"/"0047" prefixes or their absence:
    /// with 8+ digits the last 8 must match (a Norwegian number, or the
    /// subscriber part of most others); shorter queries match anywhere.
    static func phone(_ c: CNContact, _ q: String) -> Bool {
        let query = digits(q)
        guard !query.isEmpty else { return false }
        return c.phoneNumbers.contains { labeled in
            let stored = digits(labeled.value.stringValue)
            if query.count >= 8, stored.count >= 8 {
                return stored.hasSuffix(String(query.suffix(8)))
            }
            return stored.contains(query)
        }
    }

    static func any(_ c: CNContact, _ q: String) -> Bool {
        if name(c, q) || text(c.organizationName, q) || email(c, q) || address(c, q) { return true }
        // Only treat the query as a phone number when it mostly is one.
        let digitCount = q.filter(\.isNumber).count
        return digitCount >= 3 && digitCount * 2 >= q.filter { !$0.isWhitespace }.count && phone(c, q)
    }
}

// MARK: - Errors

enum ContactsError: Error, CustomStringConvertible {
    case accessDenied
    case contactNotFound
    case groupNotFound
    case exportFailed
    case ambiguous([String])
    case ambiguousGroup([String])

    var description: String {
        switch self {
        case .accessDenied:
            return "Access to Contacts denied. Grant it in System Settings > Privacy & Security > Contacts, or run `apple-contacts permissions`."
        case .contactNotFound:
            return "Contact not found"
        case .groupNotFound:
            return "Group not found"
        case .exportFailed:
            return "Failed to export contact"
        case .ambiguous(let lines):
            return "\(lines.count) contacts match; pick one with --id:\n"
                + lines.prefix(20).map { "  " + $0 }.joined(separator: "\n")
        case .ambiguousGroup(let lines):
            return "Several groups match; use --group-id with one of:\n"
                + lines.map { "  " + $0 }.joined(separator: "\n")
        }
    }
}

// MARK: - JSON

enum JSON {
    /// Pretty JSON with stable key order.
    static func print(_ object: Any) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
            let string = String(data: data, encoding: .utf8)
        else { return }
        Swift.print(string)
    }

    /// Fields shared by search and list rows.
    static func summary(_ c: CNContact) -> [String: Any] {
        var row: [String: Any] = [
            "id": c.identifier,
            "name": c.fullName,
            "firstName": c.givenName,
            "lastName": c.familyName,
            "nickname": c.nickname,
            "organization": c.organizationName,
        ]
        if c.isKeyAvailable(CNContactPhoneNumbersKey) {
            row["phones"] = c.phoneNumbers.map { $0.value.stringValue }
        }
        if c.isKeyAvailable(CNContactEmailAddressesKey) {
            row["emails"] = c.emailAddresses.map { $0.value as String }
        }
        if c.isKeyAvailable(CNContactBirthdayKey), let birthday = c.birthdayString {
            row["birthday"] = birthday
        }
        return row
    }
}

// MARK: - CNContact Extensions

extension CNContact {
    /// Full name using formatter
    var fullName: String {
        CNContactFormatter.string(from: self, style: .fullName)
            ?? "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
    }

    /// Birthday as YYYY-MM-DD, or --MM-DD when the year is unknown
    var birthdayString: String? {
        guard let birthday, let month = birthday.month, let day = birthday.day else { return nil }
        let year = birthday.year.map { String(format: "%04d", $0) } ?? "-"
        return "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }

    /// First phone number
    var firstPhone: String? {
        phoneNumbers.first?.value.stringValue
    }

    /// First email
    var firstEmail: String? {
        emailAddresses.first?.value as String?
    }
}
