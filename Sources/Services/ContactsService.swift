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
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
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

    /// Request access to contacts
    func requestAccess() async throws -> Bool {
        try await store.requestAccess(for: .contacts)
    }

    /// Check authorization status
    var isAuthorized: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    /// Ensure we have access, throw if not
    func ensureAccess() throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return
        case .notDetermined:
            // For CLI, we can't easily request access synchronously
            // User needs to grant permission via System Settings
            throw ContactsError.accessDenied
        case .denied, .restricted:
            throw ContactsError.accessDenied
        @unknown default:
            throw ContactsError.accessDenied
        }
    }

    // MARK: - Search Operations

    /// Search contacts by name or nickname (fast - uses predicate for name)
    func searchByName(_ query: String) throws -> [CNContact] {
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let byName = try store.unifiedContacts(matching: predicate, keysToFetch: Self.basicKeys)

        // Also search by nickname (no built-in predicate, so fetch and filter)
        let nicknameMatches = try searchByNickname(query)

        // Merge and deduplicate
        var seen = Set<String>()
        var results: [CNContact] = []

        for contact in byName {
            if !seen.contains(contact.identifier) {
                seen.insert(contact.identifier)
                results.append(contact)
            }
        }

        for contact in nicknameMatches {
            if !seen.contains(contact.identifier) {
                seen.insert(contact.identifier)
                results.append(contact)
            }
        }

        return results
    }

    /// Search contacts by nickname
    private func searchByNickname(_ query: String) throws -> [CNContact] {
        let queryLower = query.lowercased()
        var results: [CNContact] = []

        let request = CNContactFetchRequest(keysToFetch: Self.basicKeys)
        try store.enumerateContacts(with: request) { contact, _ in
            if contact.nickname.lowercased().contains(queryLower) {
                results.append(contact)
            }
        }

        return results
    }

    /// Search contacts by email
    func searchByEmail(_ query: String) throws -> [CNContact] {
        // Try predicate match first (exact email)
        let predicate = CNContact.predicateForContacts(matchingEmailAddress: query)
        if let contacts = try? store.unifiedContacts(matching: predicate, keysToFetch: Self.basicKeys),
           !contacts.isEmpty
        {
            return contacts
        }

        // Fall back to contains search
        let queryLower = query.lowercased()
        var results: [CNContact] = []

        let keys = Self.basicKeys + [CNContactEmailAddressesKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        try store.enumerateContacts(with: request) { contact, _ in
            for email in contact.emailAddresses {
                if (email.value as String).lowercased().contains(queryLower) {
                    results.append(contact)
                    break
                }
            }
        }

        return results
    }

    /// Search contacts by phone number
    func searchByPhone(_ query: String) throws -> [CNContact] {
        // Normalize query - keep only digits and +
        let normalizedQuery = query.filter { $0.isNumber || $0 == "+" }

        // Try predicate match first
        let phoneNumber = CNPhoneNumber(stringValue: query)
        let predicate = CNContact.predicateForContacts(matching: phoneNumber)
        if let contacts = try? store.unifiedContacts(matching: predicate, keysToFetch: Self.basicKeys),
           !contacts.isEmpty
        {
            return contacts
        }

        // Fall back to contains search
        var results: [CNContact] = []

        let keys = Self.basicKeys + [CNContactPhoneNumbersKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        try store.enumerateContacts(with: request) { contact, _ in
            for phone in contact.phoneNumbers {
                let phoneDigits = phone.value.stringValue.filter { $0.isNumber || $0 == "+" }
                if phoneDigits.contains(normalizedQuery) {
                    results.append(contact)
                    break
                }
            }
        }

        return results
    }

    /// Search contacts by organization
    func searchByOrganization(_ query: String) throws -> [CNContact] {
        let queryLower = query.lowercased()
        var results: [CNContact] = []

        let request = CNContactFetchRequest(keysToFetch: Self.basicKeys)
        try store.enumerateContacts(with: request) { contact, _ in
            if contact.organizationName.lowercased().contains(queryLower) {
                results.append(contact)
            }
        }

        return results
    }

    /// Search contacts by address
    func searchByAddress(_ query: String) throws -> [CNContact] {
        let queryLower = query.lowercased()
        var results: [CNContact] = []

        let keys = Self.basicKeys + [CNContactPostalAddressesKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        try store.enumerateContacts(with: request) { contact, _ in
            for address in contact.postalAddresses {
                let formatted = CNPostalAddressFormatter.string(from: address.value, style: .mailingAddress)
                if formatted.lowercased().contains(queryLower) {
                    results.append(contact)
                    break
                }
            }
        }

        return results
    }

    /// Search contacts by birthday
    func searchByBirthday(month: Int?, day: Int?) throws -> [CNContact] {
        var results: [CNContact] = []

        let keys = Self.basicKeys + [CNContactBirthdayKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        try store.enumerateContacts(with: request) { contact, _ in
            guard let birthday = contact.birthday else { return }

            var matches = true
            if let m = month, birthday.month != m {
                matches = false
            }
            if let d = day, birthday.day != d {
                matches = false
            }

            if matches && (month != nil || day != nil) {
                results.append(contact)
            }
        }

        return results
    }

    /// Search across all fields
    func searchAll(_ query: String) throws -> [CNContact] {
        let queryLower = query.lowercased()
        var seen = Set<String>()
        var results: [CNContact] = []

        // First do fast name search
        let byName = try searchByName(query)
        for contact in byName {
            if !seen.contains(contact.identifier) {
                seen.insert(contact.identifier)
                results.append(contact)
            }
        }

        // Then search other fields
        let keys: [CNKeyDescriptor] = Self.basicKeys + [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        try store.enumerateContacts(with: request) { contact, _ in
            if seen.contains(contact.identifier) { return }

            // Check organization
            if contact.organizationName.lowercased().contains(queryLower) {
                seen.insert(contact.identifier)
                results.append(contact)
                return
            }

            // Check emails
            for email in contact.emailAddresses {
                if (email.value as String).lowercased().contains(queryLower) {
                    seen.insert(contact.identifier)
                    results.append(contact)
                    return
                }
            }

            // Check phones
            for phone in contact.phoneNumbers {
                if phone.value.stringValue.contains(query) {
                    seen.insert(contact.identifier)
                    results.append(contact)
                    return
                }
            }

            // Check addresses
            for address in contact.postalAddresses {
                let formatted = CNPostalAddressFormatter.string(from: address.value, style: .mailingAddress)
                if formatted.lowercased().contains(queryLower) {
                    seen.insert(contact.identifier)
                    results.append(contact)
                    return
                }
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

    /// Get a contact by name (returns first match, prefers exact)
    func getContact(name: String) throws -> CNContact? {
        let predicate = CNContact.predicateForContacts(matchingName: name)
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: Self.fullKeys)

        // Prefer exact match
        let nameLower = name.lowercased()
        for contact in contacts {
            let fullName = contact.fullName.lowercased()
            if fullName == nameLower {
                return contact
            }
        }

        return contacts.first
    }

    // MARK: - List Operations

    /// List all contacts
    func listContacts(limit: Int? = nil) throws -> [CNContact] {
        var results: [CNContact] = []

        let request = CNContactFetchRequest(keysToFetch: Self.basicKeys)
        request.sortOrder = .userDefault

        try store.enumerateContacts(with: request) { contact, stop in
            results.append(contact)
            if let limit, results.count >= limit {
                stop.pointee = true
            }
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
        return try store.unifiedContacts(matching: predicate, keysToFetch: Self.basicKeys)
    }

    /// Get group by name
    func getGroup(name: String) throws -> CNGroup? {
        let groups = try listGroups()
        return groups.first { $0.name == name }
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

// MARK: - Errors

enum ContactsError: Error, CustomStringConvertible {
    case accessDenied
    case contactNotFound
    case groupNotFound
    case exportFailed

    var description: String {
        switch self {
        case .accessDenied:
            return "Access to Contacts denied. Please grant access in System Settings > Privacy & Security > Contacts."
        case .contactNotFound:
            return "Contact not found"
        case .groupNotFound:
            return "Group not found"
        case .exportFailed:
            return "Failed to export contact"
        }
    }
}

// MARK: - CNContact Extensions

extension CNContact {
    /// Full name using formatter
    var fullName: String {
        CNContactFormatter.string(from: self, style: .fullName)
            ?? "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
    }

    /// Birthday as string (YYYY-MM-DD or --MM-DD if no year)
    var birthdayString: String? {
        guard let birthday else { return nil }
        var components: [String] = []
        if let year = birthday.year {
            components.append(String(format: "%04d", year))
        } else {
            components.append("----")
        }
        if let month = birthday.month {
            components.append(String(format: "%02d", month))
        }
        if let day = birthday.day {
            components.append(String(format: "%02d", day))
        }
        return components.joined(separator: "-")
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
