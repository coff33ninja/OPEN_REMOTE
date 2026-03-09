package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"openremote/agent/pkg/pluginsdk"
	plugin_template "openremote/sdk/plugin-template"
)

func main() {
	command := pluginsdk.Command{}
	if err := json.NewDecoder(os.Stdin).Decode(&command); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	plugin := plugin_template.New()
	if !plugin.Supports(command) {
		fmt.Fprintf(os.Stderr, "unsupported command %q\n", command.CommandName())
		os.Exit(1)
	}

	if err := plugin.Execute(context.Background(), command); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
