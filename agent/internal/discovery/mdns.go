package discovery

import (
	"context"
	"log"
	"strconv"
	"sync"

	"github.com/grandcat/zeroconf"
	"openremote/agent/internal/config"
)

type Descriptor struct {
	DeviceName string   `json:"device_name"`
	Host       string   `json:"host"`
	Port       int      `json:"port"`
	Service    string   `json:"service"`
	Domain     string   `json:"domain"`
	TXT        []string `json:"txt"`
}

type Service struct {
	config config.Config
	logger *log.Logger
	mu     sync.Mutex
	server *zeroconf.Server
}

func NewService(cfg config.Config, logger *log.Logger) *Service {
	return &Service{
		config: cfg,
		logger: logger,
	}
}

func (s *Service) Descriptor() Descriptor {
	return Descriptor{
		DeviceName: s.config.DeviceName,
		Host:       s.config.PublicHost,
		Port:       s.config.Port,
		Service:    s.config.ServiceType,
		Domain:     "local.",
		TXT:        s.txtRecords(),
	}
}

func (s *Service) Start(ctx context.Context) error {
	s.mu.Lock()
	server, err := zeroconf.Register(
		s.config.DeviceName,
		s.config.ServiceType,
		"local.",
		s.config.Port,
		s.txtRecords(),
		nil,
	)
	if err != nil {
		s.mu.Unlock()
		return err
	}
	s.server = server
	s.mu.Unlock()

	s.logger.Printf(
		"mDNS advertising service=%s instance=%s port=%d",
		s.config.ServiceType,
		s.config.DeviceName,
		s.config.Port,
	)

	<-ctx.Done()
	s.mu.Lock()
	if s.server != nil {
		s.server.Shutdown()
		s.server = nil
	}
	s.mu.Unlock()
	s.logger.Println("mDNS advertising stopped")

	return nil
}

func (s *Service) txtRecords() []string {
	return []string{
		"app=OpenRemote",
		"ws_path=" + s.config.WebSocketPath,
		"http_port=" + strconv.Itoa(s.config.Port),
	}
}
