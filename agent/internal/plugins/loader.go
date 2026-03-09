package plugins

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"
)

type Registry struct {
	plugins []Plugin
}

func NewRegistry(plugins ...Plugin) *Registry {
	registry := &Registry{}
	for _, plugin := range plugins {
		registry.Register(plugin)
	}

	return registry
}

func (r *Registry) Register(plugin Plugin) {
	if plugin == nil {
		return
	}

	r.plugins = append(r.plugins, plugin)
}

func (r *Registry) Execute(ctx context.Context, command Command) error {
	for _, plugin := range r.plugins {
		if plugin.Supports(command) {
			return plugin.Execute(ctx, command)
		}
	}

	return fmt.Errorf("no plugin registered for command %q", command.CommandName())
}

func (r *Registry) Manifests() []Manifest {
	manifests := make([]Manifest, 0, len(r.plugins))
	for _, plugin := range r.plugins {
		manifests = append(manifests, plugin.Manifest())
	}

	return manifests
}

type ExternalPlugin struct {
	manifest   Manifest
	executable string
	args       []string
	workdir    string
	timeout    time.Duration
	env        []string
	logger     *log.Logger
}

type externalManifestFile struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Category    string            `json:"category"`
	Description string            `json:"description"`
	Commands    []string          `json:"commands"`
	Executable  string            `json:"executable"`
	Args        []string          `json:"args"`
	WorkingDir  string            `json:"working_dir"`
	TimeoutMS   int               `json:"timeout_ms"`
	Environment map[string]string `json:"environment"`
}

func LoadExternalPlugins(root string, logger *log.Logger) ([]Plugin, error) {
	if root == "" {
		return nil, nil
	}

	info, err := os.Stat(root)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("plugins directory %q is not a directory", root)
	}

	plugins := make([]Plugin, 0)
	err = filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || !strings.EqualFold(entry.Name(), "plugin.json") {
			return nil
		}

		plugin, err := loadExternalPlugin(path, logger)
		if err != nil {
			return err
		}
		plugins = append(plugins, plugin)
		return nil
	})
	if err != nil {
		return nil, err
	}

	slices.SortFunc(plugins, func(left Plugin, right Plugin) int {
		return strings.Compare(left.ID(), right.ID())
	})

	return plugins, nil
}

func loadExternalPlugin(manifestPath string, logger *log.Logger) (Plugin, error) {
	blob, err := os.ReadFile(manifestPath)
	if err != nil {
		return nil, err
	}

	var document externalManifestFile
	if err := json.Unmarshal(blob, &document); err != nil {
		return nil, fmt.Errorf("parse %s: %w", manifestPath, err)
	}

	if document.ID == "" || document.Name == "" || document.Executable == "" {
		return nil, fmt.Errorf("plugin manifest %s requires id, name, and executable", manifestPath)
	}
	if len(document.Commands) == 0 {
		return nil, fmt.Errorf("plugin manifest %s must declare at least one command", manifestPath)
	}

	manifestDir := filepath.Dir(manifestPath)
	executable, err := resolveExecutable(document.Executable, manifestDir)
	if err != nil {
		return nil, fmt.Errorf("resolve executable for %s: %w", manifestPath, err)
	}

	workdir := manifestDir
	if document.WorkingDir != "" {
		workdir = document.WorkingDir
		if !filepath.IsAbs(workdir) {
			workdir = filepath.Join(manifestDir, workdir)
		}
	}

	timeout := 5 * time.Second
	if document.TimeoutMS > 0 {
		timeout = time.Duration(document.TimeoutMS) * time.Millisecond
	}

	env := make([]string, 0, len(document.Environment))
	for key, value := range document.Environment {
		env = append(env, key+"="+value)
	}
	slices.Sort(env)

	plugin := &ExternalPlugin{
		manifest: Manifest{
			ID:          document.ID,
			Name:        document.Name,
			Category:    document.Category,
			Description: document.Description,
			Commands:    append([]string(nil), document.Commands...),
		},
		executable: executable,
		args:       append([]string(nil), document.Args...),
		workdir:    workdir,
		timeout:    timeout,
		env:        env,
		logger:     logger,
	}

	if logger != nil {
		logger.Printf("loaded external plugin id=%s executable=%s", plugin.ID(), plugin.executable)
	}

	return plugin, nil
}

func resolveExecutable(value string, baseDir string) (string, error) {
	if filepath.IsAbs(value) {
		return value, nil
	}
	if strings.ContainsRune(value, filepath.Separator) || strings.Contains(value, "/") {
		resolved := filepath.Join(baseDir, value)
		if _, err := os.Stat(resolved); err != nil {
			return "", err
		}
		return resolved, nil
	}

	resolved, err := exec.LookPath(value)
	if err != nil {
		return "", err
	}
	return resolved, nil
}

func (p *ExternalPlugin) ID() string {
	return p.manifest.ID
}

func (p *ExternalPlugin) Name() string {
	return p.manifest.Name
}

func (p *ExternalPlugin) Manifest() Manifest {
	return p.manifest
}

func (p *ExternalPlugin) Supports(command Command) bool {
	return slices.Contains(p.manifest.Commands, command.CommandName())
}

func (p *ExternalPlugin) Execute(ctx context.Context, command Command) error {
	timeoutCtx := ctx
	var cancel context.CancelFunc
	if p.timeout > 0 {
		timeoutCtx, cancel = context.WithTimeout(ctx, p.timeout)
		defer cancel()
	}

	payload, err := json.Marshal(command)
	if err != nil {
		return err
	}

	cmd := exec.CommandContext(timeoutCtx, p.executable, p.args...)
	cmd.Dir = p.workdir
	cmd.Env = append(os.Environ(), p.env...)
	cmd.Stdin = bytes.NewReader(payload)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		message := strings.TrimSpace(stderr.String())
		if message == "" {
			message = strings.TrimSpace(stdout.String())
		}
		if message != "" {
			return fmt.Errorf("external plugin %q failed: %w: %s", p.ID(), err, message)
		}
		return fmt.Errorf("external plugin %q failed: %w", p.ID(), err)
	}

	if p.logger != nil {
		output := strings.TrimSpace(stdout.String())
		if output != "" {
			p.logger.Printf("external plugin %s output: %s", p.ID(), output)
		}
	}

	return nil
}
