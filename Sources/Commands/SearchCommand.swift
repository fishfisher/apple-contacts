import ArgumentParser
import Contacts
import Foundation

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Search contacts by name or other criteria",
        discussion: """
            Search for contacts using various criteria.
            The term matches anywhere in the name or nickname, ignoring case
            and accents (ø/æ/å also match o/ae/a). Flags narrow the result;
            all criteria, including --any, must match.
            Phone numbers match with or without spaces and +47/0047.

            Examples:
              apple-contacts search fisher
              apple-contacts search --email "@company.com"
              apple-contacts search --phone "+47"
              apple-contacts search --org "Acme"
              apple-contacts search --phone "900 00 000"
              apple-contacts search --birthday 01-25
              apple-contacts search --birthday-month 1
            """
    )

    @Argument(help: "Search term (searches name and nickname)")
    var term: String?

    @Option(name: .long, help: "Search by email (contains)")
    var email: String?

    @Option(name: .long, help: "Search by phone number (ignores spaces and country code)")
    var phone: String?

    @Option(name: .long, help: "Search by organization (contains)")
    var org: String?

    @Option(name: .long, help: "Search in addresses (contains)")
    var address: String?

    @Option(name: .long, help: "Search by birthday (MM-DD, DD.MM or YYYY-MM-DD)")
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
        if let limit, limit < 1 { throw ValidationError("--limit must be at least 1") }
        if let birthdayMonth, !(1...12).contains(birthdayMonth) {
            throw ValidationError("--birthday-month must be 1-12")
        }

        let criteria = SearchCriteria(
            term: term, email: email, phone: phone, org: org, address: address, any: any,
            birthday: try birthday.map { try BirthdayFilter(parsing: $0) },
            birthdayMonth: birthdayMonth
        )
        if criteria.isEmpty {
            throw ValidationError("Please provide a search term or use search flags (--email, --org, etc.)")
        }

        try ContactsService.requireAccess()
        var results = try ContactsService().search(criteria)

        if let limit, results.count > limit {
            results = Array(results.prefix(limit))
        }

        if json {
            JSON.print(results.map(JSON.summary))
        } else {
            printTable(results)
        }
    }

    private func printTable(_ contacts: [CNContact]) {
        if contacts.isEmpty {
            print("No contacts found")
            return
        }

        // Calculate column widths
        let nameWidth = max(4, contacts.map { $0.fullName.count }.max() ?? 20)
        let nickWidth = max(8, contacts.map { $0.nickname.count }.max() ?? 10)

        // Header
        print("\("NAME".padding(toLength: nameWidth, withPad: " ", startingAt: 0))  \("NICKNAME".padding(toLength: nickWidth, withPad: " ", startingAt: 0))  ID")

        // Rows
        for contact in contacts {
            let name = contact.fullName.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let nick = (contact.nickname.isEmpty ? "-" : contact.nickname).padding(toLength: nickWidth, withPad: " ", startingAt: 0)

            print("\(name)  \(nick)  \(contact.identifier)")
        }

        print("\nFound \(contacts.count) contact(s)")
    }
}
