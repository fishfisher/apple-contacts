package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"text/tabwriter"

	"github.com/fishfisher/apple-contacts/internal/contacts"
	"github.com/spf13/cobra"
)

var (
	listLimit int
	listGroup string
	listJSON  bool
)

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List all contacts",
	Long: `List all contacts or contacts in a specific group.

Examples:
  apple-contacts list
  apple-contacts list --limit 10
  apple-contacts list --group "Family"
  apple-contacts list --json`,
	RunE: func(cmd *cobra.Command, args []string) error {
		var results []contacts.Contact
		var err error

		if listGroup != "" {
			results, err = contacts.ListContactsInGroup(listGroup)
		} else {
			results, err = contacts.ListContacts(listLimit)
		}

		if err != nil {
			return fmt.Errorf("list failed: %w", err)
		}

		if listLimit > 0 && len(results) > listLimit {
			results = results[:listLimit]
		}

		if listJSON {
			output, err := json.MarshalIndent(results, "", "  ")
			if err != nil {
				return fmt.Errorf("failed to marshal JSON: %w", err)
			}
			fmt.Println(string(output))
			return nil
		}

		if len(results) == 0 {
			if listGroup != "" {
				fmt.Printf("No contacts found in group '%s'\n", listGroup)
			} else {
				fmt.Println("No contacts found")
			}
			return nil
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "NAME\tPHONE\tEMAIL")

		for _, c := range results {
			phone := ""
			if len(c.Phones) > 0 {
				phone = c.Phones[0].Value
			}
			email := ""
			if len(c.Emails) > 0 {
				email = c.Emails[0].Value
			}
			fmt.Fprintf(w, "%s\t%s\t%s\n", c.Name, phone, email)
		}
		w.Flush()

		fmt.Printf("\nTotal: %d contact(s)\n", len(results))
		return nil
	},
}

func init() {
	listCmd.Flags().IntVarP(&listLimit, "limit", "l", 0, "Limit number of results")
	listCmd.Flags().StringVarP(&listGroup, "group", "g", "", "Filter by group name")
	listCmd.Flags().BoolVarP(&listJSON, "json", "j", false, "Output as JSON")
}
