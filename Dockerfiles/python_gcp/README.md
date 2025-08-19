# Docker Container para Python con Cloud SQL Proxy

Este contenedor está diseñado para ejecutarse en **GitHub Actions** y conectarse a Google Cloud SQL a través del Cloud SQL Proxy. Optimizado con construcción multi-stage para reducir el tamaño final.

Soporta **múltiples modos de ejecución** para máxima flexibilidad:
- 🔧 **Modo archivo de tareas**: Ejecuta múltiples scripts definidos en un archivo
- 📝 **Modo script único**: Ejecuta un script específico (retrocompatibilidad)
- 🔗 **Modo solo proxy**: Solo funciona como proxy a Cloud SQL

## Modos de Ejecución

### 1. Modo Archivo de Tareas (Recomendado)

Ejecuta múltiples scripts de Python definidos en un archivo `list-python-task.txt`.

#### Variables de Entorno Requeridas
- `BITBUCKET_USER`: Usuario de Bitbucket
- `BITBUCKET_TOKEN`: Token de acceso de Bitbucket (App Password)
- `BITBUCKET_URL`: URL del repositorio sin protocolo (ej: bitbucket.org/workspace/repo.git)
- `INSTANCE_GCP`: Instancia de Cloud SQL (formato: project:region:instance)
- `USER_BD`, `PASSWORD_BD`, `HOST_BD`, `PORT_BD`, `NAME_BD`: Configuración de base de datos

#### Archivos Requeridos
- `credential.json`: Credenciales de Google Cloud (montado en `/app/credential.json`)
- `list-python-task.txt`: Lista de scripts a ejecutar (montado en `/app/list-python-task.txt`)

#### Formato del archivo list-python-task.txt
```bash
# Comentarios empiezan con #
# Una línea por script: script_path argumentos_separados_por_espacios

devops/script.py PI3-25
devops/script2.py PI3-25 950 1
data/processor.py --verbose --output /tmp/result
setup.py --config production

# Scripts sin argumentos
cleanup.py
```

### 2. Modo Script Único (Retrocompatibilidad)

Ejecuta un solo script de Python especificado por variable de entorno.

#### Variables de Entorno Adicionales
- `PATH_SCRIPT_TO_EXECUTE`: Ruta relativa al script Python a ejecutar (ej: main.py, scripts/process.py)

### 3. Modo Solo Proxy

Solo inicia Cloud SQL Proxy para conexiones externas.

#### Variables de Entorno Requeridas
- `INSTANCE_GCP`: Instancia de Cloud SQL (formato: project:region:instance)

#### Archivos Requeridos
- `credential.json`: Credenciales de Google Cloud (montado en `/app/credential.json`)

## Ejemplos de Uso

### 🔧 Modo Archivo de Tareas - GitHub Actions

```yaml
name: Ejecutar Múltiples Scripts

on:
  workflow_dispatch:

env:
  BITBUCKET_USER: tu_usuario
  BITBUCKET_URL: bitbucket.org/workspace/repo.git
  TASK_FILE_PATH: configs/list-python-task.txt
  INSTANCE_GCP: mi-proyecto:us-central1:mi-instancia

jobs:
  run-scripts:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Crear credential.json
        run: echo "${{ secrets.CREDENTIAL_JSON_BASE64 }}" | base64 -d > credential.json

      - name: Ejecutar contenedor con archivo de tareas
        run: |
          docker run --name python_container \
            -e BITBUCKET_USER=${{ env.BITBUCKET_USER }} \
            -e BITBUCKET_TOKEN=${{ secrets.BITBUCKET_TOKEN }} \
            -e BITBUCKET_URL=${{ env.BITBUCKET_URL }} \
            -e INSTANCE_GCP=${{ env.INSTANCE_GCP }} \
            -e USER_BD=${{ secrets.DB_USER }} \
            -e PASSWORD_BD=${{ secrets.DB_PASSWORD }} \
            -e HOST_BD=localhost \
            -e PORT_BD=3307 \
            -e NAME_BD=${{ secrets.DB_NAME }} \
            -v ${{ github.workspace }}/credential.json:/app/credential.json \
            -v ${{ github.workspace }}/${{ env.TASK_FILE_PATH }}:/app/list-python-task.txt \
            ghcr.io/tu-usuario/python_gcp:latest

      - name: Cleanup
        if: always()
        run: |
          docker rm -f python_container || true
          rm -f credential.json
```

### 📝 Modo Script Único - GitHub Actions

```yaml
- name: Ejecutar Script Único
  run: |
    docker run --rm \
      -v ${{ github.workspace }}/credential.json:/app/credential.json \
      -e BITBUCKET_USER="${{ secrets.BITBUCKET_USER }}" \
      -e BITBUCKET_TOKEN="${{ secrets.BITBUCKET_TOKEN }}" \
      -e BITBUCKET_URL="bitbucket.org/workspace/repo.git" \
      -e PATH_SCRIPT_TO_EXECUTE="main.py" \
      -e INSTANCE_GCP="mi-proyecto:us-central1:mi-instancia" \
      -e USER_BD="${{ secrets.DB_USER }}" \
      -e PASSWORD_BD="${{ secrets.DB_PASSWORD }}" \
      -e HOST_BD="localhost" \
      -e PORT_BD="3307" \
      -e NAME_BD="mi_base_datos" \
      ghcr.io/tu-usuario/python_gcp:latest
```

### 🔧 Modo Archivo de Tareas - Docker Local

```bash
# Crear archivo de tareas
cat > list-python-task.txt << EOF
# Scripts del proceso ETL
data/extract.py --source production
data/transform.py --config etl.yaml
data/load.py --batch-size 1000
EOF

# Ejecutar contenedor
docker run --rm \
  -v ./credential.json:/app/credential.json \
  -v ./list-python-task.txt:/app/list-python-task.txt \
  -e BITBUCKET_USER="tu_usuario" \
  -e BITBUCKET_TOKEN="tu_token" \
  -e BITBUCKET_URL="bitbucket.org/workspace/repo.git" \
  -e INSTANCE_GCP="proyecto:region:instancia" \
  -e USER_BD="usuario_db" \
  -e PASSWORD_BD="password_db" \
  -e HOST_BD="localhost" \
  -e PORT_BD="3307" \
  -e NAME_BD="nombre_db" \
  ghcr.io/tu-usuario/python_gcp:latest
```

### 📝 Modo Script Único - Docker Local

```bash
docker run --rm \
  -v ./credential.json:/app/credential.json \
  -e BITBUCKET_USER="tu_usuario" \
  -e BITBUCKET_TOKEN="tu_token" \
  -e BITBUCKET_URL="bitbucket.org/workspace/repo.git" \
  -e PATH_SCRIPT_TO_EXECUTE="main.py" \
  -e INSTANCE_GCP="proyecto:region:instancia" \
  -e USER_BD="usuario_db" \
  -e PASSWORD_BD="password_db" \
  -e HOST_BD="localhost" \
  -e PORT_BD="3307" \
  -e NAME_BD="nombre_db" \
  ghcr.io/tu-usuario/python_gcp:latest
```

### 🔗 Modo Solo Proxy

Ideal para desarrollo local cuando necesitas conectarte a Cloud SQL desde tu aplicación.

#### Con imagen construida localmente
```bash
# Construir la imagen
docker build -t python-gcp .

# Ejecutar solo el proxy
docker run --rm \
  -v ./credential.json:/app/credential.json \
  -e INSTANCE_GCP="proyecto:region:instancia" \
  -p 3307:3307 \
  --entrypoint /app/entrypoint_proxy.sh \
  python-gcp
```

#### Con imagen desde repositorio
```bash
docker run --rm \
  -v ./credential.json:/app/credential.json \
  -e INSTANCE_GCP="proyecto:region:instancia" \
  -p 3307:3307 \
  --entrypoint /app/entrypoint_proxy.sh \
  ghcr.io/tu-usuario/python_gcp:latest
```

#### Con Docker Compose
```yaml
# docker-compose.yml
version: '3.8'
services:
  proxy:
    image: ghcr.io/tu-usuario/python_gcp:latest
    entrypoint: /app/entrypoint_proxy.sh
    environment:
      - INSTANCE_GCP=${INSTANCE_GCP}
    volumes:
      - ./credential.json:/app/credential.json:ro
    ports:
      - "3307:3307"
```

```bash
# Configurar variables de entorno
echo "INSTANCE_GCP=proyecto:region:instancia" > .env

# Ejecutar
docker-compose up proxy
```

**Conexión desde tu aplicación local:**
- Host: `localhost`
- Puerto: `3307`
- Las demás credenciales de BD permanecen igual

## Funcionamiento Interno

### Detección Automática de Modo

El entrypoint detecta automáticamente el modo de operación:

1. **Si existe `/app/list-python-task.txt`** → Modo archivo de tareas
2. **Si existe variable `PATH_SCRIPT_TO_EXECUTE`** → Modo script único  
3. **Si se usa `entrypoint_proxy.sh`** → Modo solo proxy

### Flujo de Ejecución

#### Modo Archivo de Tareas / Script Único
1. **Validación**: Verifica variables de entorno y archivos requeridos
2. **Clone**: Clona el repositorio de Bitbucket en `/app/src`
3. **Proxy**: Inicia Cloud SQL Proxy en segundo plano
4. **Dependencias**: Instala `requirements.txt` si existe
5. **Ejecución**: 
   - Archivo de tareas: Lee y ejecuta cada script secuencialmente
   - Script único: Ejecuta el script especificado
6. **Finalización**: Termina con código de salida del último script

#### Modo Solo Proxy
1. **Validación**: Verifica `INSTANCE_GCP` y `credential.json`
2. **Proxy**: Inicia Cloud SQL Proxy exponiendo puerto 3307
3. **Mantiene**: Permanece activo hasta detener el contenedor

### Manejo de Errores

- **Validación estricta**: Falla inmediatamente si faltan variables/archivos requeridos
- **Fallo temprano**: Si un script falla, se detiene la ejecución completa
- **Logs detallados**: Cada paso muestra información de debug
- **Códigos de salida**: Preserva el código de salida del script que falló

## Archivo de Tareas - Formato Avanzado

### Características
- ✅ **Comentarios**: Líneas que empiezan con `#`
- ✅ **Líneas vacías**: Se ignoran automáticamente
- ✅ **Argumentos con espacios**: Usar comillas cuando sea necesario
- ✅ **Paths relativos**: Relativos al directorio `/app/src` clonado
- ✅ **Logging detallado**: Muestra número de línea y comando completo

### Ejemplos Avanzados

```bash
# === Proceso ETL Completo ===

# 1. Configuración inicial
setup/init_environment.py --env production --log-level INFO

# 2. Extracción de datos
extract/fetch_data.py --source mysql --tables "users,orders,products"
extract/validate_data.py --strict --output /tmp/validation.log

# 3. Transformación
transform/clean_data.py --config "config/clean_rules.json"
transform/aggregate_data.py --period daily --format parquet

# 4. Carga de datos  
load/upload_to_warehouse.py --destination bigquery --dataset analytics
load/create_views.py --schema "reporting"

# 5. Verificación final
verify/data_quality.py --threshold 95
verify/send_notification.py --email admin@company.com --status success
```

## Características Técnicas

### Optimización de Imagen
- **Multi-stage build**: Reduce el tamaño final eliminando herramientas de construcción
- **Dependencias mínimas**: Solo las herramientas esenciales en imagen final
- **Base optimizada**: Python 3.11 slim como imagen base
- **Cache inteligente**: Layers optimizados para maximizar reutilización

### Diseño para CI/CD
- **GitHub Actions optimizado**: Sin cleanup manual, logging detallado
- **Múltiples modos**: Flexibilidad para diferentes casos de uso
- **Retrocompatibilidad**: Soporte para configuraciones existentes
- **Fail-fast**: Detección temprana de errores para builds rápidos

### Seguridad
- **Credenciales montadas**: No embebidas en la imagen
- **Usuario no-root**: Ejecución con usuario limitado (donde aplique)
- **Secrets seguros**: Integración con sistemas de secrets de CI/CD

## Casos de Uso Comunes

### 🔄 Procesos ETL Automatizados
```bash
# list-python-task.txt para ETL diario
extract/daily_extract.py --date today
transform/process_data.py --parallel 4
load/sync_to_warehouse.py --verify
notifications/send_report.py --recipients ops-team
```

### 🧪 Testing y Validación
```bash
# list-python-task.txt para pipeline de testing
tests/setup_test_data.py --fresh
tests/run_integration_tests.py --coverage
validation/check_data_quality.py --strict
cleanup/remove_test_data.py
```

### 📊 Reportes Programados
```bash
# list-python-task.txt para reportes semanales
reports/generate_weekly_summary.py --week current
reports/create_charts.py --format png --output /tmp/charts
reports/send_email_report.py --template weekly --recipients stakeholders
```

### 🔧 Mantenimiento Automatizado
```bash
# list-python-task.txt para tareas de mantenimiento
maintenance/cleanup_old_logs.py --days 30
maintenance/update_cache.py --force
maintenance/backup_configs.py --destination s3
health/system_check.py --alert-on-failure
```

## Mejores Prácticas

### 📝 Organización del Archivo de Tareas
```bash
# ✅ Buena práctica: Organizado y documentado
# === CONFIGURACIÓN ===
setup/init.py --env prod

# === PROCESAMIENTO ===  
process/step1.py --input data/raw
process/step2.py --input data/processed --output data/final

# === VALIDACIÓN ===
validate/check_output.py --path data/final
```

### 🔒 Manejo de Secretos
```yaml
# ✅ En GitHub Actions
- name: Setup secrets
  run: |
    echo "${{ secrets.CREDENTIAL_JSON_BASE64 }}" | base64 -d > credential.json
    echo "${{ secrets.DB_CONFIG }}" > db_config.json

# ✅ Montar como volúmenes, no como variables de entorno sensibles
-v ${{ github.workspace }}/credential.json:/app/credential.json:ro
```

### 🚀 Optimización de Performance
```bash
# ✅ Scripts optimizados para ejecución secuencial
validate/quick_check.py          # Falla rápido si hay problemas
setup/prepare_environment.py     # Una sola vez al inicio
process/heavy_computation.py     # Al final, cuando todo está listo
```

## Troubleshooting

### ❌ Errores Comunes

#### Error: "PATH_SCRIPT_TO_EXECUTE es requerida"
```bash
# ✅ Solución: Usar archivo de tareas o variable
# Opción 1: Montar archivo
-v ./list-python-task.txt:/app/list-python-task.txt

# Opción 2: Usar variable (modo legacy)
-e PATH_SCRIPT_TO_EXECUTE="mi_script.py"
```

#### Error: "credential.json no encontrado"
```bash
# ✅ Solución: Verificar montaje del volumen
-v ./credential.json:/app/credential.json:ro

# ✅ Verificar que el archivo existe localmente
ls -la credential.json
```

#### Error: Script falla con "Module not found"
```bash
# ✅ Solución: Verificar requirements.txt en el repo
# El contenedor instala automáticamente desde src/requirements.txt
```

### 🔍 Debug y Logging

#### Habilitar logging detallado
```bash
# Los logs incluyen automáticamente:
# - Variables de entorno (sin secretos)
# - Comandos ejecutados
# - Códigos de salida
# - Tiempo de ejecución
```

#### Verificar conectividad a Cloud SQL
```bash
# El proxy logs aparecen en la salida del contenedor
# Buscar: "Cloud SQL Proxy iniciado con PID: XXXX"
```

## Migración desde Versión Anterior

### De script único a archivo de tareas

#### Antes (script único):
```yaml
env:
  PATH_SCRIPT_TO_EXECUTE: mi_script.py
```

#### Después (archivo de tareas):
```yaml
env:
  TASK_FILE_PATH: configs/list-python-task.txt

# Crear archivo configs/list-python-task.txt:
# mi_script.py
```

#### Migración automática:
```bash
# Crear archivo de tareas desde variable existente
echo "$PATH_SCRIPT_TO_EXECUTE" > list-python-task.txt
```

La **retrocompatibilidad está garantizada** - el modo script único sigue funcionando sin cambios.
