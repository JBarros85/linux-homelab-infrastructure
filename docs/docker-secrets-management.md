# Docker Secrets Management

## Overview

Self-hosted applications frequently require sensitive configuration such as:

- Database passwords
- API tokens
- Application secrets
- JWT signing keys
- Administrative credentials

These values should not be stored directly in public Docker Compose files or committed to Git.

This homelab separates sensitive configuration from infrastructure definitions using local environment files that are excluded from version control.

## Problem

A Compose file can technically contain credentials directly:

```yaml
services:
  database:
    environment:
      MYSQL_ROOT_PASSWORD: example-password
```

This is convenient, but creates unnecessary risk.

If the Compose file is:

```text
committed to Git
shared
backed up to an insecure location
copied for troubleshooting
```

the credential travels with it.

## Current Strategy

The homelab separates configuration into:

```text
docker-compose.yml
        |
        +---- normal configuration
        |
        +---- env_file
                 |
                 v
           local secrets file
```

Example:

```yaml
services:
  database:
    env_file:
      - ./secrets/database.env
```

The local file can then contain:

```text
DB_ROOT_PASSWORD=<secret>
DB_PASSWORD=<secret>
```

The actual values are never included in the public repository.

## Example Directory Layout

```text
application/
├── docker-compose.yml
├── .env
└── secrets/
    ├── database.env
    └── application.env
```

Public repositories should contain only sanitized examples:

```text
application/
├── docker-compose.example.yml
└── .env.example
```

## Git Protection

Sensitive files must be excluded from Git.

Example `.gitignore` rules:

```gitignore
.env
.env.*
!.env.example

secrets/
*.key
*.pem
```

The exception:

```text
!.env.example
```

allows a safe template to be committed while keeping real environment files private.

## Safe Example File

A public example can document which variables are required:

```text
DB_ROOT_PASSWORD=CHANGE_ME
DB_PASSWORD=CHANGE_ME
JWT_SECRET=CHANGE_ME
```

This provides documentation without publishing working credentials.

## File Permissions

Local secret files should not be unnecessarily readable by other users.

Example:

```bash
chmod 600 secrets/database.env
```

Inspect permissions with:

```bash
ls -l secrets/
```

The appropriate permissions depend on how the containers and deployment process access the files.

## Credential Rotation

If a secret may have been exposed, simply deleting it from the current Compose file is not sufficient.

The credential itself should be rotated.

General workflow:

```text
1. Identify the exposed credential
2. Generate a replacement
3. Update the local secret file
4. Update dependent applications
5. Restart only the required services
6. Verify authentication
7. Revoke or remove the previous credential
8. Check that the secret is not present in tracked files
```

## Dependent Services

Some secrets must match between multiple applications.

For example:

```text
Application A
     |
     | shared authentication secret
     v
Application B
```

When rotating such a value, every dependent service must receive the same new secret before validation is complete.

This is especially relevant for:

```text
database credentials
JWT secrets
API tokens
service-to-service authentication
```

## Docker Compose Verification

Before restarting services after a configuration change, the Compose configuration can be validated with:

```bash
docker compose config --quiet
```

Be careful when using:

```bash
docker compose config
```

because the expanded output may contain resolved environment values.

Avoid copying expanded configuration into:

```text
GitHub issues
documentation
chat messages
public logs
```

without reviewing it first.

## Verify Running Containers

After rotating credentials:

```bash
docker compose ps
```

Inspect only the required service logs:

```bash
docker compose logs --tail=100 <service>
```

Then verify the actual application functionality.

A running container alone does not prove that authentication between dependent services is working.

## Git Verification

Check which files are tracked:

```bash
git ls-files
```

Check the working tree:

```bash
git status
```

Search tracked files for common sensitive terms:

```bash
git grep -Ei \
'password|passwd|secret|token|api[_-]?key|private[_-]?key'
```

Matches are not automatically security problems.

For example:

```text
PASSWORD=CHANGE_ME
JWT_SECRET=${JWT_SECRET}
```

can be legitimate documentation.

Every result should be reviewed manually.

## Check Whether a Secret File Is Ignored

Example:

```bash
git check-ignore -v secrets/database.env
```

A correctly ignored secret file should report the `.gitignore` rule responsible for excluding it.

## Important Git Limitation

Adding a secret to `.gitignore` does not remove it from Git history if it was committed previously.

Conceptually:

```text
Secret committed
      |
      v
Git history
      |
      +---- still exists after deleting current file
```

If a real credential was previously published, the safest first action is:

```text
ROTATE THE CREDENTIAL
```

History cleanup may also be appropriate, but rewriting Git history is not a substitute for credential rotation.

## Environment Variables Are Not Encryption

Moving credentials into an environment file improves separation and prevents accidental publication when configured correctly.

It does not encrypt the secret.

Users with sufficient access to the host or running container may still be able to inspect environment data.

The protection model therefore also depends on:

```text
host access control
file permissions
SSH security
user privileges
container security
backup security
```

## Public Repository Policy

Before committing infrastructure configuration, verify that it does not contain:

- Passwords
- Real API keys
- JWT secrets
- Private keys
- VPN private keys
- Database credentials
- Session secrets
- Authentication tokens

Public examples use placeholders such as:

```text
CHANGE_ME
<secret>
<token>
<password>
```

## Practical Pre-Commit Check

A simple review before publishing:

```bash
git diff --check
git diff --cached
git status
```

Then inspect specifically for suspicious strings:

```bash
git diff --cached | \
grep -Ei 'password|passwd|secret|token|api[_-]?key|private[_-]?key' || true
```

Any match should be reviewed before pushing.

## Security Model

The strategy can be summarized as:

```text
Public repository
      |
      +---- Compose examples
      +---- variable names
      +---- documentation
      |
      X
      |
      +---- real passwords
      +---- tokens
      +---- private keys
      +---- application secrets

Local host
      |
      +---- protected secret files
             |
             v
         Docker Compose
             |
             v
          Services
```

## Lessons Learned

Secrets management is not only about hiding passwords from a Compose file.

A complete process includes:

```text
separation
+
Git exclusion
+
access permissions
+
credential rotation
+
dependency validation
+
publication review
```

The most important rule is simple:

> If a real secret may have been exposed, assume it is compromised and rotate it.

Removing the value from the latest version of a file is not enough.
