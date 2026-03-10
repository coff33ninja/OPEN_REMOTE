//go:build windows

package system

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"sort"
	"strings"
)

type serviceRow struct {
	Name        string `json:"Name"`
	DisplayName string `json:"DisplayName"`
	Status      string `json:"Status"`
	StartType   string `json:"StartType"`
}

func (e *Executor) ListServices() ([]ServiceInfo, error) {
	output, err := runPowerShell(`Get-Service | Select-Object Name,DisplayName,Status,StartType | ConvertTo-Json -Depth 3`)
	if err != nil {
		return nil, err
	}

	rows := make([]serviceRow, 0)
	trimmed := strings.TrimSpace(string(output))
	if trimmed == "" {
		return nil, nil
	}

	if strings.HasPrefix(trimmed, "[") {
		if err := json.Unmarshal([]byte(trimmed), &rows); err != nil {
			return nil, err
		}
	} else {
		var single serviceRow
		if err := json.Unmarshal([]byte(trimmed), &single); err != nil {
			return nil, err
		}
		rows = append(rows, single)
	}

	services := make([]ServiceInfo, 0, len(rows))
	for _, row := range rows {
		services = append(services, ServiceInfo{
			Name:        row.Name,
			DisplayName: row.DisplayName,
			Status:      row.Status,
			StartType:   row.StartType,
		})
	}

	sort.Slice(services, func(i int, j int) bool {
		return strings.ToLower(services[i].Name) < strings.ToLower(services[j].Name)
	})

	return services, nil
}

func (e *Executor) StartService(name string) error {
	_, err := runPowerShell(fmt.Sprintf("Start-Service -Name %s -ErrorAction Stop", psQuote(name)))
	return err
}

func (e *Executor) StopService(name string) error {
	_, err := runPowerShell(fmt.Sprintf("Stop-Service -Name %s -ErrorAction Stop", psQuote(name)))
	return err
}

func (e *Executor) RestartService(name string) error {
	_, err := runPowerShell(fmt.Sprintf("Restart-Service -Name %s -ErrorAction Stop", psQuote(name)))
	return err
}

func runPowerShell(command string) ([]byte, error) {
	output, err := exec.Command(
		"powershell",
		"-NoProfile",
		"-NonInteractive",
		"-Command",
		command,
	).CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("%w: %s", err, strings.TrimSpace(string(output)))
	}
	return output, nil
}

func psQuote(value string) string {
	escaped := strings.ReplaceAll(value, "'", "''")
	return "'" + escaped + "'"
}
