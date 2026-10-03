# Homelab Maintenance Checklist

## Daily / Frequent Checks

- Verify Docker containers are running
- Check critical service health
- Review available disk space
- Confirm RAID1 status is healthy
- Check recent backup execution
- Review important system alerts

## Weekly Checks

- Review UFW firewall rules
- Check Fail2Ban status
- Review SMART disk health
- Verify Borg backup repository
- Check system updates
- Review Docker container logs for recurring errors

## Monthly Checks

- Review exposed ports
- Remove obsolete firewall rules
- Review unused Docker containers and images
- Confirm VPN access is working
- Test access to important services
- Review storage usage growth
- Confirm backup retention is working as expected

## Security Review

- Keep SSH restricted to trusted networks
- Keep databases inaccessible from public interfaces
- Verify secrets are not stored in Git
- Review reverse proxy configuration
- Remove unused services
- Rotate credentials when necessary
- Review authentication logs

## Storage Review

Check:

- RAID1 health
- SMART attributes
- Filesystem usage
- Backup disk health
- Borg repository integrity

## Backup Review

A backup is only useful if it can be restored.

Periodically:

- Check the last successful backup
- Run repository verification
- Perform a test restore to a temporary directory
- Confirm important files are included

## Documentation

Update the repository when infrastructure changes, including:

- Network architecture
- Firewall rules
- Storage configuration
- Backup strategy
- Docker services
- Security controls

Keeping documentation current is part of the maintenance process.
