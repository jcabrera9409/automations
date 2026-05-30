#!/bin/bash

set -e

echo "====================================="
echo "Configurando contenedor"
echo "====================================="

#
# Instalar dependencias si se proporciona un archivo de requerimientos
#
if [ ! -z "$REQUIREMENTS_FILE" ] && [ -f "$REQUIREMENTS_FILE" ]; then
    echo "Instalando dependencias..."
    pip install --no-cache-dir -r "$REQUIREMENTS_FILE"
fi

# Configurar cron jobs
# Colocar el archivo dentro de la carpeta /etc/cron.d
if [ ! -z "$CRON_JOBS_FILE" ] && [ -f "$CRON_JOBS_FILE" ]; then
    echo "Iniciando configuración de cron jobs..."

    chmod 0644 "$CRON_JOBS_FILE"

    crontab "$CRON_JOBS_FILE"
fi

touch /var/log/cron.log

echo "Cron iniciado"

exec cron -f