import ArgumentParser
import Foundation

@main
struct AppleContacts: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apple-contacts",
        abstract: "CLI tool to search and query Apple Contacts",
        version: "0.3.0",
        subcommands: [
            Search.self,
            Show.self,
            List.self,
            Groups.self,
            Export.self,
            Permissions.self,
        ],
        defaultSubcommand: nil
    )
}
