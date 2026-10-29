# Reverse Proxy and TLS Architecture

This homelab uses Nginx Proxy Manager as the reverse proxy layer for selected
web services.

The reverse proxy is responsible for:

- accepting HTTP and HTTPS connections;
- selecting the correct virtual host through the requested hostname;
- terminating TLS;
- redirecting HTTP traffic when required;
- forwarding requests to internal services;
- managing Let's Encrypt certificates.

---

## Architecture

```text
Client
  |
  | HTTP / HTTPS
  v
Host ports 80 / 443
  |
  v
Nginx Proxy Manager
  |
  +--> Hostname matching
  +--> TLS termination
  +--> HTTP redirects
  +--> Reverse proxy rules
  |
  v
Internal application
```

The reverse proxy separates public-facing web access from the internal service
network.

---

## Container State

The audited reverse proxy runs in Docker.

Observed state:

```text
Container health: healthy
Restart policy: unless-stopped
```

The container is attached to the internal Docker network used by the services
it proxies.

---

## Published Ports

The reverse proxy publishes the standard web ports:

```text
80/tcp
443/tcp
```

These are used for HTTP and HTTPS traffic.

The administration interface uses:

```text
81/tcp
```

During the audit, the administration port was bound only to a private host
address rather than to every host interface.

This reduces unnecessary exposure of the management interface.

---

## Management Interface

The management interface should not be treated as a public application endpoint.

A safer deployment pattern is:

```text
Internet
   |
   +----> 80 / 443
   |
   X----> 81

Trusted LAN / VPN
   |
   +----> 81
```

This keeps administrative access separate from normal reverse proxy traffic.

---

## Virtual Hosts

Nginx uses the HTTP `Host` header and TLS SNI to determine which virtual host
should handle a request.

A simplified configuration looks like:

```nginx
server {
    listen 80;
    listen 443 ssl;

    server_name example.internal;

    # TLS configuration

    # Reverse proxy configuration
}
```

Real domains and internal addresses are intentionally omitted from this public
repository.

---

## TLS and SNI

TLS connections to a reverse proxy must include the correct hostname.

When several sites share the same IP address, the server uses Server Name
Indication (SNI) to select the correct TLS certificate and virtual host.

Testing HTTPS only against:

```text
https://127.0.0.1/
```

may therefore fail even when the reverse proxy is working correctly.

A more representative local test uses the real hostname while forcing local
resolution:

```bash
curl --resolve example.internal:443:127.0.0.1 \
  https://example.internal/
```

This sends the expected hostname and SNI while still connecting locally.

---

## Audit Result

A local test without the expected hostname initially produced a TLS handshake
failure.

The reverse proxy was then tested again with the correct hostname and SNI.

Observed result:

```text
HTTP:  301
HTTPS: 302
```

This confirmed that the reverse proxy and TLS configuration were operational.

The initial TLS error was therefore caused by the test method rather than by a
broken HTTPS configuration.

---

## HTTP Redirect

The audited HTTP endpoint returned:

```text
301
```

This indicates that the request was redirected.

A common reverse proxy design is:

```text
HTTP request
    |
    v
301 redirect
    |
    v
HTTPS request
```

The exact redirect target is intentionally not included in the public
documentation.

---

## HTTPS Response

Using the correct hostname and SNI, the HTTPS endpoint returned:

```text
302
```

A valid HTTP response confirms that:

- the TLS handshake completed;
- the correct virtual host was selected;
- Nginx accepted the request;
- the configured application flow generated a redirect response.

A redirect response is not itself an error.

---

## Let's Encrypt

The reverse proxy uses Let's Encrypt certificates.

During the audit:

```text
2 certificate directories were present
```

Nginx Proxy Manager periodically checks certificate renewal status.

Recent service logs showed successful certificate renewal checks.

Certificate renewal therefore forms part of the normal reverse proxy
maintenance process.

---

## Certificate Verification

A certificate can be inspected locally with:

```bash
echo | openssl s_client \
  -connect 127.0.0.1:443 \
  -servername example.internal 2>/dev/null |
openssl x509 -noout -dates -issuer
```

This verifies information such as:

```text
notBefore
notAfter
issuer
```

The audited certificate was issued by Let's Encrypt and was within its validity
period.

---

## Health Check

The Nginx Proxy Manager container also has a Docker health check.

This adds application-level visibility beyond simply checking whether the
container process is running.

Example operational check:

```bash
docker inspect <reverse-proxy-container> --format \
'{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}'
```

The audited state was:

```text
healthy
```

---

## Restart Policy

The container uses:

```text
unless-stopped
```

This allows Docker to restart the reverse proxy automatically after host or
Docker restarts unless the administrator intentionally stopped it.

---

## Useful Audit Commands

Check container state:

```bash
docker ps
```

Inspect published ports:

```bash
docker port <reverse-proxy-container>
```

Inspect listening ports on the host:

```bash
sudo ss -lntp
```

Check local HTTP behavior:

```bash
curl -I http://127.0.0.1/
```

Test HTTPS with SNI:

```bash
curl --resolve example.internal:443:127.0.0.1 \
  https://example.internal/
```

Inspect certificate metadata:

```bash
echo | openssl s_client \
  -connect 127.0.0.1:443 \
  -servername example.internal 2>/dev/null |
openssl x509 -noout -dates -issuer
```

---

## Security Principles

The reverse proxy design follows several basic principles:

```text
Public application traffic
        |
     80 / 443
        |
        v
Reverse Proxy
        |
        v
Internal services
```

Administrative access is treated differently:

```text
Trusted network / VPN
        |
        v
Management interface
```

Public repositories should never contain:

- real public domains;
- private network addresses;
- certificate private keys;
- API tokens;
- authentication credentials;
- internal application secrets.

---

## Result

The audited reverse proxy layer provides:

```text
HTTP/HTTPS entry point
        +
TLS termination
        +
SNI virtual host selection
        +
Let's Encrypt certificates
        +
Private management interface
        +
Docker health monitoring
        =
Centralized web ingress layer
```

This provides a controlled entry point for selected homelab web services without
requiring each internal application to manage public TLS independently.
