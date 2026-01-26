import ArgumentParser
import Contacts
import Foundation

struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show full details for a contact",
        discussion: """
            Display all available information for a specific contact.
            You can identify the contact by name or ID.

            Examples:
              apple-contacts show "John Doe"
              apple-contacts show --id ABC123...
            """
    )

    @Argument(help: "Contact name to look up")
    var name: String?

    @Option(name: .long, help: "Contact ID (use if name is ambiguous)")
    var id: String?

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    func run() throws {
        let service = ContactsService()

        // Check access
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .denied || status == .restricted {
            throw ContactsError.accessDenied
        }

        var contact: CNContact?

        if let id = id {
            contact = try service.getContact(id: id)
        } else if let name = name {
            contact = try service.getContact(name: name)
        } else {
            throw ValidationError("Please provide a contact name or --id")
        }

        guard let contact else {
            throw ContactsError.contactNotFound
        }

        if json {
            printJSON(contact)
        } else {
            printDetails(contact)
        }
    }

    private func printDetails(_ contact: CNContact) {
        // Basic info
        print("Name:         \(contact.fullName)")

        if !contact.nickname.isEmpty {
            print("Nickname:     \(contact.nickname)")
        }

        if !contact.organizationName.isEmpty {
            print("Organization: \(contact.organizationName)")
        }

        if !contact.departmentName.isEmpty {
            print("Department:   \(contact.departmentName)")
        }

        if !contact.jobTitle.isEmpty {
            print("Job Title:    \(contact.jobTitle)")
        }

        if let birthday = contact.birthdayString {
            print("Birthday:     \(birthday)")
        }

        // Phone numbers
        if !contact.phoneNumbers.isEmpty {
            print("\nPHONES:")
            for phone in contact.phoneNumbers {
                let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? "other")
                print("  \(label.padding(toLength: 12, withPad: " ", startingAt: 0)) \(phone.value.stringValue)")
            }
        }

        // Email addresses
        if !contact.emailAddresses.isEmpty {
            print("\nEMAILS:")
            for email in contact.emailAddresses {
                let label = CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "other")
                print("  \(label.padding(toLength: 12, withPad: " ", startingAt: 0)) \(email.value)")
            }
        }

        // Postal addresses
        if !contact.postalAddresses.isEmpty {
            print("\nADDRESSES:")
            for address in contact.postalAddresses {
                let label = CNLabeledValue<CNPostalAddress>.localizedString(forLabel: address.label ?? "other")
                let formatted = CNPostalAddressFormatter.string(from: address.value, style: .mailingAddress)
                    .replacingOccurrences(of: "\n", with: ", ")
                print("  \(label.padding(toLength: 12, withPad: " ", startingAt: 0)) \(formatted)")
            }
        }

        // URLs
        if !contact.urlAddresses.isEmpty {
            print("\nURLS:")
            for url in contact.urlAddresses {
                let label = CNLabeledValue<NSString>.localizedString(forLabel: url.label ?? "other")
                print("  \(label.padding(toLength: 12, withPad: " ", startingAt: 0)) \(url.value)")
            }
        }

        // Social profiles
        if !contact.socialProfiles.isEmpty {
            print("\nSOCIAL:")
            for profile in contact.socialProfiles {
                let service = profile.value.service
                let username = profile.value.username
                print("  \(service.padding(toLength: 12, withPad: " ", startingAt: 0)) \(username)")
            }
        }

        // Relations
        if !contact.contactRelations.isEmpty {
            print("\nRELATIONS:")
            for relation in contact.contactRelations {
                let label = CNLabeledValue<CNContactRelation>.localizedString(forLabel: relation.label ?? "other")
                print("  \(label.padding(toLength: 12, withPad: " ", startingAt: 0)) \(relation.value.name)")
            }
        }

        // ID
        print("\nID: \(contact.identifier)")
    }

    private func printJSON(_ contact: CNContact) {
        var data: [String: Any] = [
            "id": contact.identifier,
            "name": contact.fullName,
            "firstName": contact.givenName,
            "lastName": contact.familyName,
            "middleName": contact.middleName,
            "nickname": contact.nickname,
            "organization": contact.organizationName,
            "department": contact.departmentName,
            "jobTitle": contact.jobTitle,
        ]

        if let birthday = contact.birthdayString {
            data["birthday"] = birthday
        }

        data["phones"] = contact.phoneNumbers.map { phone -> [String: String] in
            [
                "label": CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? "other"),
                "value": phone.value.stringValue,
            ]
        }

        data["emails"] = contact.emailAddresses.map { email -> [String: String] in
            [
                "label": CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "other"),
                "value": email.value as String,
            ]
        }

        data["addresses"] = contact.postalAddresses.map { address -> [String: String] in
            [
                "label": CNLabeledValue<CNPostalAddress>.localizedString(forLabel: address.label ?? "other"),
                "value": CNPostalAddressFormatter.string(from: address.value, style: .mailingAddress),
            ]
        }

        data["urls"] = contact.urlAddresses.map { url -> [String: String] in
            [
                "label": CNLabeledValue<NSString>.localizedString(forLabel: url.label ?? "other"),
                "value": url.value as String,
            ]
        }

        data["socialProfiles"] = contact.socialProfiles.map { profile -> [String: String] in
            [
                "service": profile.value.service,
                "username": profile.value.username,
            ]
        }

        data["relations"] = contact.contactRelations.map { relation -> [String: String] in
            [
                "label": CNLabeledValue<CNContactRelation>.localizedString(forLabel: relation.label ?? "other"),
                "name": relation.value.name,
            ]
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            print(jsonString)
        }
    }
}
