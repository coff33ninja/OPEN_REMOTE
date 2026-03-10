package updates

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

type Config struct {
	Repo struct {
		Owner string `json:"owner"`
		Name  string `json:"name"`
	} `json:"repo"`
	Links struct {
		Releases string `json:"releases"`
		Commits  string `json:"commits"`
	} `json:"links"`
	Versions struct {
		Android string `json:"android"`
		Agent   string `json:"agent"`
	} `json:"versions"`
}

func Load() (*Config, error) {
	if path := strings.TrimSpace(os.Getenv("OPENREMOTE_UPDATES_CONFIG")); path != "" {
		return loadFromPath(path)
	}

	for _, candidate := range candidatePaths() {
		cfg, err := loadFromPath(candidate)
		if err == nil && cfg != nil {
			return cfg, nil
		}
	}

	return nil, nil
}

func loadFromPath(path string) (*Config, error) {
	if strings.TrimSpace(path) == "" {
		return nil, nil
	}
	blob, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := json.Unmarshal(blob, &cfg); err != nil {
		return nil, err
	}
	if strings.TrimSpace(cfg.Repo.Owner) == "" && strings.TrimSpace(cfg.Repo.Name) == "" {
		return &cfg, nil
	}
	return &cfg, nil
}

func candidatePaths() []string {
	candidates := make([]string, 0, 8)
	addBase := func(base string) {
		if strings.TrimSpace(base) == "" {
			return
		}
		candidates = append(
			candidates,
			filepath.Join(base, "openremote_updates.json"),
			filepath.Join(base, "android", "assets", "openremote_updates.json"),
			filepath.Join(base, "..", "openremote_updates.json"),
		)
	}

	if workingDir, err := os.Getwd(); err == nil {
		addBase(workingDir)
	}
	if executablePath, err := os.Executable(); err == nil {
		addBase(filepath.Dir(executablePath))
	}

	seen := make(map[string]struct{}, len(candidates))
	unique := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		candidate = filepath.Clean(candidate)
		if _, ok := seen[candidate]; ok {
			continue
		}
		seen[candidate] = struct{}{}
		unique = append(unique, candidate)
	}
	return unique
}
