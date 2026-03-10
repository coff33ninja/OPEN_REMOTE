package main

import (
	"context"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"openremote/agent/internal/config"
	"openremote/agent/internal/discovery"
	"openremote/agent/internal/pairing"
	coreplugins "openremote/agent/internal/plugins"
	"openremote/agent/internal/server"
	"openremote/agent/internal/system"
	pluginkeyboard "openremote/agent/plugins/keyboard"
	pluginmacro "openremote/agent/plugins/macro"
	pluginmedia "openremote/agent/plugins/media"
	pluginmouse "openremote/agent/plugins/mouse"
	pluginpower "openremote/agent/plugins/power"
	pluginpresentation "openremote/agent/plugins/presentation"
	pluginvolume "openremote/agent/plugins/volume"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		logger := log.New(os.Stdout, "openremote-agent ", log.LstdFlags)
		logger.Fatal(err)
	}

	logDir := filepath.Join(cfg.DataDir, "logs")
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		logger := log.New(os.Stdout, "openremote-agent ", log.LstdFlags)
		logger.Fatal(err)
	}

	agentLogPath := filepath.Join(logDir, "agent.log")
	agentLogFile, err := os.OpenFile(agentLogPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		logger := log.New(os.Stdout, "openremote-agent ", log.LstdFlags)
		logger.Fatalf("open agent log failed: %v", err)
	}
	defer agentLogFile.Close()

	clientLogPath := filepath.Join(logDir, "client.log")
	clientLogFile, err := os.OpenFile(clientLogPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		logger := log.New(os.Stdout, "openremote-agent ", log.LstdFlags)
		logger.Fatalf("open client log failed: %v", err)
	}
	defer clientLogFile.Close()

	logger := log.New(io.MultiWriter(os.Stdout, agentLogFile), "openremote-agent ", log.LstdFlags)
	clientLogger := log.New(clientLogFile, "openremote-client ", log.LstdFlags)

	executor := system.NewExecutor(logger)
	executor.ConfigureWakeTarget(cfg.PublicHost, system.WakeTarget{
		MAC:       cfg.WakeMAC,
		Broadcast: cfg.WakeBroadcast,
		Port:      cfg.WakePort,
	})
	registry := coreplugins.NewRegistry(
		pluginmouse.New(executor),
		pluginkeyboard.New(executor),
		pluginmedia.New(executor),
		pluginvolume.New(executor),
		pluginpower.New(executor),
		pluginpresentation.New(executor),
	)
	registry.Register(pluginmacro.New(registry.Execute))

	externalPlugins, err := coreplugins.LoadExternalPlugins(cfg.PluginsDir, logger)
	if err != nil {
		logger.Fatal(err)
	}
	for _, plugin := range externalPlugins {
		registry.Register(plugin)
	}

	pairingManager := pairing.NewManager(cfg.PairingTTL, cfg.PairingScheme)
	authorizer, err := server.NewAuthorizer(filepath.Join(cfg.DataDir, "trusted-devices.json"))
	if err != nil {
		logger.Fatal(err)
	}

	discoveryService := discovery.NewService(cfg, logger, executor.WakeTarget())
	application := server.NewApplication(
		logger,
		clientLogger,
		cfg,
		registry,
		pairingManager,
		authorizer,
		discoveryService,
		executor,
	)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	if err := application.ListenAndServe(ctx); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Fatal(err)
	}
}
