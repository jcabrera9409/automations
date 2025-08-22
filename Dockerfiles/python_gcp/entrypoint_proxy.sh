#!/bin/bash

set -e

echo "=== Iniciando entrypoint del contenedor ==="

if [ -z "$INSTANCE_GCP" ]; then
    echo "ERROR: La variable INSTANCE_GCP es requerida (ej: project:region:instance)"
    exit 1
fi

# Verificar que el archivo credential.json exista
if [ ! -f "/app/credential.json" ]; then
    echo "ERROR: El archivo credential.json no se encontró en /app/credential.json"
    echo "Asegúrate de montarlo como volumen en tiempo de ejecución"
    exit 1
fi

echo "=== Variables de entorno verificadas ==="

# Iniciar Cloud SQL Proxy en segundo plano
echo "=== Iniciando Cloud SQL Proxy ==="
/app/cloud_sql_proxy -address 0.0.0.0 -instances=${INSTANCE_GCP}



