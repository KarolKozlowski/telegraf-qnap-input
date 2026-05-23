# telegraf-qnap-input

Small helper repo for recovering and maintaining Telegraf custom monitoring on QNAP.

## Layout

- `examples/telegraf-qnap-base.conf` - reference/base Telegraf config
- `examples/telegraf-qnap-output.conf` - output drop-in (global host tag + PostgreSQL output, manual password placeholder)
- `examples/telegraf-qnap-metrics.conf` - generic custom metrics drop-in (QNAP collector + nvidia_smi wrapper)
- `examples/telegraf-qnap-uptime-kuma.conf` - optional heartbeat drop-in (Uptime Kuma URL placeholders)
- `sql/discover-metrics.sql` - helper SQL block to discover existing metric tables for a host
- `qnap-collector.sh` - custom collector script emitting Influx line protocol
- `nvidia-smi-wrapper` - QPKG wrapper used by `inputs.nvidia_smi`

## Typical deployment notes

1. Copy `examples/telegraf-qnap-output.conf`, `examples/telegraf-qnap-metrics.conf`, and optionally `examples/telegraf-qnap-uptime-kuma.conf` to Telegraf drop-in directory on NAS.

2. Replace placeholders: `__TELEGRAF_HOST_FQDN__` and `__REPLACE_WITH_REAL_PASSWORD__` in `telegraf-qnap-output.conf`; `__UPTIME_KUMA_HOST__` and `__UPTIME_KUMA_PUSH_TOKEN__` in `telegraf-qnap-uptime-kuma.conf` (if used).

3. Keep collector and wrapper paths aligned with your NAS locations: `/mnt/HDA_ROOT/bin/qnap-collector.sh` and `/mnt/HDA_ROOT/bin/nvidia-smi-wrapper`.

4. If needed, apply diskio tuning from `examples/diskio-qnap-snippet.conf.example` in the active diskio stanza.
