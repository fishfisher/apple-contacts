import ArgumentParser
import Contacts
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all contacts",
        discussion: """
            List contacts, optionally filtered by group.

            Examples:
              apple-contacts list
              apple-contacts list --limit 10
              apple-contacts list --group "Work"
            """
    )

    @Option(name: .long, help: "Filter by group name (case-insensitive)")
    var group: String?

    @Option(name: .long, help: "Filter by group ID (from `groups --json`)")
    var groupId: String?

    @Option(name: .shortAndLong, help: "Limit number of results")
    var limit: Int?

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    func run() throws {
        if let limit, limit < 1 { throw ValidationError("--limit must be at least 1") }
        try ContactsService.requireAccess()
        let service = ContactsService()

        var contacts: [CNContact]

        if group != nil || groupId != nil {
            contacts = try service.listContactsInGroup(service.getGroup(name: group, id: groupId))
            if let limit, contacts.count > limit {
                contacts = Array(contacts.prefix(limit))
            }
        } else {
            contacts = try service.listContacts(limit: limit)
        }

        if json {
            JSON.print(contacts.map(JSON.summary))
        } else {
            printTable(contacts)
        }
    }

    private func printTable(_ contacts: [CNContact]) {
        if contacts.isEmpty {
            print("No contacts found")
            return
        }

        // Calculate column widths
        let nameWidth = max(4, min(30, contacts.map { $0.fullName.count }.max() ?? 20))
        let orgWidth = max(12, min(25, contacts.map { $0.organizationName.count }.max() ?? 15))

        // Header
        print("\("NAME".padding(toLength: nameWidth, withPad: " ", startingAt: 0))  \("ORGANIZATION".padding(toLength: orgWidth, withPad: " ", startingAt: 0))  ID")

        // Rows
        for contact in contacts {
            let name = String(contact.fullName.prefix(nameWidth)).padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let org = (contact.organizationName.isEmpty ? "-" : String(contact.organizationName.prefix(orgWidth)))
                .padding(toLength: orgWidth, withPad: " ", startingAt: 0)

            print("\(name)  \(org)  \(contact.identifier)")
        }

        print("\nTotal: \(contacts.count) contact(s)")
    }
}
