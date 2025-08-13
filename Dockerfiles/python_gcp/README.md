# Docker Container para Python con Cloud SQL Proxy

Este contenedor está diseñado para ejecutarse en **GitHub Actions** y conectarse a Google Cloud SQL a través del Cloud SQL Proxy. Optimizado con construcción multi-stage para reducir el tamaño final.

## Variables de Entorno Requeridas

### Para Ejecución Completa (con clonado de repositorio)

#### Credenciales de Bitbucket
- `BITBUCKET_USER`: Usuario de Bitbucket
- `BITBUCKET_TOKEN`: Token de acceso de Bitbucket (App Password)
- `BITBUCKET_URL`: URL del repositorio sin protocolo (ej: bitbucket.org/workspace/repo.git)

#### Configuración de Ejecución
- `PATH_SCRIPT_TO_EXECUTE`: Ruta relativa al script Python a ejecutar (ej: main.py, scripts/process.py)
- `INSTANCE_GCP`: Instancia de Cloud SQL (formato: project:region:instance)

#### Configuración de Base de Datos
- `USER_BD`: Usuario de la base de datos
- `PASSWORD_BD`: Contraseña de la base de datos
- `HOST_BD`: Host de la base de datos
- `PORT_BD`: Puerto de la base de datos (usualmente 3306)
- `NAME_BD`: Nombre de la base de datos

### Para Modo Solo Proxy

#### Variables Requeridas
- `INSTANCE_GCP`: Instancia de Cloud SQL (formato: project:region:instance)

#### Variables Opcionales
- Puerto de exposición: Por defecto 3307 (configurable con `-p puerto:3307`)

## Archivos Requeridos

### credential.json
El archivo `credential.json` con las credenciales de Google Cloud debe ser montado en `/app/credential.json`

## Ejemplo de Uso

### Para GitHub Actions
```yaml
- name: Run Python Script with Cloud SQL
  run: |
    docker run --rm \
      -v ${{ github.workspace }}/credential.json:/app/credential.json:ro \
      -e BITBUCKET_USER="${{ secrets.BITBUCKET_USER }}" \
      -e BITBUCKET_TOKEN="${{ secrets.BITBUCKET_TOKEN }}" \
      -e BITBUCKET_URL="bitbucket.org/workspace/repo.git" \
      -e PATH_SCRIPT_TO_EXECUTE="main.py" \
      -e INSTANCE_GCP="my-project:us-central1:my-instance" \
      -e USER_BD="${{ secrets.DB_USER }}" \
      -e PASSWORD_BD="${{ secrets.DB_PASSWORD }}" \
      -e HOST_BD="${{ secrets.DB_HOST }}" \
      -e PORT_BD="3306" \
      -e NAME_BD="mi_base_datos" \
      python-ghc
```

### Para Docker local
```bash
# Construir la imagen
docker build -t python-ghc .

# Ejecutar el contenedor
docker run --rm \
  -v /ruta/local/credential.json:/app/credential.json:ro \
  -e BITBUCKET_USER="tu_usuario" \
  -e BITBUCKET_TOKEN="tu_token" \
  -e BITBUCKET_URL="bitbucket.org/workspace/repo.git" \
  -e PATH_SCRIPT_TO_EXECUTE="main.py" \
  -e INSTANCE_GCP="proyecto:region:instancia" \
  -e USER_BD="usuario_db" \
  -e PASSWORD_BD="password_db" \
  -e HOST_BD="localhost" \
  -e PORT_BD="3306" \
  -e NAME_BD="nombre_db" \
  python-ghc
```

### Ejecutar solo como Proxy para Base de Datos

Si solo necesitas usar el contenedor como proxy para conectarte a Cloud SQL desde tu aplicación local:

#### Opción 1: Con imagen construida localmente
```bash
# Construir la imagen
docker build -t python-ghc .

# Ejecutar solo el proxy
docker run --rm \
  -v /ruta/local/credential.json:/app/credential.json:ro \
  -e INSTANCE_GCP="proyecto:region:instancia" \
  -p 3307:3307 \
  --entrypoint /app/entrypoint_proxy.sh \
  python-ghc
```

#### Opción 2: Con imagen desde repositorio
```bash
# Ejecutar solo el proxy desde repositorio
docker run --rm \
  -v /ruta/local/credential.json:/app/credential.json:ro \
  -e INSTANCE_GCP="proyecto:region:instancia" \
  -p 3307:3307 \
  --entrypoint /app/entrypoint_proxy.sh \
  tu-repositorio/python-ghc:latest
```

#### Opción 3: Con Docker Compose
```bash
# Configurar variables de entorno en .env
echo "DOCKER_IMAGE=python-ghc" > .env
echo "INSTANCE_GCP=proyecto:region:instancia" >> .env

# Ejecutar con docker-compose
docker-compose up proxy
```

**Conexión desde tu aplicación local:**
- Host: `localhost`
- Puerto: `3307`
- Las demás credenciales de BD permanecen igual

## Funcionamiento

### Modo Completo (Ejecución de Scripts)
1. **Validación**: Verifica que todas las variables de entorno requeridas estén configuradas
2. **Verificación**: Confirma que el archivo `credential.json` esté presente
3. **Clone**: Clona el repositorio de Bitbucket en `/app/src` usando las credenciales proporcionadas
4. **Proxy**: Inicia Cloud SQL Proxy en segundo plano con las credenciales de GCP
5. **Espera**: Aguarda 5 segundos para que el proxy se inicialice completamente
6. **Ejecución**: Ejecuta el script Python especificado en `PATH_SCRIPT_TO_EXECUTE`

### Modo Solo Proxy
1. **Validación**: Verifica que la variable `INSTANCE_GCP` esté configurada
2. **Verificación**: Confirma que el archivo `credential.json` esté presente
3. **Proxy**: Inicia Cloud SQL Proxy exponiendo el puerto 3307
4. **Mantiene**: El proxy permanece activo hasta que se detenga el contenedor

## Características Técnicas

### Optimización de Imagen
- **Multi-stage build**: Reduce el tamaño final eliminando herramientas de construcción
- **Dependencias mínimas**: Solo git en la imagen final (curl solo en etapa de descarga)
- **Base optimizada**: Python 3.11 slim como imagen base

### Diseño para CI/CD
- **Sin cleanup**: Optimizado para GitHub Actions donde el entorno se destruye automáticamente
- **Ejecución directa**: El contenedor termina cuando el script Python finaliza
- **Logging detallado**: Mensajes informativos para debugging en Actions

## Notas Importantes

### Modo Completo
- El repositorio se clona en `/app/src`
- El Cloud SQL Proxy se conecta al puerto local 3307
- Diseñado específicamente para GitHub Actions (no requiere cleanup manual)
- La variable `BITBUCKET_URL` debe excluir el protocolo `https://`
- El script se ejecuta desde `/app/src/${PATH_SCRIPT_TO_EXECUTE}`

### Modo Solo Proxy
- El Cloud SQL Proxy expone el puerto 3307 para conexiones externas
- Solo requiere el archivo `credential.json` y la variable `INSTANCE_GCP`
- Ideal para desarrollo local cuando necesitas conectarte a Cloud SQL
- El contenedor permanece activo hasta ser detenido manualmente
- Puedes cambiar el puerto local con `-p puerto_deseado:3307`
