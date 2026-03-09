package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestResolveAssetDirPrefersCurrentWorkspaceLayout(t *testing.T) {
	root := t.TempDir()
	agentDir := filepath.Join(root, "agent")
	remotesDir := filepath.Join(root, "remotes")

	if err := os.MkdirAll(agentDir, 0o755); err != nil {
		t.Fatalf("MkdirAll(agent) error = %v", err)
	}
	if err := os.MkdirAll(remotesDir, 0o755); err != nil {
		t.Fatalf("MkdirAll(remotes) error = %v", err)
	}

	restoreWorkingDir := withWorkingDir(t, agentDir)
	defer restoreWorkingDir()

	resolved := resolveAssetDir("OPENREMOTE_REMOTES_DIR", "remotes")
	if resolved != filepath.Clean(remotesDir) {
		t.Fatalf("resolveAssetDir() = %q, want %q", resolved, filepath.Clean(remotesDir))
	}
}

func TestLoadHonorsDeviceNameOverride(t *testing.T) {
	t.Setenv("OPENREMOTE_DEVICE_NAME", "Desk Agent")
	t.Setenv("OPENREMOTE_PUBLIC_HOST", "127.0.0.1")
	t.Setenv("OPENREMOTE_REMOTES_DIR", filepath.Join(t.TempDir(), "remotes"))
	t.Setenv("OPENREMOTE_PLUGINS_DIR", filepath.Join(t.TempDir(), "plugins"))

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.DeviceName != "Desk Agent" {
		t.Fatalf("DeviceName = %q, want %q", cfg.DeviceName, "Desk Agent")
	}
}

func withWorkingDir(t *testing.T, target string) func() {
	t.Helper()

	original, err := os.Getwd()
	if err != nil {
		t.Fatalf("Getwd() error = %v", err)
	}
	if err := os.Chdir(target); err != nil {
		t.Fatalf("Chdir(%q) error = %v", target, err)
	}

	return func() {
		if err := os.Chdir(original); err != nil {
			t.Fatalf("restore working directory error = %v", err)
		}
	}
}
