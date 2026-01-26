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

    @Option(name: .long, help: "Filter by group name")
    var group: String?

    @Option(name: .shortAndLong, help: "Limit number of results")
    var limit: Int?

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    func run() throws {
        let service = ContactsService()

        // Check access
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .denied || status == .restricted {
            throw ContactsError.accessDenied
        }

        var contacts: [CNContact]

        if let groupName = group {
            guard let group = try service.getGroup(name: groupName) else {
                throw ContactsError.groupNotFound
            }
            contacts = try service.listContactsInGroup(group)
        } else {
            contacts = try service.listContacts(limit: limit)
        }

        // Apply limit if group was specified (listContacts already handles limit)
        if group != nil, let limit = limit, contacts.count > limit {
            contacts = Array(contacts.prefix(limit))
        }

        if json {
            printJSON(contacts)
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
            let shortId = String(contact.identifier.prefix(20)) + "..."

            print("\(name)  \(org)  \(shortId)")
        }

        print("\nTotal: \(contacts.count) contact(s)")
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
