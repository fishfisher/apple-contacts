import ArgumentParser
import Contacts
import Foundation

struct Groups: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List contact groups",
        discussion: """
            List all contact groups and their member counts.

            Examples:
              apple-contacts groups
              apple-contacts groups --json
            """
    )

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    func run() throws {
        try ContactsService.requireAccess()
        let service = ContactsService()

        let groups = try service.listGroups()

        if json {
            printJSON(groups, service: service)
        } else {
            printTable(groups, service: service)
        }
    }

    private func printTable(_ groups: [CNGroup], service: ContactsService) {
        if groups.isEmpty {
            print("No groups found")
            return
        }

        // Calculate column width
        let nameWidth = max(5, groups.map { $0.name.count }.max() ?? 20)

        // Header
        print("\("GROUP".padding(toLength: nameWidth, withPad: " ", startingAt: 0))  MEMBERS")

        // Rows
        for group in groups {
            let count = (try? service.listContactsInGroup(group).count) ?? 0
            print("\(group.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0))  \(count)")
        }

        print("\nTotal: \(groups.count) group(s)")
    }

    private func printJSON(_ groups: [CNGroup], service: ContactsService) {
        let data = groups.map { group -> [String: Any] in
            let count = (try? service.listContactsInGroup(group).count) ?? 0
            return [
                "id": group.identifier,
                "name": group.name,
                "memberCount": count,
            ]
        }

        JSON.print(data)
    }
}
