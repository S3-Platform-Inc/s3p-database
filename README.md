# S3 Platform Database

S3P Database is an important unit of all Platform.
This repository contains all things (running, initiating, testing and deploying database to the S3P).

## 📦 Docker Image

The database is available as a pre-built Docker image through GitHub Container Registry:

```
# Pull the latest image
docker pull ghcr.io/s3-platform-inc/s3p-database:latest

# Run the database container
docker run -d \
--name s3p-database \
-p 5432:5432 \
-e POSTGRES_PASSWORD=your_password \
ghcr.io/s3-platform-inc/s3p-database:latest
```

### Available Tags

- `latest` - Latest stable release
- `v1.0.1` - Specific version releases
- `dev` - Latest development build

## Quick Start

### Option 1: Using Pre-built Docker Image

```
# Pull and run the pre-built image
docker pull ghcr.io/s3-platform-inc/s3p-database:latest
docker run -d \
--name s3p-database \
-p 5432:5432 \
-e POSTGRES_PASSWORD=your_secure_password \
-e POSTGRES_DB=sppIntegrateDB \
ghcr.io/s3-platform-inc/s3p-database:latest
```

### Option 2: Build from Source
 
1. Go to the local projects path and run
```
git clone https://github.com/S3-Platform-Inc/s3p-database.git
cd s3p-database
```

2. Next, use `make` for generate `.env.sample` file and fill empty variables 
```
make env
``` 

3. After that, use `make` for up dev environment 
```
make dev
``` 

4. Congratulations! Welcome to the S3P Database

## 🐳 Docker Compose

For development and testing, you can use Docker Compose:

```
version: '3.8'
services:
s3p-database:
image: ghcr.io/s3-platform-inc/s3p-database:latest
container_name: s3p-database
ports:
- "5432:5432"
environment:
- POSTGRES_PASSWORD=your_secure_password
- POSTGRES_DB=sppIntegrateDB
volumes:
- postgres_data:/var/lib/postgresql/data
restart: unless-stopped

volumes:
postgres_data:
```

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

## 🔧 Building Custom Image

To build your own image with modifications:

```
cd <project directory>

# Build the image
docker build -t s3p-database:custom .

# Run your custom image
docker run -d \
--name s3p-database-custom \
-p 5432:5432 \
-e POSTGRES_PASSWORD=your_password \
s3p-database:custom
```

## 📋 Database Schema

The database comes pre-initialized with:
- ✅ User roles and permissions
- ✅ Complete schema structure
- ✅ Initial data sets
- ✅ Functions and procedures
- ✅ Indexes and constraints

## 🔍 Image Information

You can inspect the image metadata:

```
# View image labels and information
docker inspect ghcr.io/s3-platform-inc/s3p-database:latest

# Check image size and layers
docker images ghcr.io/s3-platform-inc/s3p-database:latest
```

## 🚀 Production Deployment

> in progress


## 🧪 Testing

> in progress

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

For support and questions:
- 🐛 Issues: [GitHub Issues](https://github.com/S3-Platform-Inc/s3p-database/issues)

## 🏷️ Image Labels
The Docker image includes comprehensive OCI-compliant labels for better metadata management:

```
# View all image labels
docker inspect ghcr.io/s3-platform-inc/s3p-database:latest | jq '..Config.Labels'
```

Key labels include:
- `org.opencontainers.image.title` - S3P Database
- `org.opencontainers.image.description` - Pre-initialized PostgreSQL 16 database
- `org.opencontainers.image.source` - GitHub repository URL
- `org.opencontainers.image.version` - Release version
- `com.s3platform.database.name` - Database name
- `com.s3platform.database.initialized` - Initialization status
