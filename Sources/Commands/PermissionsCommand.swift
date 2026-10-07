import ArgumentParser
import Contacts
import Foundation

struct Permissions: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check and request Contacts permissions",
        discussion: """
            Check the current authorization status for Contacts access.
            If permission hasn't been requested yet, this will trigger the system prompt.

            Use --reset to get instructions for resetting permissions via tccutil.

            Note: When running from Node.js or other parent processes, the permission
            prompt may appear for that process instead of Terminal.
            """
    )

    @Flag(name: .long, help: "Show instructions to reset permissions")
    var reset: Bool = false

    func run() throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        print("Current status: \(statusDescription(status))")
        print("Executable: \(ProcessInfo.processInfo.arguments[0])")

        if let parentProcess = getParentProcessName() {
            print("Parent process: \(parentProcess)")
        }

        if reset {
            printResetInstructions()
            return
        }

        switch status {
        case .notDetermined:
            print("\nRequesting access...")
            if ContactsService.requestAccess(timeout: 60) {
                print("Access granted!")
            } else {
                print("Access not granted (refused, or no prompt could be shown within 60 s).")
                print("\nTo grant access, go to:")
                print("  System Settings > Privacy & Security > Contacts")
                throw ExitCode(ContactsService.accessDeniedExitCode)
            }

        case .authorized:
            print("\nContacts access is granted. No action needed.")

        case .denied:
            print("\nAccess was denied. To reset and request again:")
            printResetInstructions()
            throw ExitCode(ContactsService.accessDeniedExitCode)

        case .restricted:
            print("\nAccess is restricted by system policy (parental controls, MDM, etc.)")
            throw ExitCode(ContactsService.accessDeniedExitCode)

        @unknown default:
            print("\nUnknown authorization status")
            throw ExitCode.failure
        }
    }

    private func statusDescription(_ status: CNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined (permission not yet requested)"
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }

    private func getParentProcessName() -> String? {
        let ppid = getppid()
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(ppid)", "-o", "comm="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            // Ignore errors
        }
        return nil
    }

    private func printResetInstructions() {
        print("""

        To reset Contacts permissions, run one of these commands in Terminal:

        1. Reset for ALL apps (requires sudo):
           sudo tccutil reset AddressBook

        2. Reset for a specific app bundle ID:
           tccutil reset AddressBook <bundle-id>

        Common bundle IDs:
           - Terminal.app: com.apple.Terminal
           - iTerm2: com.googlecode.iterm2
           - VS Code: com.microsoft.VSCode
           - Node.js (when run directly): May appear as the parent process

        After resetting, run 'apple-contacts permissions' again to trigger the prompt.

        Manual method:
           System Settings > Privacy & Security > Contacts
           Find your terminal/app and toggle it off, then on again.
        """)
    }
}
