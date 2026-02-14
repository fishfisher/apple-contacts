import ArgumentParser
import Foundation

struct InstallSkill: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install-skill",
        abstract: "Install the AI coding skill for this CLI",
        discussion: """
            Copies the embedded skill files to an AI tool's skill directory \
            so it can discover them globally.
            """
    )

    // Known AI tool skill directories (relative to home).
    private static let knownSkillLocations: [(label: String, dir: String)] = [
        ("Claude Code", ".claude/skills"),
        ("OpenAI Codex", ".codex/skills"),
        ("OpenCode", ".config/opencode/skill"),
        ("GitHub Copilot", ".copilot/skills"),
        ("Agents", ".agents/skills"),
    ]

    @Option(name: .shortAndLong, help: "Parent directory (default: interactive selection)")
    var path: String?

    @Flag(name: .shortAndLong, help: "Overwrite existing files without prompting")
    var force = false

    func run() throws {
        let skillName = "apple-contacts"
        let skillContent = EmbeddedSkill.skillMD
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let baseDir: String
        if let p = path {
            baseDir = p
        } else if isatty(fileno(stdin)) != 0 {
            // Interactive: show menu
            print("Install skill to:")
            for (i, loc) in Self.knownSkillLocations.enumerated() {
                print("  \(i + 1)) \(loc.label)")
            }
            print("  \(Self.knownSkillLocations.count + 1)) Custom path")
            print("> ", terminator: "")

            guard let line = readLine()?.trimmingCharacters(in: .whitespaces),
                  let choice = Int(line), choice >= 1, choice <= Self.knownSkillLocations.count + 1 else {
                print("Aborted.")
                return
            }

            if choice <= Self.knownSkillLocations.count {
                baseDir = (home as NSString).appendingPathComponent(Self.knownSkillLocations[choice - 1].dir)
            } else {
                print("Enter path: ", terminator: "")
                guard var entered = readLine()?.trimmingCharacters(in: .whitespaces),
                      !entered.isEmpty else {
                    print("Aborted.")
                    return
                }
                if entered.hasPrefix("~/") {
                    entered = (home as NSString).appendingPathComponent(String(entered.dropFirst(2)))
                }
                baseDir = entered
            }
        } else {
            // Non-interactive: default to Claude Code
            baseDir = (home as NSString).appendingPathComponent(Self.knownSkillLocations[0].dir)
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

        print("\u{001B}[32m\u{2713} Installed 1 file(s) to \(destDir)\u{001B}[0m")
    }
}
