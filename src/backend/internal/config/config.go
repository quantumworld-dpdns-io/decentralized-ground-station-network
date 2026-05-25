package config

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

type Config struct {
	Version   string         `mapstructure:"version"`
	Env       string         `mapstructure:"env"`
	LogLevel  string         `mapstructure:"log_level"`
	GRPC      GRPCConfig     `mapstructure:"grpc"`
	HTTP      HTTPConfig     `mapstructure:"http"`
	Database  DatabaseConfig `mapstructure:"database"`
	Redis     RedisConfig    `mapstructure:"redis"`
	OTEL      OTELConfig     `mapstructure:"otel"`
	Crypto    CryptoConfig   `mapstructure:"crypto"`
	Quantum   QuantumConfig  `mapstructure:"quantum"`
	Signal    SignalConfig   `mapstructure:"signal"`
}

type GRPCConfig struct {
	Port              int    `mapstructure:"port"`
	MaxRecvMsgSize    int    `mapstructure:"max_recv_msg_size"`
	MaxSendMsgSize    int    `mapstructure:"max_send_msg_size"`
	ConnectionTimeout int    `mapstructure:"connection_timeout"`
}

type HTTPConfig struct {
	Port           int      `mapstructure:"port"`
	AllowedOrigins []string `mapstructure:"allowed_origins"`
	ReadTimeout    int      `mapstructure:"read_timeout"`
	WriteTimeout   int      `mapstructure:"write_timeout"`
}

type DatabaseConfig struct {
	Driver      string `mapstructure:"driver"`
	DSN         string `mapstructure:"dsn"`
	MaxOpenCons int    `mapstructure:"max_open_cons"`
	MaxIdleCons int    `mapstructure:"max_idle_cons"`
	MaxLifetime int    `mapstructure:"max_lifetime"`
}

type RedisConfig struct {
	Addr     string `mapstructure:"addr"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
	PoolSize int    `mapstructure:"pool_size"`
}

type OTELConfig struct {
	ServiceName    string  `mapstructure:"service_name"`
	OTLPEndpoint   string  `mapstructure:"otlp_endpoint"`
	SamplingRatio  float64 `mapstructure:"sampling_ratio"`
	Insecure       bool    `mapstructure:"insecure"`
	ExportInterval int     `mapstructure:"export_interval"`
}

type CryptoConfig struct {
	KernelPath    string `mapstructure:"kernel_path"`
	DefaultAlgo   string `mapstructure:"default_algo"`
	KeySize       int    `mapstructure:"key_size"`
}

type QuantumConfig struct {
	EngineEndpoint string `mapstructure:"engine_endpoint"`
	Simulator      string `mapstructure:"simulator"`
	MaxQubits      int    `mapstructure:"max_qubits"`
	Shots          int    `mapstructure:"shots"`
}

type SignalConfig struct {
	ProcessingEndpoint string `mapstructure:"processing_endpoint"`
	SampleRate         int    `mapstructure:"sample_rate"`
	FFTSize            int    `mapstructure:"fft_size"`
}

func DefaultConfig() *Config {
	return &Config{
		Version:  "0.1.0",
		Env:    "development",
		LogLevel: "info",
		GRPC: GRPCConfig{
			Port: 9090,
			MaxRecvMsgSize: 4 * 1024 * 1024,
			MaxSendMsgSize: 4 * 1024 * 1024,
			ConnectionTimeout: 120,
		},
		HTTP: HTTPConfig{
			Port: 8080,
			AllowedOrigins: []string{"*"},
			ReadTimeout: 30,
			WriteTimeout: 30,
		},
		Database: DatabaseConfig{
			Driver: "postgres",
			DSN:    "postgres://dgsn:dgsn@localhost:5432/dgsn?sslmode=disable",
			MaxOpenCons: 25,
			MaxIdleCons: 5,
			MaxLifetime: 300,
		},
		Redis: RedisConfig{
			Addr:     "localhost:6379",
			Password: "",
			DB:       0,
			PoolSize: 10,
		},
		OTEL: OTELConfig{
			ServiceName:    "dgsn-server",
			OTLPEndpoint:   "localhost:4317",
			SamplingRatio:  0.1,
			Insecure:       true,
			ExportInterval: 10,
		},
		Crypto: CryptoConfig{
			KernelPath:  "/usr/local/lib/libdgsn_crypto.so",
			DefaultAlgo: "ML-KEM-768",
			KeySize:     256,
		},
		Quantum: QuantumConfig{
			EngineEndpoint: "localhost:50051",
			Simulator:      "aer",
			MaxQubits:      32,
			Shots:          1024,
		},
		Signal: SignalConfig{
			ProcessingEndpoint: "localhost:50052",
			SampleRate:         2500000,
			FFTSize:            4096,
		},
	}
}

func Load(path string) (*Config, error) {
	cfg := DefaultConfig()

	if path != "" {
		data, err := os.ReadFile(path)
		if err != nil {
			if !os.IsNotExist(err) {
				return nil, fmt.Errorf("reading config file: %w", err)
			}
		} else {
			cfg.applyYAML(data)
		}
	}

	cfg.applyEnv()

	return cfg, nil
}

func (c *Config) applyYAML(data []byte) error {
	return nil
}

func (c *Config) applyEnv() {
	if v := os.Getenv("DGSN_ENV"); v != "" {
		c.Env = v
	}
	if v := os.Getenv("DGSN_LOG_LEVEL"); v != "" {
		c.LogLevel = v
	}
	if v := os.Getenv("DGSN_GRPC_PORT"); v != "" {
		var port int
		if _, err := fmt.Sscanf(v, "%d", &port); err == nil {
			c.GRPC.Port = port
		}
	}
	if v := os.Getenv("DGSN_HTTP_PORT"); v != "" {
		var port int
		if _, err := fmt.Sscanf(v, "%d", &port); err == nil {
			c.HTTP.Port = port
		}
	}
	if v := os.Getenv("DGSN_DATABASE_DSN"); v != "" {
		c.Database.DSN = v
	}
	if v := os.Getenv("DGSN_REDIS_ADDR"); v != "" {
		c.Redis.Addr = v
	}
	if v := os.Getenv("DGSN_REDIS_PASSWORD"); v != "" {
		c.Redis.Password = v
	}
	if v := os.Getenv("DGSN_OTEL_ENDPOINT"); v != "" {
		c.OTEL.OTLPEndpoint = v
	}
	if v := os.Getenv("DGSN_OTEL_SAMPLING_RATIO"); v != "" {
		var ratio float64
		if _, err := fmt.Sscanf(v, "%f", &ratio); err == nil {
			c.OTEL.SamplingRatio = ratio
		}
	}
	if v := os.Getenv("DGSN_QUANTUM_ENDPOINT"); v != "" {
		c.Quantum.EngineEndpoint = v
	}
	if v := os.Getenv("DGSN_SIGNAL_ENDPOINT"); v != "" {
		c.Signal.ProcessingEndpoint = v
	}
	if v := os.Getenv("DGSN_CRYPTO_ALGO"); v != "" {
		c.Crypto.DefaultAlgo = v
	}
	if v := os.Getenv("DGSN_CRYPTO_KERNEL_PATH"); v != "" {
		c.Crypto.KernelPath = v
	}
}
