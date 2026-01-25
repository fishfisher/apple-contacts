package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var (
	appVersion = "dev"
	appCommit  = "none"
)

// SetVersionInfo sets the version information from main
func SetVersionInfo(version, commit string) {
	appVersion = version
	appCommit = commit
}

var rootCmd = &cobra.Command{
	Use:   "apple-contacts",
	Short: "CLI tool to search and query Apple Contacts",
	Long: `apple-contacts is a command-line tool for searching and querying
your Apple Contacts database using AppleScript/JXA.

Examples:
  apple-contacts search fisher
  apple-contacts show "Erik Fisher"
  apple-contacts list
  apple-contacts groups
  apple-contacts export "Erik Fisher"`,
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print version information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("apple-contacts %s (commit: %s)\n", appVersion, appCommit)
	},
}

// Execute runs the root command
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.AddCommand(searchCmd)
	rootCmd.AddCommand(showCmd)
	rootCmd.AddCommand(listCmd)
	rootCmd.AddCommand(groupsCmd)
	rootCmd.AddCommand(exportCmd)
	rootCmd.AddCommand(versionCmd)
}
