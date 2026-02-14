import ArgumentParser
import Foundation

struct InstallSkill: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install-skill",
        abstract: "Install the Claude Code skill for this CLI",
        discussion: """
            Copies the embedded skill files to ~/.claude/skills/ so Claude Code \
            can discover them globally.
            """
    )

    @Option(name: .shortAndLong, help: "Parent directory (default: ~/.claude/skills/)")
    var path: String?

    @Flag(name: .shortAndLong, help: "Overwrite existing files without prompting")
    var force = false

    func run() throws {
        let skillName = "apple-contacts"
        let skillContent = EmbeddedSkill.skillMD

        let baseDir: String
        if let p = path {
            baseDir = p
        } else {
            baseDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/skills")
                .path
        }

        let destDir = (baseDir as NSString).appendingPathComponent(skillName)
        let destFile = (destDir as NSString).appendingPathComponent("SKILL.md")

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: destFile)

        // Show file list
        print("\u{001B}[1mInstalling to \(destDir)\u{001B}[0m")
        let marker = fileExists ? "\u{001B}[33m (exists)\u{001B}[0m" : ""
        print("  SKILL.md\(marker)")

        // Prompt if existing and not --force
        if fileExists && !force {
            print("\n\u{001B}[33m?\u{001B}[0m Overwrite 1 existing file(s)? [y/N] ", terminator: "")
            guard let answer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased(),
                  answer == "y" else {
                print("Aborted.")
                return
            }
        }

        // Create directory and write file
        do {
            try FileManager.default.createDirectory(
                atPath: destDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ValidationError("creating directory: mkdir \(destDir): \(error.localizedDescription)")
        }
        do {
            try skillContent.write(toFile: destFile, atomically: true, encoding: .utf8)
        } catch {
            throw ValidationError("writing SKILL.md: \(error.localizedDescription)")
        }

        print("\u{001B}[32m✓ Installed 1 file(s) to \(destDir)\u{001B}[0m")
    }
}
