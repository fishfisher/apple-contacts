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

// SearchContacts searches for contacts by name (contains match)
func SearchContacts(term string) ([]Contact, error) {
	return SearchContactsAdvanced(SearchOptions{Name: term})
}

// SearchContactsAdvanced searches contacts with multiple criteria
// Uses batch property access for performance
func SearchContactsAdvanced(opts SearchOptions) ([]Contact, error) {
	// For simple name-only search, use the fast whose() query
	if opts.Name != "" && opts.Email == "" && opts.Phone == "" &&
		opts.Organization == "" && opts.Note == "" && opts.Address == "" &&
		opts.Birthday == "" && opts.BirthdayMonth == 0 && opts.Any == "" {
		return searchByNameFast(opts.Name)
	}

	// For complex queries, fetch all data in batch and filter in JS
	return searchAdvanced(opts)
}

// searchByNameFast uses Contacts' native whose() for fast name search
// Searches both name and nickname fields
// Only fetches scalar properties (name, org, nickname) - no phones/emails for speed
func searchByNameFast(term string) ([]Contact, error) {
	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var searchTerm = '%s';

// Search by name and nickname separately (JXA doesn't support OR)
var byName = Contacts.people.whose({name: {_contains: searchTerm}});
var byNick = Contacts.people.whose({nickname: {_contains: searchTerm}});

// Collect results, avoiding duplicates
var seen = {};
var results = [];

function addMatches(matches) {
    var ids = matches.id();
    var names = matches.name();
    var firstNames = matches.firstName();
    var lastNames = matches.lastName();
    var nicknames = matches.nickname();
    var orgs = matches.organization();

    for (var i = 0; i < ids.length; i++) {
        if (!seen[ids[i]]) {
            seen[ids[i]] = true;
            results.push({
                id: ids[i],
                name: names[i] || '',
                firstName: firstNames[i] || '',
                lastName: lastNames[i] || '',
                nickname: nicknames[i] || '',
                organization: orgs[i] || ''
            });
        }
    }
}

addMatches(byName);
addMatches(byNick);

JSON.stringify(results);
`, escapeJS(term))

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

// searchAdvanced handles complex multi-field searches
func searchAdvanced(opts SearchOptions) ([]Contact, error) {
	// Build filter conditions for JavaScript
	var filters []string

	if opts.Name != "" {
		filters = append(filters, fmt.Sprintf(`(names[i] || '').toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Name))))
	}
	if opts.Organization != "" {
		filters = append(filters, fmt.Sprintf(`(orgs[i] || '').toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Organization))))
	}
	if opts.Email != "" {
		filters = append(filters, fmt.Sprintf(`emailStr.toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Email))))
	}
	if opts.Phone != "" {
		filters = append(filters, fmt.Sprintf(`phoneStr.indexOf('%s') !== -1`, escapeJS(opts.Phone)))
	}
	if opts.Note != "" {
		filters = append(filters, fmt.Sprintf(`(notes[i] || '').toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Note))))
	}
	if opts.Address != "" {
		filters = append(filters, fmt.Sprintf(`addrStr.toLowerCase().indexOf('%s') !== -1`, escapeJS(strings.ToLower(opts.Address))))
	}
	if opts.Birthday != "" {
		filters = append(filters, fmt.Sprintf(`birthdayMMDD === '%s'`, escapeJS(opts.Birthday)))
	}
	if opts.BirthdayMonth > 0 && opts.BirthdayMonth <= 12 {
		filters = append(filters, fmt.Sprintf(`birthdayMonth === %d`, opts.BirthdayMonth))
	}
	if opts.Any != "" {
		anyLower := escapeJS(strings.ToLower(opts.Any))
		filters = append(filters, fmt.Sprintf(`(
			(names[i] || '').toLowerCase().indexOf('%s') !== -1 ||
			(orgs[i] || '').toLowerCase().indexOf('%s') !== -1 ||
			(notes[i] || '').toLowerCase().indexOf('%s') !== -1 ||
			emailStr.toLowerCase().indexOf('%s') !== -1 ||
			phoneStr.indexOf('%s') !== -1 ||
			addrStr.toLowerCase().indexOf('%s') !== -1
		)`, anyLower, anyLower, anyLower, anyLower, anyLower, anyLower))
	}

	if len(filters) == 0 {
		return []Contact{}, nil
	}

	filterCondition := strings.Join(filters, " && ")

	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var people = Contacts.people;

// Batch fetch all scalar properties (fast)
var ids = people.id();
var names = people.name();
var firstNames = people.firstName();
var lastNames = people.lastName();
var orgs = people.organization();
var notes = people.note();
var birthDates = people.birthDate();

var results = [];

for (var i = 0; i < ids.length; i++) {
    // Compute birthday strings
    var birthdayMMDD = '';
    var birthdayMonth = 0;
    var bd = birthDates[i];
    if (bd) {
        var month = bd.getMonth() + 1;
        var day = bd.getDate();
        birthdayMonth = month;
        birthdayMMDD = ('0' + month).slice(-2) + '-' + ('0' + day).slice(-2);
    }

    // Get phone/email/address strings for filtering (only if needed)
    var phoneStr = '';
    var emailStr = '';
    var addrStr = '';
    var p = people[i];

    try {
        var phs = p.phones();
        for (var j = 0; j < phs.length; j++) {
            phoneStr += (phs[j].value() || '').replace(/[^0-9+]/g, '') + ' ';
        }
    } catch(e) {}

    try {
        var ems = p.emails();
        for (var k = 0; k < ems.length; k++) {
            emailStr += (ems[k].value() || '') + ' ';
        }
    } catch(e) {}

    try {
        var addrs = p.addresses();
        for (var m = 0; m < addrs.length; m++) {
            var a = addrs[m];
            addrStr += (a.street() || '') + ' ' + (a.city() || '') + ' ' + (a.state() || '') + ' ' + (a.zip() || '') + ' ' + (a.country() || '') + ' ';
        }
    } catch(e) {}

    if (%s) {
        // Collect full data for matches
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
        if (bd) {
            var month = ('0' + (bd.getMonth() + 1)).slice(-2);
            var day = ('0' + bd.getDate()).slice(-2);
            birthday = bd.getFullYear() + '-' + month + '-' + day;
        }

        results.push({
            id: ids[i],
            name: names[i] || '',
            firstName: firstNames[i] || '',
            lastName: lastNames[i] || '',
            organization: orgs[i] || '',
            birthday: birthday,
            phones: phones,
            emails: emails
        });
    }
}
JSON.stringify(results);
`, filterCondition)

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
	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var searchName = '%s';
var matches = Contacts.people.whose({name: {_contains: searchName}});

if (matches.length === 0) {
    null;
} else {
    // Prefer exact match
    var p = matches[0];
    var searchLower = searchName.toLowerCase();
    for (var i = 0; i < matches.length; i++) {
        if ((matches[i].name() || '').toLowerCase() === searchLower) {
            p = matches[i];
            break;
        }
    }

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

    JSON.stringify({
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
    });
}
`, escapeJS(name))

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
	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var matches = Contacts.people.whose({id: '%s'});

if (matches.length === 0) {
    null;
} else {
    var p = matches[0];

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

    JSON.stringify({
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
    });
}
`, escapeJS(id))

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
	limitClause := ""
	if limit > 0 {
		limitClause = fmt.Sprintf("if (results.length >= %d) break;", limit)
	}

	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var people = Contacts.people;

// Batch fetch scalar properties
var ids = people.id();
var names = people.name();
var firstNames = people.firstName();
var lastNames = people.lastName();
var orgs = people.organization();

var results = [];
for (var i = 0; i < ids.length; i++) {
    %s
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
        id: ids[i],
        name: names[i] || '',
        firstName: firstNames[i] || '',
        lastName: lastNames[i] || '',
        organization: orgs[i] || '',
        phones: phones,
        emails: emails
    });
}
JSON.stringify(results);
`, limitClause)

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

// ListGroups returns all contact groups with their contact counts
func ListGroups() ([]Group, error) {
	script := `
var Contacts = Application("Contacts");
var groups = Contacts.groups;
var names = groups.name();
var results = [];

for (var i = 0; i < names.length; i++) {
    var count = 0;
    try {
        count = groups[i].people().length;
    } catch(e) {}
    results.push({
        name: names[i],
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
	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var groups = Contacts.groups.whose({name: '%s'});
var results = [];

if (groups.length > 0) {
    var people = groups[0].people;
    var ids = people.id();
    var names = people.name();
    var firstNames = people.firstName();
    var lastNames = people.lastName();
    var orgs = people.organization();

    for (var i = 0; i < ids.length; i++) {
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
            id: ids[i],
            name: names[i] || '',
            firstName: firstNames[i] || '',
            lastName: lastNames[i] || '',
            organization: orgs[i] || '',
            phones: phones,
            emails: emails
        });
    }
}
JSON.stringify(results);
`, escapeJS(groupName))

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
	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var searchName = '%s';
var matches = Contacts.people.whose({name: {_contains: searchName}});

if (matches.length === 0) {
    null;
} else {
    // Prefer exact match
    var p = matches[0];
    var searchLower = searchName.toLowerCase();
    for (var i = 0; i < matches.length; i++) {
        if ((matches[i].name() || '').toLowerCase() === searchLower) {
            p = matches[i];
            break;
        }
    }
    p.vcard();
}
`, escapeJS(name))

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
	script := fmt.Sprintf(`
var Contacts = Application("Contacts");
var matches = Contacts.people.whose({id: '%s'});

if (matches.length === 0) {
    null;
} else {
    matches[0].vcard();
}
`, escapeJS(id))

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
