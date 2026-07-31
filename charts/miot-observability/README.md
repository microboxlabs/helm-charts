# miot-observability

Optional development observability dependency for the ModularIoT umbrella chart.
It wraps the upstream Langfuse chart and supplies a deliberately small,
single-replica ClickHouse deployment plus the PostgreSQL, Valkey, and MinIO
services required by Langfuse v3.

The chart is disabled by default. Production deployments should use HA or
managed data services and must not inherit these development resource and
replica defaults.
