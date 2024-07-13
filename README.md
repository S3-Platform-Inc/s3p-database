# S3 Platform Database

S3P Database is an important unit of all Platform.
This repository contains all things (running, initiating, testing and deploying database to the S3P).

## Quick Start
 
> 1. go to the local projects path and run

```
git clone https://github.com/S3-Platform-Inc/s3p-database.git
cd s3p-database
```

> 2. Next, use `make` for generate `.env.sample` file and fill empty variables 
```
make env
``` 

> 3. After that, use `make` for up dev environment 
```
make dev
``` 

> 4. Congratulations! Welcome to the S3P Database


## Env Configuration file

Run:
```
cp .env.sample .env
```
> If **.env.sample** is not exists, see **Quick Start** step 2. 

**Necessary variables**:
- `DB_DOCKER_PORT` - Port that will be use for external connect
- `DB_USER` - Main admin user
- `DB_PASSWORD` - Admin password
- `DB_DATABASE` - Database name (default: `sppIntegrateDB`)

The other variables already been filled in.
### Variable Description
- `DB_CONTAINER_NAME` - Docker container name
- `DB_DOCKER_SERVICE_NAME` - DB Service name
- `DB_POSTGRES_VERSION` - postgresql version (**default: latest**)
- `DB_DATA_DIR` - Directory for PostgreSQL data
- `LOG_DIR` - Directory for DB logs
- `DB_ROLE_SCRIPT` - Initial script for create Role (**default: roles.sql**)
- `DB_INIT_SCRIPT` - Initial script for create all Schemes, Tables, Functions, etc. (**default: startup.sql**)
- `DB_DATA_SCRIPT` - Initial script for set static data to DB (**default: data.sql**)

## Testing

> in progress


