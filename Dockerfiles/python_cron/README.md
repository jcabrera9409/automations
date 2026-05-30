# Python Cron Docker Container

## Descripción General

Contenedor Docker ligero basado en Python 3.12-slim que proporciona un entorno para ejecutar tareas cron programadas con scripts Python. La solución está diseñada para facilitar la ejecución de trabajos programados en entornos containerizados, eliminando la necesidad de configurar cron manualmente en el host.

## Características

- 🐍 Python 3.12-slim como base
- ⏰ Servicio cron preconfigurado
- 📦 Instalación automática de dependencias Python
- 🔧 Configuración flexible mediante variables de entorno
- 📝 Logging integrado a `/var/log/cron.log`
- 🚀 Arquitectura lista para producción

## Estructura del Proyecto

```
python_cron/
├── Dockerfile              # Definición de la imagen Docker
├── entrypoint.sh          # Script de inicialización del contenedor
├── README.md              # Este archivo
└── example/               # Ejemplo de implementación
    ├── docker-compose.yml
    ├── example-cron-jobs  # Configuración de cron jobs
    ├── requeriments.txt   # (no incluido - crear según necesidad)
    └── scripts/
        └── example.py     # Script Python de ejemplo
```

## Funcionamiento

### 1. Construcción de la Imagen

El `Dockerfile` realiza las siguientes operaciones:

```dockerfile
FROM python:3.12-slim
RUN apt-get update && apt-get install -y cron
WORKDIR /app
COPY entrypoint.sh entrypoint.sh
RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
```

- Utiliza Python 3.12-slim para mantener el tamaño reducido
- Instala el paquete `cron`
- Configura el entrypoint script como punto de entrada

### 2. Entrypoint Script

El `entrypoint.sh` gestiona la inicialización del contenedor:

**Paso 1: Instalación de Dependencias**
```bash
if [ ! -z "$REQUIREMENTS_FILE" ] && [ -f "$REQUIREMENTS_FILE" ]; then
    pip install --no-cache-dir -r "$REQUIREMENTS_FILE"
fi
```

**Paso 2: Configuración de Cron Jobs**
```bash
if [ ! -z "$CRON_JOBS_FILE" ] && [ -f "$CRON_JOBS_FILE" ]; then
    chmod 0644 "$CRON_JOBS_FILE"
    crontab "$CRON_JOBS_FILE"
fi
```

**Paso 3: Inicio del Servicio Cron**
```bash
exec cron -f
```
El flag `-f` ejecuta cron en foreground, crítico para mantener el contenedor activo.

## Configuración

### Variables de Entorno

| Variable | Descripción | Requerido | Ejemplo |
|----------|-------------|-----------|---------|
| `REQUIREMENTS_FILE` | Ruta al archivo requirements.txt | No | `/app/requeriments.txt` |
| `CRON_JOBS_FILE` | Ruta al archivo de configuración de cron | No | `/etc/cron.d/python-jobs` |

### Formato del Archivo Cron

El archivo de cron jobs debe seguir el formato estándar de crontab:

```
# Formato: minuto hora día mes día_semana comando
* * * * * /usr/local/bin/python /app/scripts/mi_script.py >> /var/log/cron.log 2>&1
```

**Nota importante**: Es crítico redirigir la salida a `/var/log/cron.log` para poder monitorear la ejecución.

#### Ejemplos de Expresiones Cron

```bash
# Cada minuto
* * * * * comando

# Cada 5 minutos
*/5 * * * * comando

# Cada hora en el minuto 0
0 * * * * comando

# Diariamente a las 2:30 AM
30 2 * * * comando

# Cada lunes a las 9:00 AM
0 9 * * 1 comando

# Primer día de cada mes a medianoche
0 0 1 * * comando
```

## Uso

### Construcción de la Imagen

```bash
cd Dockerfiles/python_cron
docker build -t cron:latest .
```

### Ejecución con Docker Run

```bash
docker run -d \
  --name python-cron \
  -e REQUIREMENTS_FILE=/app/requirements.txt \
  -e CRON_JOBS_FILE=/etc/cron.d/python-jobs \
  -v $(pwd)/requirements.txt:/app/requirements.txt \
  -v $(pwd)/cron-jobs:/etc/cron.d/python-jobs \
  -v $(pwd)/scripts:/app/scripts \
  cron:latest
```

### Ejecución con Docker Compose

Crear un archivo `docker-compose.yml`:

```yaml
services:
  cron:
    image: cron:latest
    platform: linux/amd64  # Especificar si se ejecuta en Apple Silicon
    container_name: python-cron
    environment:
      - REQUIREMENTS_FILE=/app/requirements.txt
      - CRON_JOBS_FILE=/etc/cron.d/python-jobs
    volumes:
      - ./requirements.txt:/app/requirements.txt
      - ./cron-jobs:/etc/cron.d/python-jobs
      - ./scripts:/app/scripts
    entrypoint: ["/app/entrypoint.sh"]
```

Ejecutar:
```bash
docker compose up -d
```

## Implementación de Ejemplo

### 1. Crear la Estructura

```bash
mkdir -p my-cron-project/scripts
cd my-cron-project
```

### 2. Crear el Script Python

`scripts/my_task.py`:
```python
import datetime
import requests

def main():
    timestamp = datetime.datetime.now().isoformat()
    print(f"[{timestamp}] Ejecutando tarea programada...")
    
    # Tu lógica aquí
    try:
        # Ejemplo: llamada a API
        response = requests.get('https://api.example.com/data')
        print(f"Status: {response.status_code}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
```

### 3. Crear el Archivo de Dependencias

`requirements.txt`:
```
requests==2.31.0
python-dotenv==1.0.0
```

### 4. Configurar Cron Jobs

`my-cron-jobs`:
```bash
# Ejecutar cada 5 minutos
*/5 * * * * /usr/local/bin/python /app/scripts/my_task.py >> /var/log/cron.log 2>&1

# Ejecutar cada hora
0 * * * * /usr/local/bin/python /app/scripts/hourly_task.py >> /var/log/cron.log 2>&1
```

### 5. Crear docker-compose.yml

```yaml
services:
  cron:
    image: cron:latest
    platform: linux/amd64
    container_name: my-cron-app
    environment:
      - REQUIREMENTS_FILE=/app/requirements.txt
      - CRON_JOBS_FILE=/etc/cron.d/python-jobs
    volumes:
      - ./requirements.txt:/app/requirements.txt
      - ./my-cron-jobs:/etc/cron.d/python-jobs
      - ./scripts:/app/scripts
    restart: unless-stopped
```

## Monitoreo y Debugging

### Ver Logs del Cron

```bash
# Ver logs en tiempo real
docker exec -it python-cron tail -f /var/log/cron.log

# Ver últimas 100 líneas
docker exec -it python-cron tail -n 100 /var/log/cron.log

# Ver logs del contenedor
docker logs python-cron -f
```

### Verificar Crontab Configurado

```bash
docker exec -it python-cron crontab -l
```

### Ejecutar Script Manualmente

```bash
docker exec -it python-cron /usr/local/bin/python /app/scripts/example.py
```

### Verificar Servicio Cron

```bash
docker exec -it python-cron ps aux | grep cron
```

## Consideraciones de Producción

### 1. Timezone

Por defecto, el contenedor usa UTC. Para configurar otra zona horaria:

```yaml
environment:
  - TZ=America/Mexico_City
```

### 2. Persistencia de Logs

Montar un volumen para los logs:

```yaml
volumes:
  - ./logs:/var/log
```

### 3. Health Checks

Agregar un health check al docker-compose:

```yaml
healthcheck:
  test: ["CMD", "pgrep", "cron"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

### 4. Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

### 5. Restart Policy

```yaml
restart: unless-stopped
```

### 6. Manejo de Secretos

No incluir secretos en variables de entorno. Usar Docker secrets o montar archivos:

```yaml
volumes:
  - ./secrets/.env:/app/.env:ro
```

## Troubleshooting

### Problema: Los cron jobs no se ejecutan

**Solución 1**: Verificar permisos del archivo cron
```bash
docker exec -it python-cron ls -la /etc/cron.d/
```
Debe tener permisos `0644`.

**Solución 2**: Verificar formato del archivo cron
- Debe terminar con una línea en blanco
- No debe tener extensión `.txt` u otra
- Usar LF (Unix) line endings, no CRLF (Windows)

**Solución 3**: Verificar que cron esté corriendo
```bash
docker exec -it python-cron pgrep -a cron
```

### Problema: Dependencias no se instalan

**Verificar**:
1. Que `REQUIREMENTS_FILE` apunte a la ruta correcta dentro del contenedor
2. Que el volumen esté montado correctamente
3. Revisar logs de inicio: `docker logs python-cron`

### Problema: Script no encuentra módulos Python

**Causa**: Path incorrecto en el cron job.

**Solución**: Usar ruta completa al intérprete Python:
```bash
* * * * * /usr/local/bin/python /app/scripts/my_script.py >> /var/log/cron.log 2>&1
```

### Problema: Contenedor se detiene inmediatamente

**Causa**: Cron no está corriendo en foreground.

**Verificar**: El entrypoint usa `cron -f` (flag `-f` es crítico)

## Mejoras Sugeridas

1. **Agregar notificaciones**: Integrar notificaciones por email o Slack en caso de fallos
2. **Metrics**: Exportar métricas a Prometheus/Grafana
3. **Multiple cron files**: Soportar múltiples archivos de configuración
4. **Dynamic reload**: Recargar configuración sin reiniciar contenedor
5. **Log rotation**: Implementar rotación de logs para evitar crecimiento indefinido

## Ejemplos de Casos de Uso

- ✅ ETL jobs periódicos
- ✅ Backup automatizado de bases de datos
- ✅ Sincronización de datos entre sistemas
- ✅ Generación de reportes programados
- ✅ Limpieza de archivos temporales
- ✅ Health checks de APIs
- ✅ Web scraping programado
- ✅ Procesamiento batch de datos

## Referencias

- [Cron Format Reference](https://crontab.guru/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Python in Docker](https://hub.docker.com/_/python)

## Licencia

Este proyecto es de código abierto y está disponible para uso libre.
