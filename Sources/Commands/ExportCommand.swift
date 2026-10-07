import ArgumentParser
import Contacts
import Foundation

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Export contact as vCard",
        discussion: """
            Export a contact in vCard format.
            Output goes to stdout by default, or to a file with --output.

            Examples:
              apple-contacts export "John Doe"
              apple-contacts export --id ABC123... --output john.vcf
            """
    )

    @Argument(help: "Contact name to export")
    var name: String?

    @Option(name: .long, help: "Contact ID (use if name is ambiguous)")
    var id: String?

    @Option(name: .shortAndLong, help: "Output file path (default: stdout)")
    var output: String?

    func run() throws {
        guard id != nil || name != nil else {
            throw ValidationError("Please provide a contact name or --id")
        }
        try ContactsService.requireAccess()
        let service = ContactsService()
        let contact = try resolveContact(name: name, id: id)

        let vcard = try service.exportVCardString(contact: contact)

        if let outputPath = output {
            // Write to file
            let url = URL(fileURLWithPath: outputPath)
            try vcard.write(to: url, atomically: true, encoding: .utf8)
            print("Exported to \(outputPath)")
        } else {
            // Write to stdout (the vCard already ends with a line break)
            print(vcard, terminator: "")
        }
    }
}
