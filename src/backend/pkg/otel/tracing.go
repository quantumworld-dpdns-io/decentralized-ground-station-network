package otel

import (
	"context"
	"fmt"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.opentelemetry.io/otel/trace"

	"github.com/quantumworld-dpdns-io/dgsn/internal/config"
)

func InitTracerProvider(cfg config.OTELConfig) (*sdktrace.TracerProvider, error) {
	res, err := resource.New(context.Background(),
		resource.WithAttributes(
			semconv.ServiceNameKey.String(cfg.ServiceName),
			attribute.String("service.version", "0.1.0"),
			attribute.String("deployment.environment", "production"),
		),
		resource.WithHost(),
		resource.WithOS(),
	)
	if err != nil {
		return nil, fmt.Errorf("creating resource: %w", err)
	}

	exp, err := newOTLPExporter(cfg)
	if err != nil {
		return nil, fmt.Errorf("creating OTLP exporter: %w", err)
	}

	sampler := sdktrace.ParentBased(sdktrace.TraceIDRatioBased(cfg.SamplingRatio))

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp,
			sdktrace.WithBatchTimeout(time.Duration(cfg.ExportInterval)*time.Second),
			sdktrace.WithMaxExportBatchSize(512),
			sdktrace.WithMaxQueueSize(2048),
		),
		sdktrace.WithSampler(sampler),
		sdktrace.WithResource(res),
	)

	return tp, nil
}

func newOTLPExporter(cfg config.OTELConfig) (*otlptrace.Exporter, error) {
	opts := []otlptracegrpc.Option{
		otlptracegrpc.WithEndpoint(cfg.OTLPEndpoint),
		otlptracegrpc.WithTimeout(10 * time.Second),
	}

	if cfg.Insecure {
		opts = append(opts, otlptracegrpc.WithInsecure())
	}

	client := otlptracegrpc.NewClient(opts...)
	ctx := context.Background()

	exp, err := otlptrace.New(ctx, client)
	if err != nil {
		return nil, fmt.Errorf("initializing OTLP exporter: %w", err)
	}

	return exp, nil
}

func Tracer(name string) trace.Tracer {
	return otel.Tracer(name)
}

func SpanFromContext(ctx context.Context) trace.Span {
	return trace.SpanFromContext(ctx)
}
