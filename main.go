package main

import "github.com/fishfisher/apple-contacts/cmd"

var (
	version = "dev"
	commit  = "none"
)

func init() {
	cmd.SetVersionInfo(version, commit)
}

func main() {
	cmd.Execute()
}
