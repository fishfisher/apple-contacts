package cmd

import (
	"encoding/json"
	"fmt"

	"github.com/fishfisher/apple-contacts/internal/contacts"
	"github.com/spf13/cobra"
)

var (
	showJSON bool
	showID   string
)

var showCmd = &cobra.Command{
	Use:   "show [name]",
	Short: "Show full contact details",
	Long: `Display all available information for a contact.
Searches by exact name first, then falls back to partial match.
Use --id to select a specific contact by ID (useful for duplicates).

Examples:
  apple-contacts show "Erik Fisher"
  apple-contacts show fisher
  apple-contacts show "Erik Fisher" --json
  apple-contacts show --id "ABC123-DEF456:ABPerson"`,
	RunE: func(cmd *cobra.Command, args []string) error {
		var contact *contacts.Contact
		var err error

		if showID != "" {
			contact, err = contacts.GetContactByID(showID)
		} else if len(args) > 0 {
			contact, err = contacts.GetContact(args[0])
		} else {
			return fmt.Errorf("please provide a name or use --id flag")
		}

		if err != nil {
			return err
		}

		if showJSON {
			output, err := json.MarshalIndent(contact, "", "  ")
			if err != nil {
				return fmt.Errorf("failed to marshal JSON: %w", err)
			}
			fmt.Println(string(output))
			return nil
		}

		// Display formatted output
		fmt.Printf("Name:         %s\n", contact.Name)
		fmt.Printf("ID:           %s\n", contact.ID)
		if contact.Nickname != "" {
			fmt.Printf("Nickname:     %s\n", contact.Nickname)
		}
		if contact.Organization != "" {
			fmt.Printf("Organization: %s\n", contact.Organization)
		}
		if contact.Department != "" {
			fmt.Printf("Department:   %s\n", contact.Department)
		}
		if contact.JobTitle != "" {
			fmt.Printf("Job Title:    %s\n", contact.JobTitle)
		}
		if contact.Birthday != "" {
			fmt.Printf("Birthday:     %s\n", contact.Birthday)
		}

		if len(contact.Phones) > 0 {
			fmt.Println("\nPHONES:")
			for _, p := range contact.Phones {
				label := contacts.CleanLabel(p.Label)
				if label == "" {
					label = "other"
				}
				fmt.Printf("  %-10s %s\n", label, p.Value)
			}
		}

		if len(contact.Emails) > 0 {
			fmt.Println("\nEMAILS:")
			for _, e := range contact.Emails {
				label := contacts.CleanLabel(e.Label)
				if label == "" {
					label = "other"
				}
				fmt.Printf("  %-10s %s\n", label, e.Value)
			}
		}

		if len(contact.Addresses) > 0 {
			fmt.Println("\nADDRESSES:")
			for _, a := range contact.Addresses {
				label := contacts.CleanLabel(a.Label)
				if label == "" {
					label = "other"
				}
				fmt.Printf("  %-10s %s\n", label, a.Format())
			}
		}

		if contact.Note != "" {
			fmt.Println("\nNOTE:")
			fmt.Printf("  %s\n", contact.Note)
		}

		return nil
	},
}

func init() {
	showCmd.Flags().BoolVarP(&showJSON, "json", "j", false, "Output as JSON")
	showCmd.Flags().StringVar(&showID, "id", "", "Get contact by ID instead of name")
}
