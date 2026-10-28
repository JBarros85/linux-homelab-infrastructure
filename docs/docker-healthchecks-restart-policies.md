# Docker Health Checks and Restart Policies

This homelab uses Docker health checks and restart policies to improve service
visibility and resilience.

The goal is to distinguish between:

- a container that is merely running;
- a container whose internal service is actually responding;
- a service that should automatically restart after failure or host reboot.

---

## Audited State

During the audit:

```text
28 running containers
27 containers with health checks
1 container without a health check
0 unhealthy containers
```

The remaining container without a health check is managed by a separate
deployment mechanism and was intentionally left unchanged.

---

## Why Health Checks Matter

Docker can report a container as running even when the application inside it is
not working correctly.

A health check adds an application-level verification.

Example:

```text
Container process running
        |
        v
Health check executes
        |
    +---+---+
    |       |
 success   failure
    |       |
 healthy   retry
            |
            v
        unhealthy
```

This provides better operational visibility than checking container uptime
alone.

---

## Health Check Methods

Different applications require different verification methods.

The homelab currently uses several approaches.

### HTTP endpoint

Web applications can be checked through an internal HTTP request:

```yaml
healthcheck:
  test:
    - CMD-SHELL
    - curl -fsS http://127.0.0.1:<port>/ >/dev/null || exit 1
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 60s
```

### wget-based HTTP check

Containers without `curl` can use `wget`:

```yaml
healthcheck:
  test:
    - CMD-SHELL
    - wget -q -O /dev/null http://127.0.0.1:<port>/ || exit 1
```

### TCP or protocol-level check

Services without an HTTP interface can be checked using a native protocol
client or TCP connection.

For example, an MQTT broker can verify its own broker status through an MQTT
subscription instead of relying only on the container process.

---

## Health Checks Added During Audit

Four running services were found without Docker health checks even though each
provided a reliable internal endpoint or protocol check.

Health checks were added for:

```text
Seerr
Nginx Proxy Manager
Home Assistant
Mosquitto
```

Each check was tested from inside the respective container before changing the
Compose configuration.

This avoided assuming that tools such as `curl`, `wget`, or protocol clients
were available.

---

## Validation Before Deployment

Each Docker Compose configuration was validated before recreating services:

```bash
docker compose config -q
```

The affected Compose projects all passed validation successfully.

Only the modified services were recreated.

This reduces unnecessary disruption to unrelated containers.

---

## Verification After Deployment

After recreation, every newly configured service reached:

```text
health=healthy
failing=0
```

The server also reported:

```text
0 unhealthy containers
```

The full running environment was then checked again to identify any remaining
containers without health monitoring.

---

## Restart Policies

Health checks and restart policies solve different problems.

A health check determines whether the application is working.

A restart policy determines when Docker should restart a stopped container.

The environment primarily uses:

```text
restart: unless-stopped
```

Some application stacks use:

```text
restart: always
```

### `unless-stopped`

Useful for long-running homelab services:

```yaml
restart: unless-stopped
```

The container starts again after Docker or the host restarts unless it was
explicitly stopped by the administrator.

### `always`

Some application stacks define:

```yaml
restart: always
```

Docker attempts to restart the container whenever it stops.

---

## Health Check and Restart Policy Are Independent

A common misconception is that Docker automatically restarts a container when
its health status becomes `unhealthy`.

A Docker health check only changes health state:

```text
starting
healthy
unhealthy
```

Restart policies react to the container process stopping, not directly to an
`unhealthy` status.

Additional monitoring or orchestration is required if automatic remediation
based on health status is desired.

---

## Useful Audit Commands

List running containers and status:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

Show unhealthy containers:

```bash
docker ps --filter health=unhealthy \
  --format '{{.Names}} | {{.Status}}'
```

Inspect one container health state:

```bash
docker inspect <container> --format \
'{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}'
```

Inspect restart policy:

```bash
docker inspect <container> --format \
'{{.HostConfig.RestartPolicy.Name}}'
```

---

## Operational Principle

The monitoring model is:

```text
Container runtime state
        +
Application health check
        +
Restart policy
        +
External health reporting
        =
Improved service visibility
```

Docker health checks provide local application-state information, while the
homelab monitoring layer can use that information for alerts and reports.

---

## Security and Privacy

Public documentation should not include:

- private IP addresses;
- internal hostnames;
- credentials;
- environment-variable values;
- tokens;
- application secrets;
- private filesystem paths.

Health check examples in this repository therefore use generic ports and
sanitized values.

---

## Result

After the audit and remediation:

```text
27 of 28 running containers have health checks
0 containers are unhealthy
all running containers have restart policies
```

The only remaining container without a health check is managed outside the
audited Docker Compose configurations and was intentionally left unchanged
until its deployment mechanism is reviewed separately.
