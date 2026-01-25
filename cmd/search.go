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
	searchLimit         int
	searchJSON          bool
	searchEmail         string
	searchPhone         string
	searchOrg           string
	searchNote          string
	searchAddress       string
	searchBirthday      string
	searchBirthdayMonth int
	searchAny           string
)

var searchCmd = &cobra.Command{
	Use:   "search [term]",
	Short: "Search contacts by name or other criteria",
	Long: `Search for contacts using various criteria.
Without flags, searches by name. Use flags to search other fields.
Multiple flags are combined with AND logic.

Examples:
  apple-contacts search fisher                    # Search by name
  apple-contacts search --email "@agens.no"       # Search by email domain
  apple-contacts search --org "Acme"              # Search by organization
  apple-contacts search --phone "+47"             # Search by phone prefix
  apple-contacts search --birthday "01-25"        # Birthday on Jan 25 (MM-DD)
  apple-contacts search --birthday-month 1        # All January birthdays
  apple-contacts search --note "VIP"              # Search in notes
  apple-contacts search --address "Oslo"          # Search in addresses
  apple-contacts search --any "fisher"            # Search all fields
  apple-contacts search --org "Agens" --json      # JSON output`,
	RunE: func(cmd *cobra.Command, args []string) error {
		opts := contacts.SearchOptions{
			Email:         searchEmail,
			Phone:         searchPhone,
			Organization:  searchOrg,
			Note:          searchNote,
			Address:       searchAddress,
			Birthday:      searchBirthday,
			BirthdayMonth: searchBirthdayMonth,
			Any:           searchAny,
		}

		// If positional arg provided and no --any flag, use as name search
		if len(args) > 0 && searchAny == "" {
			opts.Name = args[0]
		}

		// Check if any search criteria provided
		if opts.Name == "" && opts.Email == "" && opts.Phone == "" &&
			opts.Organization == "" && opts.Note == "" && opts.Address == "" &&
			opts.Birthday == "" && opts.BirthdayMonth == 0 && opts.Any == "" {
			return fmt.Errorf("please provide a search term or use search flags (--email, --org, etc.)")
		}

		results, err := contacts.SearchContactsAdvanced(opts)
		if err != nil {
			return fmt.Errorf("search failed: %w", err)
		}

		if searchLimit > 0 && len(results) > searchLimit {
			results = results[:searchLimit]
		}

		if searchJSON {
			output, err := json.MarshalIndent(results, "", "  ")
			if err != nil {
				return fmt.Errorf("failed to marshal JSON: %w", err)
			}
			fmt.Println(string(output))
			return nil
		}

		if len(results) == 0 {
			fmt.Println("No contacts found matching the criteria")
			return nil
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "NAME\tNICKNAME\tORGANIZATION\tID")

		for _, c := range results {
			nick := c.Nickname
			if nick == "" {
				nick = "-"
			}
			org := c.Organization
			if org == "" {
				org = "-"
			}
			shortID := c.ID
			if len(shortID) > 20 {
				shortID = shortID[:17] + "..."
			}
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", c.Name, nick, org, shortID)
		}
		w.Flush()

		fmt.Printf("\nFound %d contact(s)\n", len(results))
		return nil
	},
}

func init() {
	searchCmd.Flags().IntVarP(&searchLimit, "limit", "l", 0, "Limit number of results")
	searchCmd.Flags().BoolVarP(&searchJSON, "json", "j", false, "Output as JSON")
	searchCmd.Flags().StringVar(&searchEmail, "email", "", "Search by email (contains)")
	searchCmd.Flags().StringVar(&searchPhone, "phone", "", "Search by phone number (contains)")
	searchCmd.Flags().StringVar(&searchOrg, "org", "", "Search by organization (contains)")
	searchCmd.Flags().StringVar(&searchNote, "note", "", "Search in notes (contains)")
	searchCmd.Flags().StringVar(&searchAddress, "address", "", "Search in addresses (contains)")
	searchCmd.Flags().StringVar(&searchBirthday, "birthday", "", "Search by birthday (MM-DD format)")
	searchCmd.Flags().IntVar(&searchBirthdayMonth, "birthday-month", 0, "Search by birthday month (1-12)")
	searchCmd.Flags().StringVar(&searchAny, "any", "", "Search across all fields")
}
