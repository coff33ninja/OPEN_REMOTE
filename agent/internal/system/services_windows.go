//go:build windows

package system

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

type serviceRow struct {
	Name                    string `json:"Name"`
	DisplayName             string `json:"DisplayName"`
	State                   string `json:"State"`
	Status                  string `json:"Status"`
	StartMode               string `json:"StartMode"`
	ExitCode                int    `json:"ExitCode"`
	ServiceSpecificExitCode int    `json:"ServiceSpecificExitCode"`
}

func (e *Executor) ListServices() ([]ServiceInfo, error) {
	output, err := runPowerShell(`Get-CimInstance Win32_Service | Select-Object Name,DisplayName,State,Status,StartMode,ExitCode,ServiceSpecificExitCode | ConvertTo-Json -Depth 3`)
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
		status := strings.TrimSpace(row.State)
		if status == "" {
			status = strings.TrimSpace(row.Status)
		}
		services = append(services, ServiceInfo{
			Name:         row.Name,
			DisplayName:  row.DisplayName,
			Status:       status,
			StatusReason: formatStatusReason(row),
			StartType:    row.StartMode,
		})
	}

	sort.Slice(services, func(i int, j int) bool {
		return strings.ToLower(services[i].Name) < strings.ToLower(services[j].Name)
	})

	return services, nil
}

func formatStatusReason(row serviceRow) string {
	parts := make([]string, 0, 3)
	status := strings.TrimSpace(row.Status)
	if status != "" && !strings.EqualFold(status, "OK") && !strings.EqualFold(status, row.State) {
		parts = append(parts, status)
	}
	if row.ExitCode != 0 {
		parts = append(parts, fmt.Sprintf("ExitCode %d", row.ExitCode))
	}
	if row.ServiceSpecificExitCode != 0 {
		parts = append(parts, fmt.Sprintf("ServiceExit %d", row.ServiceSpecificExitCode))
	}
	return strings.Join(parts, " • ")
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
