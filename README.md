# telegraf-qnap-input

Small helper repo for recovering and maintaining Telegraf custom monitoring on QNAP.

## Layout

- `examples/telegraf-qnap-base.conf` - reference/base Telegraf config
- `examples/telegraf-qnap-output.conf` - output drop-in (global host tag + PostgreSQL output, manual password placeholder)
- `examples/telegraf-qnap-metrics.conf` - generic custom metrics drop-in (QNAP collector + nvidia_smi wrapper)
- `examples/telegraf-qnap-uptime-kuma.conf` - optional heartbeat drop-in (Uptime Kuma URL placeholders)
- `examples/telegraf-qnap-smart-net.conf` - optional SMART (`/opt/sbin/smartctl`) + ethtool NIC health metrics
- `examples/telegraf-qnap-observability.conf` - optional Telegraf internal metrics
- `sql/discover-metrics.sql` - helper SQL block to discover existing metric tables for a host
- `sql/capacity-forecast.sql` - helper SQL query estimating days-to-95%-full for a mount path
- `qnap-collector.sh` - custom collector script emitting Influx line protocol
- `nvidia-smi-wrapper` - QPKG wrapper used by `inputs.nvidia_smi`

## Typical deployment notes

1. Copy `examples/telegraf-qnap-output.conf`, `examples/telegraf-qnap-metrics.conf`, and optionally `examples/telegraf-qnap-uptime-kuma.conf` to Telegraf drop-in directory on NAS.

2. Replace placeholders: `__TELEGRAF_HOST_FQDN__` and `__REPLACE_WITH_REAL_PASSWORD__` in `telegraf-qnap-output.conf`; `__UPTIME_KUMA_HOST__` and `__UPTIME_KUMA_PUSH_TOKEN__` in `telegraf-qnap-uptime-kuma.conf` (if used).

3. Keep collector and wrapper paths aligned with your NAS locations: `/mnt/HDA_ROOT/bin/qnap-collector.sh` and `/mnt/HDA_ROOT/bin/nvidia-smi-wrapper`.

4. Optional add-ons: `examples/telegraf-qnap-smart-net.conf`, `examples/telegraf-qnap-observability.conf`.

## Notes

- `inputs.zfs` is intentionally not included due to QNAP-specific implementation differences.
- SMART plugin uses `path = "/opt/sbin/smartctl"`.
- `inputs.filecount` is intentionally not included to avoid recursive directory scans and storage/IO overhead.
- Local `*.out` artifacts (e.g., collector/query outputs, `ip-a.out`) are intentionally gitignored and not part of tracked repository layout.

## TODO

- UPS metrics via NUT plugin when UPS serial/USB connection is available.
