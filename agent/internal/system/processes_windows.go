//go:build windows

package system

import (
	"encoding/csv"
	"os/exec"
	"strconv"
	"strings"
)

func (e *Executor) ListProcesses() ([]ProcessInfo, error) {
	output, err := exec.Command("tasklist", "/FO", "CSV", "/NH").Output()
	if err != nil {
		return nil, err
	}

	reader := csv.NewReader(strings.NewReader(string(output)))
	rows, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}

	processes := make([]ProcessInfo, 0, len(rows))
	for _, row := range rows {
		if len(row) < 5 {
			continue
		}

		pid, _ := strconv.Atoi(row[1])
		processes = append(processes, ProcessInfo{
			Name:       row[0],
			PID:        pid,
			Session:    row[2],
			SessionNum: row[3],
			Memory:     row[4],
		})
	}

	return processes, nil
}

func (e *Executor) TerminateProcess(pid int) error {
	return exec.Command("taskkill", "/PID", strconv.Itoa(pid), "/F").Run()
}
