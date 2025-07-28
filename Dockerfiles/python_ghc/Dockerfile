# Etapa de descarga - imagen temporal para descargar Cloud SQL Proxy
FROM alpine:latest AS downloader
RUN apk add --no-cache curl
RUN curl -o /cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
RUN chmod +x /cloud_sql_proxy

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY --from=downloader /cloud_sql_proxy /app/cloud_sql_proxy

RUN pip install pytz \
    PyMySQL

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV BITBUCKET_USER=""
ENV BITBUCKET_TOKEN=""
ENV BITBUCKET_URL=""
ENV PATH_SCRIPT_TO_EXECUTE=""
ENV INSTANCE_GCP=""
ENV USER_BD=""
ENV PASSWORD_BD=""
ENV HOST_BD=""
ENV PORT_BD=""
ENV NAME_BD=""
ENV GOOGLE_APPLICATION_CREDENTIALS="/app/credential.json"

ENTRYPOINT ["/entrypoint.sh"]
