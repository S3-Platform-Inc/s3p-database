# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

# Этап 1: Инициализация базы данных
FROM postgres:16-alpine

ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=default-password
ENV POSTGRES_DB=sppIntegrateDB

# Копирование скриптов инициализации
COPY init-scripts/*.sql /docker-entrypoint-initdb.d/

# Временный том для данных
VOLUME /var/lib/postgresql/data

# Запуск инициализации
USER postgres
RUN docker-entrypoint.sh postgres & sleep 45 && pg_ctl stop

# OCI Standard Labels
LABEL org.opencontainers.image.title="S3P Database"
LABEL org.opencontainers.image.description="Pre-initialized PostgreSQL 16 database for S3P Platform with integrated schema and data"
LABEL org.opencontainers.image.authors="S3-Platform-Inc <contact@s3platform.com>"

LABEL org.opencontainers.image.version="1.0.2"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="S3 Platform Inc"


LABEL org.opencontainers.image.source = "https://github.com/S3-Platform-Inc/s3p-database"
LABEL org.opencontainers.image.url = "https://github.com/S3-Platform-Inc/s3p-database"
LABEL org.opencontainers.image.documentation="https://github.com/S3-Platform-Inc/s3p-database/blob/main/README.md"

# Custom Labels for Database Specifics
LABEL com.s3platform.database.name="sppIntegrateDB"
LABEL com.s3platform.database.version="16"
LABEL com.s3platform.database.type="postgresql"
LABEL com.s3platform.database.initialized="true"
