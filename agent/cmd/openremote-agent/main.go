package main

import (
	"context"
	"errors"
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
	logger := log.New(os.Stdout, "openremote-agent ", log.LstdFlags)

	cfg, err := config.Load()
	if err != nil {
		logger.Fatal(err)
	}

	executor := system.NewExecutor(logger)
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

	discoveryService := discovery.NewService(cfg, logger)
	application := server.NewApplication(logger, cfg, registry, pairingManager, authorizer, discoveryService, executor)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	if err := application.ListenAndServe(ctx); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Fatal(err)
	}
}
