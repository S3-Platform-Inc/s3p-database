# syntax=docker/dockerfile:1

# Этап 1: Инициализация базы данных
FROM postgres:16-alpine

LABEL org.opencontainers.image.description "Pre-initialized PostgreSQL 16 database for S3P Platform with integrated schema and data"
LABEL org.opencontainers.image.authors "S3-Platform-Inc <contact@s3platform.com>"
LABEL org.opencontainers.image.version "1.1"
LABEL org.opencontainers.image.vendor "S3 Platform Inc"
LABEL org.opencontainers.image.source "https://github.com/S3-Platform-Inc/s3p-database"

# Копирование скриптов инициализации
COPY init-scripts/*.sql /docker-entrypoint-initdb.d/

# Устанавливаем правильные права доступа для скриптов
RUN chmod -R 755 /docker-entrypoint-initdb.d/

# Добавляем healthcheck для мониторинга состояния PostgreSQL
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-${POSTGRES_USER:-postgres}}" || exit 1

EXPOSE 5432

VOLUME /var/lib/postgresql/data

ENV POSTGRES_USER postgres
ENV POSTGRES_DB sppIntegrateDB
ENV PGDATA /var/lib/postgresql/data
