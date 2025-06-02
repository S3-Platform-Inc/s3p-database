# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

# Этап 1: Инициализация базы данных
FROM postgres:16-alpine AS builder

# Копирование скриптов инициализации
COPY init-scripts/*.sql /docker-entrypoint-initdb.d/

# Временный том для данных
VOLUME /var/lib/postgresql/data

# Запуск инициализации
USER postgres
ENV POSTGRES_PASSWORD=temp_password
ENV POSTGRES_DB=sppIntegrateDB
RUN docker-entrypoint.sh postgres & sleep 45 && pg_ctl stop

# Этап 2: Финальный образ
FROM postgres:16-alpine

# Копирование предварительно инициализированных данных
COPY --from=builder --chown=postgres:postgres /var/lib/postgresql/data /var/lib/postgresql/data

# Фиксация версии данных
ENV POSTGRES_PASSWORD=
ENV POSTGRES_DB=sppIntegrateDB
ENV PGDATA=/var/lib/postgresql/data
