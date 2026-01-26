import ArgumentParser
import Contacts
import Foundation

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Search contacts by name or other criteria",
        discussion: """
            Search for contacts using various criteria.
            Without flags, searches by name/nickname (fast).
            Multiple flags are combined with AND logic.

            Examples:
              apple-contacts search fisher
              apple-contacts search --email "@company.com"
              apple-contacts search --phone "+47"
              apple-contacts search --org "Acme"
              apple-contacts search --birthday 01-25
              apple-contacts search --birthday-month 1
            """
    )

    @Argument(help: "Search term (searches name and nickname)")
    var term: String?

    @Option(name: .long, help: "Search by email (contains)")
    var email: String?

    @Option(name: .long, help: "Search by phone number (contains)")
    var phone: String?

    @Option(name: .long, help: "Search by organization (contains)")
    var org: String?

    @Option(name: .long, help: "Search in addresses (contains)")
    var address: String?

    @Option(name: .long, help: "Search by birthday (MM-DD format)")
    var birthday: String?

    @Option(name: .long, help: "Search by birthday month (1-12)")
    var birthdayMonth: Int?

    @Option(name: .long, help: "Search across all fields")
    var any: String?

    @Option(name: .shortAndLong, help: "Limit number of results")
    var limit: Int?

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    func run() throws {
        let service = ContactsService()

        // Check access synchronously for CLI
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .denied || status == .restricted {
            throw ContactsError.accessDenied
        }

        var results: [CNContact] = []

        // Determine search type and execute
        if let any = any {
            results = try service.searchAll(any)
        } else if let term = term {
            // Name search (includes nickname)
            var nameResults = try service.searchByName(term)

            // Apply additional filters if provided
            nameResults = try applyFilters(to: nameResults, service: service)
            results = nameResults
        } else if email != nil || phone != nil || org != nil ||
                    address != nil || birthday != nil || birthdayMonth != nil
        {
            // Start with all contacts and filter
            results = try service.listContacts()
            results = try applyFilters(to: results, service: service)
        } else {
            throw ValidationError("Please provide a search term or use search flags (--email, --org, etc.)")
        }

        // Apply limit
        if let limit = limit, results.count > limit {
            results = Array(results.prefix(limit))
        }

        // Output
        if json {
            printJSON(results)
        } else {
            printTable(results)
        }
    }

    private func applyFilters(to contacts: [CNContact], service: ContactsService) throws -> [CNContact] {
        var filtered = contacts

        if let email = email {
            let emailMatches = Set(try service.searchByEmail(email).map(\.identifier))
            filtered = filtered.filter { emailMatches.contains($0.identifier) }
        }

        if let phone = phone {
            let phoneMatches = Set(try service.searchByPhone(phone).map(\.identifier))
            filtered = filtered.filter { phoneMatches.contains($0.identifier) }
        }

        if let org = org {
            let orgMatches = Set(try service.searchByOrganization(org).map(\.identifier))
            filtered = filtered.filter { orgMatches.contains($0.identifier) }
        }

        if let address = address {
            let addrMatches = Set(try service.searchByAddress(address).map(\.identifier))
            filtered = filtered.filter { addrMatches.contains($0.identifier) }
        }

        if let birthday = birthday {
            // Parse MM-DD format
            let parts = birthday.split(separator: "-")
            if parts.count == 2, let month = Int(parts[0]), let day = Int(parts[1]) {
                let bdayMatches = Set(try service.searchByBirthday(month: month, day: day).map(\.identifier))
                filtered = filtered.filter { bdayMatches.contains($0.identifier) }
            }
        }

        if let birthdayMonth = birthdayMonth {
            let bdayMatches = Set(try service.searchByBirthday(month: birthdayMonth, day: nil).map(\.identifier))
            filtered = filtered.filter { bdayMatches.contains($0.identifier) }
        }

        return filtered
    }

    private func printTable(_ contacts: [CNContact]) {
        if contacts.isEmpty {
            print("No contacts found")
            return
        }

        // Calculate column widths
        let nameWidth = max(4, contacts.map { $0.fullName.count }.max() ?? 20)
        let nickWidth = max(8, contacts.map { $0.nickname.count }.max() ?? 10)
        let orgWidth = max(12, contacts.map { $0.organizationName.count }.max() ?? 15)

        // Header
        print("\("NAME".padding(toLength: nameWidth, withPad: " ", startingAt: 0))  \("NICKNAME".padding(toLength: nickWidth, withPad: " ", startingAt: 0))  \("ORGANIZATION".padding(toLength: orgWidth, withPad: " ", startingAt: 0))  ID")

        // Rows
        for contact in contacts {
            let name = contact.fullName.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let nick = (contact.nickname.isEmpty ? "-" : contact.nickname).padding(toLength: nickWidth, withPad: " ", startingAt: 0)
            let org = (contact.organizationName.isEmpty ? "-" : contact.organizationName).padding(toLength: orgWidth, withPad: " ", startingAt: 0)
            let shortId = String(contact.identifier.prefix(20)) + "..."

            print("\(name)  \(nick)  \(org)  \(shortId)")
        }

        print("\nFound \(contacts.count) contact(s)")
    }

    private func printJSON(_ contacts: [CNContact]) {
        let data = contacts.map { contact -> [String: Any] in
            [
                "id": contact.identifier,
                "name": contact.fullName,
                "firstName": contact.givenName,
                "lastName": contact.familyName,
                "nickname": contact.nickname,
                "organization": contact.organizationName,
            ]
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            print(jsonString)
        }
    }
}
