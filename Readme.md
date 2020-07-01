# Deploying Fossology Docker images

The scripts in this directory automatically deploy and configure Fossology iinstances.


## Which images ?

- On first run, the file `docker-compose.yml` will be downloaded from the URL specified in the configuration file (GitHub Master by default).
- *you may want to set your proxy variables before that*
- The file can be patched dynamically to select a specific image version rather than the newest one (on production server for example.)

## Configuration

Before launching the deploy script, you need to duplicate and edit all config files in the `conf` directory.

## Deploy

The main entry script is `deploy.sh`. 
- Run the default (latest) build: `./deploy.sh`
- Run a specific image: `deploy.sh master_dev-orange-docker-build_0.7`

## Backup

These scripts perform automatic backup of the Fossology filesystem and database to a target directory.

Additionaly, it is possible to configure a *hook call* to the script of your choice upon backup termination.

- `docker-backup.sh`: Performs DB and data backup according to the current configuration
- `setup-backup-crontab.sh`: Configures or update a CRONTAB entry to perform backup

## Other scripts

Other helper scripts:
- `docker-nuke-all.sh` : Destroy all Fossology related containers and volumes
   - Asks for confirmation, and will refuse to execute unless the `fossology_environment` config entry is set to `preproduction`.
- `maintenance_get-user-list.sh` : List users from the DB
- `maintenance_give-admin-power.sh` : Set Admin rights to the given username
- `maintenance_force-default-agents.sh` : Modifies the database to set the list of auto-selected agents when uploading a new upload.

## SSL Certificates

SSL certificates found in `resources/ca-certificates` will be injected in the Docker container, via the `setup-certificates.sh` script.

