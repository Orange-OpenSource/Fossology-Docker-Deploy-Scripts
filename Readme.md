# Deploying  flavoured Fossology Docker images

The scripts in this directory can be used to automatically deploy and configure Fossology using Docker.

## Configuration

Before launching the deploy script, you will need to duplicate and edit most config files in the `conf`

## Deploy

The main entry script is `deploy.sh`. 
- Run the default (latest) build: `./deploy.sh`
- Run a specific image: `deploy.sh fossology-image_0.7`

## Backup

These scripts perform automatic backup of the Fossology filesystem and database to a target directory.

Additionaly, it is possible to configure a *hook call* to the script of your choice upon backup termination.

- `docker-backup.sh`: Performs DB and data backup according to the current configuration
- `setup-backup-crontab.sh`: Configures or update a CRONTAB entry to perform backup

## Maintenance scripts

- `docker-nuke-all.sh` : Destroy all Fossology related containers and volumes
   - Asks for confirmation, and will refuse to execute unless the `fossology_environment` config entry is set to `preproduction`.
- `maintenance_get-user-list.sh` : List users from the DB
- `maintenance_give-admin-power.sh` : Set Admin rights to the given username
- `maintenance_force-default-agents.sh` : Set default agent list for all users

## Additional ca-certificates

Additional ca-certificates are copied inside the Docker container.

The certificates need to be copies in the `resources/ca-certificates` folder
