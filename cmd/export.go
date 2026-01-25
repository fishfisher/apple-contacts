package cmd

import (
	"fmt"
	"os"

	"github.com/fishfisher/apple-contacts/internal/contacts"
	"github.com/spf13/cobra"
)

var (
	exportOutput string
	exportID     string
)

var exportCmd = &cobra.Command{
	Use:   "export [name]",
	Short: "Export contact as vCard",
	Long: `Export a contact in vCard format.
Outputs to stdout by default, or to a file with --output.
Use --id to select a specific contact by ID (useful for duplicates).

Examples:
  apple-contacts export "Erik Fisher"
  apple-contacts export "Erik Fisher" --output erik.vcf
  apple-contacts export --id "ABC123-DEF456:ABPerson"`,
	RunE: func(cmd *cobra.Command, args []string) error {
		var vcard string
		var err error

		if exportID != "" {
			vcard, err = contacts.GetContactVCardByID(exportID)
		} else if len(args) > 0 {
			vcard, err = contacts.GetContactVCard(args[0])
		} else {
			return fmt.Errorf("please provide a name or use --id flag")
		}

		if err != nil {
			return err
		}

		if exportOutput != "" {
			if err := os.WriteFile(exportOutput, []byte(vcard), 0644); err != nil {
				return fmt.Errorf("failed to write file: %w", err)
			}
			fmt.Printf("Exported to %s\n", exportOutput)
			return nil
		}

		fmt.Println(vcard)
		return nil
	},
}

func init() {
	exportCmd.Flags().StringVarP(&exportOutput, "output", "o", "", "Output file path")
	exportCmd.Flags().StringVar(&exportID, "id", "", "Export contact by ID instead of name")
}
