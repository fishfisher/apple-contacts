package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"text/tabwriter"

	"github.com/fishfisher/apple-contacts/internal/contacts"
	"github.com/spf13/cobra"
)

var groupsJSON bool

var groupsCmd = &cobra.Command{
	Use:   "groups",
	Short: "List contact groups",
	Long: `List all contact groups with their contact counts.

Examples:
  apple-contacts groups
  apple-contacts groups --json`,
	RunE: func(cmd *cobra.Command, args []string) error {
		groups, err := contacts.ListGroups()
		if err != nil {
			return fmt.Errorf("failed to list groups: %w", err)
		}

		if groupsJSON {
			output, err := json.MarshalIndent(groups, "", "  ")
			if err != nil {
				return fmt.Errorf("failed to marshal JSON: %w", err)
			}
			fmt.Println(string(output))
			return nil
		}

		if len(groups) == 0 {
			fmt.Println("No groups found")
			return nil
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "GROUP\tCONTACTS")

		for _, g := range groups {
			fmt.Fprintf(w, "%s\t%d\n", g.Name, g.Count)
		}
		w.Flush()

		fmt.Printf("\nTotal: %d group(s)\n", len(groups))
		return nil
	},
}

func init() {
	groupsCmd.Flags().BoolVarP(&groupsJSON, "json", "j", false, "Output as JSON")
}
