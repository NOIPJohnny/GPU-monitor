# GPU Monitor

[中文](README.md)

A small Flutter desktop app for querying GPU status across multiple machines over SSH.

![interface](assets/interface-en.png)

## Features

- Reads host entries from `~/.ssh/config`.
- Runs `nvidia-smi` over SSH to query GPU utilization, memory, temperature, and power draw.
- Shows query results by host, with separate states for online, no GPU, error, and loading.
- Expands process details at the bottom of each GPU card, including PID, user, memory usage, elapsed time, and command line.
- Shows per-process SM / MEM utilization on supported Linux hosts; environments without `pmon` support degrade to `N/A`.
- Aggregates idle GPUs by machine and GPU usage by user in the resource overview.
- Supports host selection, manual refresh, auto-refresh interval, light/dark themes, and language switching between English and Chinese.