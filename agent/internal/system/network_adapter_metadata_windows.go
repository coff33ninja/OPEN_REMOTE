//go:build windows

package system

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

type adapterMetadata struct {
	FriendlyName string
	Description  string
	Kind         string
	IsVirtual    bool
}

type rawAdapterMetadata struct {
	IfIndex              int    `json:"ifIndex"`
	Name                 string `json:"Name"`
	InterfaceAlias       string `json:"InterfaceAlias"`
	InterfaceDescription string `json:"InterfaceDescription"`
	Virtual              bool   `json:"Virtual"`
	HardwareInterface    bool   `json:"HardwareInterface"`
	MediaType            string `json:"MediaType"`
	PhysicalMediaType    string `json:"PhysicalMediaType"`
}

func loadAdapterMetadata() (map[int]adapterMetadata, error) {
	command, err := lookupAdapterMetadataCommand()
	if err != nil {
		return nil, err
	}

	script := "$ErrorActionPreference='Stop'; Get-NetAdapter -IncludeHidden | Select-Object ifIndex,Name,InterfaceAlias,InterfaceDescription,Virtual,HardwareInterface,MediaType,PhysicalMediaType | ConvertTo-Json -Compress"
	output, err := exec.Command(command, "-NoProfile", "-Command", script).CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("load adapter metadata: %w: %s", err, strings.TrimSpace(string(output)))
	}

	return parseAdapterMetadataJSON(output)
}

func lookupAdapterMetadataCommand() (string, error) {
	for _, candidate := range []string{"powershell", "pwsh"} {
		if path, err := exec.LookPath(candidate); err == nil {
			return path, nil
		}
	}

	return "", fmt.Errorf("powershell was not found on PATH")
}

func parseAdapterMetadataJSON(blob []byte) (map[int]adapterMetadata, error) {
	trimmed := strings.TrimSpace(string(blob))
	if trimmed == "" || trimmed == "null" {
		return map[int]adapterMetadata{}, nil
	}

	var rawList []rawAdapterMetadata
	if err := json.Unmarshal([]byte(trimmed), &rawList); err != nil {
		var single rawAdapterMetadata
		if singleErr := json.Unmarshal([]byte(trimmed), &single); singleErr != nil {
			return nil, err
		}
		rawList = []rawAdapterMetadata{single}
	}

	metadata := make(map[int]adapterMetadata, len(rawList))
	for _, item := range rawList {
		if item.IfIndex <= 0 {
			continue
		}

		friendlyName := strings.TrimSpace(item.InterfaceAlias)
		if friendlyName == "" {
			friendlyName = strings.TrimSpace(item.Name)
		}
		description := strings.TrimSpace(item.InterfaceDescription)
		kind, defaultDescription, isVirtual := classifyInterfaceWithSignals(
			firstNonEmpty(friendlyName, item.Name),
			strings.Join(
				[]string{
					strings.TrimSpace(item.InterfaceDescription),
					strings.TrimSpace(item.MediaType),
					strings.TrimSpace(item.PhysicalMediaType),
				},
				" ",
			),
			item.Virtual || !item.HardwareInterface,
		)
		if description == "" {
			description = defaultDescription
		}

		metadata[item.IfIndex] = adapterMetadata{
			FriendlyName: firstNonEmpty(friendlyName, item.Name),
			Description:  description,
			Kind:         kind,
			IsVirtual:    isVirtual,
		}
	}

	return metadata, nil
}
