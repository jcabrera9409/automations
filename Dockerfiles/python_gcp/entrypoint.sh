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

if [ -z "$PATH_SCRIPT_TO_EXECUTE" ] && [ ! -f "/app/list-python-task.txt" ]; then
    echo "ERROR: Se requiere al menos una de las siguientes opciones:"
    echo "1. La variable PATH_SCRIPT_TO_EXECUTE para un solo script (ej: src/main.py)"
    echo "2. El archivo /app/list-python-task.txt montado como volumen con la lista de scripts"
    echo ""
    echo "Estado actual:"
    echo "- PATH_SCRIPT_TO_EXECUTE: '${PATH_SCRIPT_TO_EXECUTE:-<vacío>}'"
    echo "- Archivo /app/list-python-task.txt existe: $([ -f "/app/list-python-task.txt" ] && echo "SÍ" || echo "NO")"
    
    if [ ! -f "/app/list-python-task.txt" ]; then
        echo "- Contenido del directorio /app:"
        ls -la /app/ || echo "  No se puede listar /app/"
    fi
    
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

# Instalar requerimientos si existe requirements.txt
if [ -f "src/requirements.txt" ]; then
    echo "=== Instalando requerimientos de Python ==="
    pip install --no-cache-dir -r src/requirements.txt
fi

echo "=== Ejecutando script(s) Python ==="

# Función para ejecutar un script con sus argumentos
execute_script() {
    local script_path="$1"
    shift
    local args=("$@")
    
    echo "--- Ejecutando: python /app/src/${script_path} ${args[*]} ---"
    python /app/src/${script_path} "${args[@]}"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "--- Script ${script_path} ejecutado exitosamente ---"
    else
        echo "--- ERROR: Script ${script_path} falló con código de salida ${exit_code} ---"
        exit $exit_code
    fi
}

# Verificar si se debe usar el archivo de tareas o la variable de script único
if [ -f "/app/list-python-task.txt" ]; then
    echo "=== Modo archivo de tareas detectado ==="
    echo "=== Leyendo scripts desde /app/list-python-task.txt ==="
    
    # Verificar que el archivo no esté vacío
    if [ ! -s "/app/list-python-task.txt" ]; then
        echo "ERROR: El archivo /app/list-python-task.txt está vacío"
        exit 1
    fi
    
    # Leer el archivo línea por línea
    line_number=0
    while IFS= read -r line || [ -n "$line" ]; do
        line_number=$((line_number + 1))
        
        # Saltar líneas vacías y comentarios (líneas que empiezan con #)
        if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Remover espacios en blanco al inicio y final
        line=$(echo "$line" | xargs)
        
        if [ -n "$line" ]; then
            echo "--- Procesando línea $line_number: $line ---"
            
            # Convertir la línea en un array de argumentos
            read -ra SCRIPT_ARGS <<< "$line"
            
            script_path="${SCRIPT_ARGS[0]}"
            # Obtener argumentos (todo excepto el primer elemento)
            args=("${SCRIPT_ARGS[@]:1}")
            
            execute_script "$script_path" "${args[@]}"
        fi
    done < "/app/list-python-task.txt"
    
elif [ -n "$PATH_SCRIPT_TO_EXECUTE" ]; then
    echo "=== Modo script único (retrocompatibilidad) ==="
    execute_script "$PATH_SCRIPT_TO_EXECUTE"
fi

echo "=== Todos los scripts ejecutados exitosamente ==="

