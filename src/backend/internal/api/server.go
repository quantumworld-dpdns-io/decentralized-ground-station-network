package api

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	"github.com/quantumworld-dpdns-io/dgsn/internal/config"
)

var (
	ErrServerStopped = errors.New("server stopped")
)

type Server struct {
	cfg         *config.Config
	logger      *slog.Logger
	grpcServer  *grpc.Server
	httpServer  *http.Server
	healthSrv   *health.Server
	handlers    *Handlers
	router      *Router
}

type Handlers struct {
	Stations *StationHandler
	Receipts *ReceiptHandler
	Schedule *ScheduleHandler
	Quantum  *QuantumHandler
	Signal   *SignalHandler
	Health   *HealthHandler
}

type HandlerDependencies struct {
	Stations StationService
	Receipts ReceiptService
	Schedule ScheduleService
	Quantum  QuantumService
	Signal   SignalService
}

func NewServer(cfg *config.Config, logger *slog.Logger, deps *HandlerDependencies) *Server {
	if logger == nil {
		logger = slog.Default()
	}

	s := &Server{
		cfg:    cfg,
		logger: logger,
	}

	s.healthSrv = health.NewServer()

	handlers := &Handlers{
		Stations: NewStationHandler(deps.Stations, logger),
		Receipts: NewReceiptHandler(deps.Receipts, logger),
		Schedule: NewScheduleHandler(deps.Schedule, logger),
		Quantum:  NewQuantumHandler(deps.Quantum, logger),
		Signal:   NewSignalHandler(deps.Signal, logger),
		Health:   NewHealthHandler(logger, cfg),
	}
	s.handlers = handlers

	s.router = NewRouter(handlers, cfg, logger)

	return s
}

func (s *Server) setupGRPC() error {
	var opts []grpc.ServerOption

	if s.cfg.GRPC.MaxRecvMsgSize > 0 {
		opts = append(opts, grpc.MaxRecvMsgSize(s.cfg.GRPC.MaxRecvMsgSize))
	}
	if s.cfg.GRPC.MaxSendMsgSize > 0 {
		opts = append(opts, grpc.MaxSendMsgSize(s.cfg.GRPC.MaxSendMsgSize))
	}

	opts = append(opts,
		grpc.UnaryInterceptor(s.unaryInterceptor()),
		grpc.StreamInterceptor(s.streamInterceptor()),
	)

	s.grpcServer = grpc.NewServer(opts...)

	grpc_health_v1.RegisterHealthServer(s.grpcServer, s.healthSrv)
	s.healthSrv.SetServingStatus("", grpc_health_v1.HealthCheckResponse_SERVING)

	reflection.Register(s.grpcServer)

	return nil
}

func (s *Server) unaryInterceptor() grpc.UnaryServerInterceptor {
	return func(
		ctx context.Context,
		req interface{},
		info *grpc.UnaryServerInfo,
		handler grpc.UnaryHandler,
	) (interface{}, error) {
		start := time.Now()

		resp, err := handler(ctx, req)

		duration := time.Since(start)
		if err != nil {
			s.logger.Warn("grpc request failed",
				slog.String("method", info.FullMethod),
				slog.Duration("duration", duration),
				slog.String("error", err.Error()),
			)
		} else {
			s.logger.Debug("grpc request completed",
				slog.String("method", info.FullMethod),
				slog.Duration("duration", duration),
			)
		}

		return resp, err
	}
}

func (s *Server) streamInterceptor() grpc.StreamServerInterceptor {
	return func(
		srv interface{},
		ss grpc.ServerStream,
		info *grpc.StreamServerInfo,
		handler grpc.StreamHandler,
	) error {
		s.logger.Debug("grpc stream started", slog.String("method", info.FullMethod))
		err := handler(srv, ss)
		if err != nil {
			s.logger.Warn("grpc stream failed",
				slog.String("method", info.FullMethod),
				slog.String("error", err.Error()),
			)
		}
		return err
	}
}

func (s *Server) setupHTTP() error {
	handler := s.router.Build()

	s.httpServer = &http.Server{
		Addr:         fmt.Sprintf(":%d", s.cfg.HTTP.Port),
		Handler:      handler,
		ReadTimeout:  time.Duration(s.cfg.HTTP.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(s.cfg.HTTP.WriteTimeout) * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	return nil
}

func (s *Server) Start(ctx context.Context) error {
	if err := s.setupGRPC(); err != nil {
		return fmt.Errorf("setting up grpc server: %w", err)
	}

	if err := s.setupHTTP(); err != nil {
		return fmt.Errorf("setting up http server: %w", err)
	}

	grpcLis, err := net.Listen("tcp", fmt.Sprintf(":%d", s.cfg.GRPC.Port))
	if err != nil {
		return fmt.Errorf("listening on grpc port %d: %w", s.cfg.GRPC.Port, err)
	}

	errChan := make(chan error, 2)

	go func() {
		s.logger.Info("grpc server starting", slog.Int("port", s.cfg.GRPC.Port))
		if err := s.grpcServer.Serve(grpcLis); err != nil && err != grpc.ErrServerStopped {
			errChan <- fmt.Errorf("grpc server error: %w", err)
		}
	}()

	go func() {
		s.logger.Info("http server starting", slog.Int("port", s.cfg.HTTP.Port))
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errChan <- fmt.Errorf("http server error: %w", err)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)

	select {
	case sig := <-sigChan:
		s.logger.Info("received signal, shutting down", slog.String("signal", sig.String()))
	case err := <-errChan:
		s.logger.Error("server error", slog.String("error", err.Error()))
		s.Stop(context.Background())
		return err
	case <-ctx.Done():
		s.logger.Info("context cancelled, shutting down")
	}

	return s.Stop(context.Background())
}

func (s *Server) Stop(ctx context.Context) error {
	stopCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	s.healthSrv.Shutdown()

	if s.grpcServer != nil {
		s.logger.Info("stopping grpc server gracefully")
		s.grpcServer.GracefulStop()
	}

	if s.httpServer != nil {
		s.logger.Info("stopping http server gracefully")
		if err := s.httpServer.Shutdown(stopCtx); err != nil {
			return fmt.Errorf("http server shutdown error: %w", err)
		}
	}

	s.logger.Info("server stopped gracefully")
	return nil
}

func (s *Server) GRPCServer() *grpc.Server {
	return s.grpcServer
}

func (s *Server) HTTPServer() *http.Server {
	return s.httpServer
}

func grpcHandlerFunc(grpcServer *grpc.Server, otherHandler http.Handler) http.Handler {
	return h2c.NewHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor == 2 && r.Header.Get("Content-Type") == "application/grpc" {
			grpcServer.ServeHTTP(w, r)
		} else {
			otherHandler.ServeHTTP(w, r)
		}
	}), &http2.Server{})
}

func NewGatewayMux() *runtime.ServeMux {
	return runtime.NewServeMux(
		runtime.WithMarshalerOption(runtime.MIMEWildcard, &runtime.JSONPb{}),
	)
}

func DialGRPC(ctx context.Context, endpoint string, tlsCfg *tls.Config) (*grpc.ClientConn, error) {
	var opts []grpc.DialOption

	if tlsCfg != nil {
		opts = append(opts, grpc.WithTransportCredentials(credentials.NewTLS(tlsCfg)))
	} else {
		opts = append(opts, grpc.WithTransportCredentials(insecure.NewCredentials()))
	}

	opts = append(opts,
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(4*1024*1024),
			grpc.MaxCallSendMsgSize(4*1024*1024),
		),
	)

	conn, err := grpc.DialContext(ctx, endpoint, opts...)
	if err != nil {
		return nil, fmt.Errorf("dialing grpc endpoint %s: %w", endpoint, err)
	}

	return conn, nil
}
