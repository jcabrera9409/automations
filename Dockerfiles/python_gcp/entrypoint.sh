#!/bin/bash

set -e

echo "=== Iniciando entrypoint del contenedor ==="

# Verificar que las variables de entorno necesarias estén configuradas
if [ -z "$BITBUCKET_USER" ] || [ -z "$BITBUCKET_TOKEN" ] || [ -z "$BITBUCKET_URL" ]; then
    echo "ERROR: Las variables BITBUCKET_USER, BITBUCKET_TOKEN y BITBUCKET_URL son requeridas"
    exit 1
fi

if [ -z "$USER_BD" ] || [ -z "$PASSWORD_BD" ] || [ -z "$HOST_BD" ] || [ -z "$PORT_BD" ] || [ -z "$NAME_BD" ]; then
    echo "ERROR: Las variables de base de datos (USER_BD, PASSWORD_BD, HOST_BD, PORT_BD, NAME_BD) son requeridas"
    exit 1
fi

if [ -z "$PATH_SCRIPT_TO_EXECUTE" ]; then
    echo "ERROR: La variable PATH_SCRIPT_TO_EXECUTE es requerida (ej: src/main.py)"
    exit 1
fi

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

# Clonar el repositorio de Bitbucket si no existe el código
echo "=== Clonando repositorio de Bitbucket ==="

# Construir la URL con credenciales
REPO_WITH_CREDENTIALS="https://${BITBUCKET_USER}:${BITBUCKET_TOKEN}@${BITBUCKET_URL}"

git clone ${REPO_WITH_CREDENTIALS} src
echo "=== Repositorio clonado exitosamente ==="

# Iniciar Cloud SQL Proxy en segundo plano
echo "=== Iniciando Cloud SQL Proxy ==="
nohup /app/cloud_sql_proxy -instances=${INSTANCE_GCP} &

echo "Cloud SQL Proxy iniciado con PID: $!"

sleep 5  # Esperar un poco para asegurarnos de que el proxy esté listo

echo "=== Ejecutando script Python ==="
python /app/src/${PATH_SCRIPT_TO_EXECUTE}

