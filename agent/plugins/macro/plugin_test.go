package macro

import (
	"context"
	"testing"

	internalplugins "openremote/agent/internal/plugins"
)

func TestMacroPluginExecutesStepsInOrder(t *testing.T) {
	var executed []string
	plugin := New(func(_ context.Context, command internalplugins.Command) error {
		executed = append(executed, command.CommandName())
		return nil
	})

	command := internalplugins.Command{
		Name: "macro_run",
		Arguments: map[string]any{
			"steps": []any{
				map[string]any{"name": "media_toggle"},
				map[string]any{
					"name": "volume_set",
					"arguments": map[string]any{
						"value": 25,
					},
				},
			},
		},
	}

	if err := plugin.Execute(context.Background(), command); err != nil {
		t.Fatalf("Execute() error = %v", err)
	}

	if len(executed) != 2 || executed[0] != "media_toggle" || executed[1] != "volume_set" {
		t.Fatalf("executed = %#v, want [media_toggle volume_set]", executed)
	}
}

func TestMacroPluginRejectsNestedMacro(t *testing.T) {
	plugin := New(func(_ context.Context, _ internalplugins.Command) error {
		return nil
	})

	command := internalplugins.Command{
		Name: "macro_run",
		Arguments: map[string]any{
			"steps": []any{
				map[string]any{"name": "macro_run"},
			},
		},
	}

	if err := plugin.Execute(context.Background(), command); err == nil {
		t.Fatal("Execute() error = nil, want nested macro rejection")
	}
}
