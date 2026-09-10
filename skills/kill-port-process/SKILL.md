---
name: kill-port-process
description: Close or free a local TCP port by force-killing the process currently listening on it. Use when the user asks to kill, close, stop, free, release, or clear a process by port number, such as freeing port 8080 or killing the service occupying localhost:3000. Works on macOS and Linux without sudo in the common case.
version: 1.0.0
author: xuxzh
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [port, process, kill, network, devops]
---

# Kill Port Process

A surgical devops skill: force-kill whatever process is listening on a given TCP port and report the result. Designed for the case where you hit `EADDRINUSE: address already in use :::3000` and want to recover in two commands without touching unrelated processes.

## When to Use

Use when the user asks to kill, close, stop, free, release, or clear a process by port number — for example:

- "port 3000 is taken, free it"
- "kill whatever is on localhost:8080"
- "I can't start the dev server, something is bound"
- "帮我把端口 5183 占了的服务干掉"

Do **not** use this skill to:

- Kill a process by name (use `pkill`)
- Kill a process by PID directly (use `kill`)
- Manage systemd / launchd services (use `systemctl` / `launchctl`)

## Workflow

### Step 1: Get the Port Number

If the user did not specify a port, ask before running anything. Never guess a port — `kill -9` is destructive and operating on the wrong number can take down a service the user wanted to keep.

### Step 2: Find the Process

Find the PIDs currently listening on the port:

```bash
lsof -ti:<port>
```

`-t` prints only PIDs (terse), `-i` filters by internet address. Example for port 8080:

```bash
lsof -ti:8080
# → 42711
```

If `lsof` is missing on a minimal Linux container, fall back to:

```bash
ss -ltnp 'sport = :<port>' | grep -oP 'pid=\K[0-9]+'
```

### Step 3: Act on the Result

- **Empty output:** tell the user no process is currently listening on that port. Do not run any kill command.
- **One or more PIDs returned:** terminate them:

```bash
kill -9 $(lsof -ti:<port>)
```

Example for port 3000:

```bash
kill -9 $(lsof -ti:3000)
```

### Step 4: Verify

Confirm the port is now free — if anything is still bound, the next dev server start will fail again with `EADDRINUSE`:

```bash
lsof -ti:<port>
```

Expected: empty output.

### Step 5: Report

Tell the user which PID(s) were killed and confirm the port is free. If `kill -9` failed with `Operation not permitted`, explain that sudo is required and ask for explicit confirmation before retrying.

## Safety Rules

- Only operate on the **exact port** requested by the user. Never broaden to a port range, a name, or unrelated PIDs.
- `kill -9` (`SIGKILL`) is destructive — the target cannot trap, log, or shut down cleanly. Prefer `kill <pid>` first; only escalate to `-9` if the process ignores `SIGTERM`.
- Do **not** use `sudo` unless the user explicitly authorizes it. The most common reason escalation is needed is a system-level daemon (LaunchDaemon, systemd service) owned by root — confirm with the user before retrying.
- Never pipe `lsof -ti:<port>` through `xargs` without `--no-run-if-empty` semantics; on macOS, the empty-output guard is implicit because `kill -9` with no args raises an error and short-circuits.
- Do not kill a PID without checking what it is. If `lsof -ti:<port>` returns a PID the user did not expect, surface it and ask before killing.
- Do not operate on privileged ports (`< 1024`) without confirming — these are usually owned by system services.

## Example

User: "kill whatever is on port 3000"

1. `lsof -ti:3000` → `42711`
2. Sanity check: report `PID 42711 will be killed`. If the user hesitates, surface `ps -p 42711 -o pid,command` for confirmation.
3. `kill -9 42711` (or `kill -9 $(lsof -ti:3000)`)
4. `lsof -ti:3000` → empty
5. Response: `Killed PID 42711. Port 3000 is now free.`

## Why Not `pkill -f`?

`pkill -f` matches against the **command line**, not the port. It will hit unrelated processes whose argv happens to contain the port number (e.g. log scrapers, status bars, dev tooling with the port in argv). `lsof -ti:<port>` matches the **kernel-level socket binding**, which is the actual definition of "the process listening on this port".

## Platform Notes

- **macOS:** `lsof` ships by default. `ss` is not installed by default.
- **Linux:** both `lsof` and `ss` are typically present. `ss` is preferred in minimal containers; `lsof` in interactive shells (more readable output).
- **Windows / WSL:** this skill does not target Windows. Inside WSL, both behave as Linux.

## See Also

- `lsof(8)` — list open files, including sockets
- `ss(8)` — investigate sockets (Linux)
- `kill(1)` — terminate processes by PID

## License

MIT — see [LICENSE](./LICENSE).
