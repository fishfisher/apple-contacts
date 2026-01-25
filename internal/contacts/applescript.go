package contacts

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

// Contact represents a contact from Apple Contacts
type Contact struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	FirstName    string    `json:"firstName"`
	LastName     string    `json:"lastName"`
	Nickname     string    `json:"nickname"`
	Organization string    `json:"organization"`
	JobTitle     string    `json:"jobTitle"`
	Department   string    `json:"department"`
	Birthday     string    `json:"birthday"` // ISO format: YYYY-MM-DD
	Note         string    `json:"note"`
	Phones       []Phone   `json:"phones"`
	Emails       []Email   `json:"emails"`
	Addresses    []Address `json:"addresses"`
}

// Phone represents a phone number with label
type Phone struct {
	Label string `json:"label"`
	Value string `json:"value"`
}

// Email represents an email address with label
type Email struct {
	Label string `json:"label"`
	Value string `json:"value"`
}

// Address represents a physical address
type Address struct {
	Label   string `json:"label"`
	Street  string `json:"street"`
	City    string `json:"city"`
	State   string `json:"state"`
	Zip     string `json:"zip"`
	Country string `json:"country"`
}

// Group represents a contact group
type Group struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

// SearchOptions contains criteria for advanced contact search
type SearchOptions struct {
	Name          string // Search in name (contains)
	Email         string // Search in email addresses (contains)
	Phone         string // Search in phone numbers (contains)
	Organization  string // Search in organization (contains)
	Note          string // Search in notes (contains)
	Address       string // Search in addresses (contains)
	Birthday      string // Exact birthday match (MM-DD format)
	BirthdayMonth int    // Birthday month (1-12)
	Any           string // Search across all text fields
}

// execJXA executes JavaScript for Automation and returns the output
func execJXA(script string) (string, error) {
	cmd := exec.Command("osascript", "-l", "JavaScript", "-e", script)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("JXA execution failed: %w\nOutput: %s", err, string(output))
	}
	return strings.TrimSpace(string(output)), nil
}

// escapeJS escapes a string for use in JavaScript
func escapeJS(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, "'", "\\'")
	s = strings.ReplaceAll(s, "\n", "\\n")
	return s
}

// contactExtractorJS returns the JavaScript code to extract contact data
func contactExtractorJS(includeDetails bool) string {
	base := `
        var phones = [];
        try {
            var phs = p.phones();
            for (var j = 0; j < phs.length; j++) {
                phones.push({label: phs[j].label() || '', value: phs[j].value() || ''});
            }
        } catch(e) {}

        var emails = [];
        try {
            var ems = p.emails();
            for (var k = 0; k < ems.length; k++) {
                emails.push({label: ems[k].label() || '', value: ems[k].value() || ''});
            }
        } catch(e) {}
`
	if includeDetails {
		base += `
        var addresses = [];
        try {
            var addrs = p.addresses();
            for (var m = 0; m < addrs.length; m++) {
                var a = addrs[m];
                addresses.push({
                    label: a.label() || '',
                    street: a.street() || '',
                    city: a.city() || '',
                    state: a.state() || '',
                    zip: a.zip() || '',
                    country: a.country() || ''
                });
            }
        } catch(e) {}

        var birthday = '';
        try {
            var bd = p.birthDate();
            if (bd) {
                var month = ('0' + (bd.getMonth() + 1)).slice(-2);
                var day = ('0' + bd.getDate()).slice(-2);
                birthday = bd.getFullYear() + '-' + month + '-' + day;
            }
        } catch(e) {}

        var contact = {
            id: p.id(),
            name: p.name() || '',
            firstName: p.firstName() || '',
            lastName: p.lastName() || '',
            nickname: p.nickname() || '',
            organization: p.organization() || '',
            jobTitle: p.jobTitle() || '',
            department: p.department() || '',
            birthday: birthday,
            note: p.note() || '',
            phones: phones,
            emails: emails,
            addresses: addresses
        };
`
	} else {
		base += `
        var birthday = '';
        try {
            var bd = p.birthDate();
            if (bd) {
                var month = ('0' + (bd.getMonth() + 1)).slice(-2);
                var day = ('0' + bd.getDate()).slice(-2);
                birthday = bd.getFullYear() + '-' + month + '-' + day;
            }
        } catch(e) {}

        var contact = {
            id: p.id(),
            name: p.name() || '',
            firstName: p.firstName() || '',
            lastName: p.lastName() || '',
            organization: p.organization() || '',
            birthday: birthday,
            phones: phones,
            emails: emails
        };
`
	}
	return base
}

// SearchContacts searches for contacts by name (contains match)
func SearchContacts(term string) ([]Contact, error) {
	return SearchContactsAdvanced(SearchOptions{Name: term})
}

// SearchContactsAdvanced searches contacts with multiple criteria
func SearchContactsAdvanced(opts SearchOptions) ([]Contact, error) {
	// Build the match conditions
	var conditions []string

	if opts.Name != "" {
		conditions = append(conditions, fmt.Sprintf(`(p.name() || '').toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Name))))
	}
	if opts.Email != "" {
		conditions = append(conditions, fmt.Sprintf(`emailsStr.toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Email))))
	}
	if opts.Phone != "" {
		// Normalize phone for comparison (remove non-digits for matching)
		conditions = append(conditions, fmt.Sprintf(`phonesStr.indexOf('%s') !== -1`, escapeJS(opts.Phone)))
	}
	if opts.Organization != "" {
		conditions = append(conditions, fmt.Sprintf(`(p.organization() || '').toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Organization))))
	}
	if opts.Note != "" {
		conditions = append(conditions, fmt.Sprintf(`(p.note() || '').toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Note))))
	}
	if opts.Address != "" {
		conditions = append(conditions, fmt.Sprintf(`addressStr.toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Address))))
	}
	if opts.Birthday != "" {
		// Birthday in MM-DD format
		conditions = append(conditions, fmt.Sprintf(`birthdayMMDD === '%s'`, escapeJS(opts.Birthday)))
	}
	if opts.BirthdayMonth > 0 && opts.BirthdayMonth <= 12 {
		conditions = append(conditions, fmt.Sprintf(`birthdayMonth === %d`, opts.BirthdayMonth))
	}
	if opts.Any != "" {
		anyLower := escapeJS(strings.ToLower(opts.Any))
		conditions = append(conditions, fmt.Sprintf(`(
            (p.name() || '').toLowerCase().indexOf('%s') !== -1 ||
            (p.organization() || '').toLowerCase().indexOf('%s') !== -1 ||
            (p.note() || '').toLowerCase().indexOf('%s') !== -1 ||
            (p.nickname() || '').toLowerCase().indexOf('%s') !== -1 ||
            emailsStr.toLowerCase().indexOf('%s') !== -1 ||
            phonesStr.indexOf('%s') !== -1 ||
            addressStr.toLowerCase().indexOf('%s') !== -1
        )`, anyLower, anyLower, anyLower, anyLower, anyLower, anyLower, anyLower))
	}

	if len(conditions) == 0 {
		return []Contact{}, nil
	}

	matchCondition := strings.Join(conditions, " && ")

	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var allPeople = Contacts.people();
var results = [];

for (var i = 0; i < allPeople.length; i++) {
    var p = allPeople[i];

    // Pre-compute searchable strings
    var emailsStr = '';
    try {
        var ems = p.emails();
        for (var k = 0; k < ems.length; k++) {
            emailsStr += (ems[k].value() || '') + ' ';
        }
    } catch(e) {}

    var phonesStr = '';
    try {
        var phs = p.phones();
        for (var j = 0; j < phs.length; j++) {
            phonesStr += (phs[j].value() || '').replace(/[^0-9+]/g, '') + ' ';
        }
    } catch(e) {}

    var addressStr = '';
    try {
        var addrs = p.addresses();
        for (var m = 0; m < addrs.length; m++) {
            var a = addrs[m];
            addressStr += (a.street() || '') + ' ' + (a.city() || '') + ' ' + (a.state() || '') + ' ' + (a.zip() || '') + ' ' + (a.country() || '') + ' ';
        }
    } catch(e) {}

    var birthdayMMDD = '';
    var birthdayMonth = 0;
    try {
        var bd = p.birthDate();
        if (bd) {
            var month = bd.getMonth() + 1;
            var day = bd.getDate();
            birthdayMonth = month;
            birthdayMMDD = ('0' + month).slice(-2) + '-' + ('0' + day).slice(-2);
        }
    } catch(e) {}

    if (%s) {
        var phones = [];
        try {
            var phs = p.phones();
            for (var j = 0; j < phs.length; j++) {
                phones.push({label: phs[j].label() || '', value: phs[j].value() || ''});
            }
        } catch(e) {}

        var emails = [];
        try {
            var ems = p.emails();
            for (var k = 0; k < ems.length; k++) {
                emails.push({label: ems[k].label() || '', value: ems[k].value() || ''});
            }
        } catch(e) {}

        var birthday = '';
        try {
            var bd = p.birthDate();
            if (bd) {
                var month = ('0' + (bd.getMonth() + 1)).slice(-2);
                var day = ('0' + bd.getDate()).slice(-2);
                birthday = bd.getFullYear() + '-' + month + '-' + day;
            }
        } catch(e) {}

        results.push({
            id: p.id(),
            name: p.name() || '',
            firstName: p.firstName() || '',
            lastName: p.lastName() || '',
            organization: p.organization() || '',
            birthday: birthday,
            phones: phones,
            emails: emails
        });
    }
}
JSON.stringify(results);
`, matchCondition)

	output, err := execJXA(script)
	if err != nil {
		return nil, err
	}

	if output == "" || output == "null" {
		return []Contact{}, nil
	}

	var contacts []Contact
	if err := json.Unmarshal([]byte(output), &contacts); err != nil {
		return nil, fmt.Errorf("failed to parse contacts: %w", err)
	}

	return contacts, nil
}

// GetContact retrieves full details for a contact by name
func GetContact(name string) (*Contact, error) {
	escapedName := escapeJS(strings.ToLower(name))

	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var searchName = '%s';
var allPeople = Contacts.people();
var result = null;

for (var i = 0; i < allPeople.length; i++) {
    var p = allPeople[i];
    var pName = (p.name() || '').toLowerCase();
    if (pName === searchName || pName.indexOf(searchName) !== -1) {
        %s
        result = contact;

        // Prefer exact match
        if (pName === searchName) {
            break;
        }
    }
}
JSON.stringify(result);
`, escapedName, contactExtractorJS(true))

	output, err := execJXA(script)
	if err != nil {
		return nil, err
	}

	if output == "" || output == "null" {
		return nil, fmt.Errorf("contact not found: %s", name)
	}

	var contact Contact
	if err := json.Unmarshal([]byte(output), &contact); err != nil {
		return nil, fmt.Errorf("failed to parse contact: %w", err)
	}

	return &contact, nil
}

// GetContactByID retrieves full details for a contact by ID
func GetContactByID(id string) (*Contact, error) {
	escapedID := escapeJS(id)

	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var allPeople = Contacts.people();
var result = null;

for (var i = 0; i < allPeople.length; i++) {
    var p = allPeople[i];
    if (p.id() === '%s') {
        %s
        result = contact;
        break;
    }
}
JSON.stringify(result);
`, escapedID, contactExtractorJS(true))

	output, err := execJXA(script)
	if err != nil {
		return nil, err
	}

	if output == "" || output == "null" {
		return nil, fmt.Errorf("contact not found with ID: %s", id)
	}

	var contact Contact
	if err := json.Unmarshal([]byte(output), &contact); err != nil {
		return nil, fmt.Errorf("failed to parse contact: %w", err)
	}

	return &contact, nil
}

// ListContacts returns all contacts
func ListContacts(limit int) ([]Contact, error) {
	script := `
var Contacts = Application("Contacts");
var allPeople = Contacts.people();
var results = [];

for (var i = 0; i < allPeople.length; i++) {
    var p = allPeople[i];
    var phones = [];
    try {
        var phs = p.phones();
        for (var j = 0; j < phs.length; j++) {
            phones.push({label: phs[j].label() || '', value: phs[j].value() || ''});
        }
    } catch(e) {}

    var emails = [];
    try {
        var ems = p.emails();
        for (var k = 0; k < ems.length; k++) {
            emails.push({label: ems[k].label() || '', value: ems[k].value() || ''});
        }
    } catch(e) {}

    results.push({
        id: p.id(),
        name: p.name() || '',
        firstName: p.firstName() || '',
        lastName: p.lastName() || '',
        organization: p.organization() || '',
        phones: phones,
        emails: emails
    });
}
JSON.stringify(results);
`

	output, err := execJXA(script)
	if err != nil {
		return nil, err
	}

	if output == "" || output == "null" {
		return []Contact{}, nil
	}

	var contacts []Contact
	if err := json.Unmarshal([]byte(output), &contacts); err != nil {
		return nil, fmt.Errorf("failed to parse contacts: %w", err)
	}

	if limit > 0 && len(contacts) > limit {
		contacts = contacts[:limit]
	}

	return contacts, nil
}

// ListGroups returns all contact groups with their contact counts
func ListGroups() ([]Group, error) {
	script := `
var Contacts = Application("Contacts");
var groups = Contacts.groups();
var results = [];

for (var i = 0; i < groups.length; i++) {
    var g = groups[i];
    var count = 0;
    try {
        count = g.people().length;
    } catch(e) {}
    results.push({
        name: g.name(),
        count: count
    });
}
JSON.stringify(results);
`

	output, err := execJXA(script)
	if err != nil {
		return nil, err
	}

	if output == "" || output == "null" {
		return []Group{}, nil
	}

	var groups []Group
	if err := json.Unmarshal([]byte(output), &groups); err != nil {
		return nil, fmt.Errorf("failed to parse groups: %w", err)
	}

	return groups, nil
}

// ListContactsInGroup returns contacts in a specific group
func ListContactsInGroup(groupName string) ([]Contact, error) {
	escapedGroup := escapeJS(groupName)

	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var groups = Contacts.groups.whose({name: '%s'});
var results = [];

if (groups.length > 0) {
    var people = groups[0].people();
    for (var i = 0; i < people.length; i++) {
        var p = people[i];
        var phones = [];
        try {
            var phs = p.phones();
            for (var j = 0; j < phs.length; j++) {
                phones.push({label: phs[j].label() || '', value: phs[j].value() || ''});
            }
        } catch(e) {}

        var emails = [];
        try {
            var ems = p.emails();
            for (var k = 0; k < ems.length; k++) {
                emails.push({label: ems[k].label() || '', value: ems[k].value() || ''});
            }
        } catch(e) {}

        results.push({
            id: p.id(),
            name: p.name() || '',
            firstName: p.firstName() || '',
            lastName: p.lastName() || '',
            organization: p.organization() || '',
            phones: phones,
            emails: emails
        });
    }
}
JSON.stringify(results);
`, escapedGroup)

	output, err := execJXA(script)
	if err != nil {
		return nil, err
	}

	if output == "" || output == "null" {
		return []Contact{}, nil
	}

	var contacts []Contact
	if err := json.Unmarshal([]byte(output), &contacts); err != nil {
		return nil, fmt.Errorf("failed to parse contacts: %w", err)
	}

	return contacts, nil
}

// GetContactVCard exports a contact as vCard format by name
func GetContactVCard(name string) (string, error) {
	escapedName := escapeJS(strings.ToLower(name))

	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var searchName = '%s';
var allPeople = Contacts.people();
var vcard = null;

for (var i = 0; i < allPeople.length; i++) {
    var p = allPeople[i];
    var pName = (p.name() || '').toLowerCase();
    if (pName === searchName || pName.indexOf(searchName) !== -1) {
        vcard = p.vcard();
        if (pName === searchName) {
            break;
        }
    }
}
vcard;
`, escapedName)

	output, err := execJXA(script)
	if err != nil {
		return "", err
	}

	if output == "" || output == "null" {
		return "", fmt.Errorf("contact not found: %s", name)
	}

	return output, nil
}

// GetContactVCardByID exports a contact as vCard format by ID
func GetContactVCardByID(id string) (string, error) {
	escapedID := escapeJS(id)

	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var allPeople = Contacts.people();
var vcard = null;

for (var i = 0; i < allPeople.length; i++) {
    var p = allPeople[i];
    if (p.id() === '%s') {
        vcard = p.vcard();
        break;
    }
}
vcard;
`, escapedID)

	output, err := execJXA(script)
	if err != nil {
		return "", err
	}

	if output == "" || output == "null" {
		return "", fmt.Errorf("contact not found with ID: %s", id)
	}

	return output, nil
}

// CleanLabel cleans up Apple's internal label format
// e.g., "_$!<Home>!$_" becomes "home"
func CleanLabel(label string) string {
	if strings.HasPrefix(label, "_$!<") && strings.HasSuffix(label, ">!$_") {
		label = strings.TrimPrefix(label, "_$!<")
		label = strings.TrimSuffix(label, ">!$_")
	}
	return strings.ToLower(label)
}

// FormatAddress formats an address for display
func (a Address) Format() string {
	parts := []string{}
	if a.Street != "" {
		parts = append(parts, a.Street)
	}
	cityStateZip := ""
	if a.City != "" {
		cityStateZip = a.City
	}
	if a.State != "" {
		if cityStateZip != "" {
			cityStateZip += ", " + a.State
		} else {
			cityStateZip = a.State
		}
	}
	if a.Zip != "" {
		if cityStateZip != "" {
			cityStateZip += " " + a.Zip
		} else {
			cityStateZip = a.Zip
		}
	}
	if cityStateZip != "" {
		parts = append(parts, cityStateZip)
	}
	if a.Country != "" {
		parts = append(parts, a.Country)
	}
	return strings.Join(parts, ", ")
}

// HasDuplicateNames checks if any contacts have the same name
func HasDuplicateNames(contacts []Contact) bool {
	seen := make(map[string]bool)
	for _, c := range contacts {
		if seen[c.Name] {
			return true
		}
		seen[c.Name] = true
	}
	return false
}
