# Beszel en Docker

Este proyecto levanta **Beszel Hub** y **Beszel Agent** en el mismo servidor usando Docker Compose.

Beszel permite monitorear:

- CPU
- RAM
- Load Average
- Disco
- Red
- Contenedores Docker
- Consumo individual por contenedor
- Histórico de métricas
- Alertas

---

## Estructura

```text
/var/docker/beszel/
├── docker-compose.yml
├── .env
├── README.md
├── beszel_data/
├── beszel_agent_data/
└── beszel_socket/
```

---

## 1. Crear la carpeta

```bash
sudo mkdir -p /var/docker/beszel
sudo chown -R $USER:$USER /var/docker/beszel

cd /var/docker/beszel
```

---

## 2. Crear el archivo `.env`

Crea el archivo:

```bash
nano .env
```

Contenido:

```env
# ==========================================
# BESZEL HUB
# ==========================================

BESZEL_IMAGE=henrygd/beszel:latest
BESZEL_CONTAINER_NAME=beszel

# Puerto local del Hub
BESZEL_PORT=8090

# URL pública configurada en Caddy
BESZEL_APP_URL=https://monitor.tudominio.com


# ==========================================
# BESZEL AGENT
# ==========================================

BESZEL_AGENT_IMAGE=henrygd/beszel-agent:latest
BESZEL_AGENT_CONTAINER_NAME=beszel-agent

# Como el Agent usa network_mode: host,
# localhost:8090 apunta al Hub publicado en el host.
BESZEL_AGENT_HUB_URL=http://localhost:8090

# Se obtienen desde Beszel al agregar el sistema.
BESZEL_AGENT_TOKEN=
BESZEL_AGENT_KEY=
```

Cambia:

```env
BESZEL_APP_URL=https://monitor.tudominio.com
```

por el dominio que usarás.

---

## 3. Crear `docker-compose.yml`

Crea el archivo:

```bash
nano docker-compose.yml
```

Contenido:

```yaml
services:

  # ==========================================
  # BESZEL HUB
  # Dashboard web
  # ==========================================
  beszel:
    image: ${BESZEL_IMAGE}
    container_name: ${BESZEL_CONTAINER_NAME}
    restart: unless-stopped

    environment:
      APP_URL: ${BESZEL_APP_URL}

    ports:
      - "127.0.0.1:${BESZEL_PORT}:8090"

    volumes:
      - ./beszel_data:/beszel_data
      - ./beszel_socket:/beszel_socket

    healthcheck:
      test:
        [
          "CMD",
          "/beszel",
          "health",
          "--url",
          "http://localhost:8090"
        ]
      interval: 120s
      start_period: 10s
      timeout: 5s


  # ==========================================
  # BESZEL AGENT
  # Monitorea este servidor
  # ==========================================
  beszel-agent:
    image: ${BESZEL_AGENT_IMAGE}
    container_name: ${BESZEL_AGENT_CONTAINER_NAME}
    restart: unless-stopped

    network_mode: host

    volumes:
      - ./beszel_agent_data:/var/lib/beszel-agent
      - ./beszel_socket:/beszel_socket
      - /var/run/docker.sock:/var/run/docker.sock:ro

    environment:
      LISTEN: /beszel_socket/beszel.sock
      HUB_URL: ${BESZEL_AGENT_HUB_URL}
      TOKEN: ${BESZEL_AGENT_TOKEN}
      KEY: ${BESZEL_AGENT_KEY}

    healthcheck:
      test: ["CMD", "/agent", "health"]
      interval: 120s
      start_period: 10s
      timeout: 5s
```

---

## 4. Levantar Beszel

Ejecuta:

```bash
docker compose up -d
```

Comprueba los contenedores:

```bash
docker compose ps
```

Deberías ver:

```text
beszel
beszel-agent
```

También puedes revisar los logs:

```bash
docker logs -f beszel
```

y:

```bash
docker logs -f beszel-agent
```

---

## 5. Configurar Caddy

Beszel solamente está publicado localmente en:

```text
127.0.0.1:8090
```

Esto evita exponer directamente el puerto de Beszel a Internet.

Abre:

```bash
sudo nano /etc/caddy/Caddyfile
```

Agrega:

```caddyfile
monitor.tudominio.com {
    reverse_proxy 127.0.0.1:8090
}
```

Valida la configuración:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

Recarga Caddy:

```bash
sudo systemctl reload caddy
```

Asegúrate también de que el DNS del dominio apunte a la IP del servidor.

Después podrás acceder en:

```text
https://monitor.tudominio.com
```

---

## 6. Crear la cuenta de administrador

En el primer acceso a Beszel deberás crear la cuenta de administrador.

Entra desde el navegador:

```text
https://monitor.tudominio.com
```

Completa el registro inicial.

---

## 7. Agregar el servidor

Dentro de Beszel selecciona:

```text
Add System
```

Como el Hub y el Agent están corriendo en el mismo servidor y comparten el volumen:

```text
./beszel_socket:/beszel_socket
```

usa como dirección del Agent:

```text
/beszel_socket/beszel.sock
```

Beszel mostrará los valores necesarios para autenticar el Agent.

Guarda:

- `TOKEN`
- `KEY`

---

## 8. Agregar TOKEN y KEY al `.env`

Edita:

```bash
nano .env
```

Completa:

```env
BESZEL_AGENT_TOKEN=TU_TOKEN
BESZEL_AGENT_KEY=TU_KEY
```

Guarda el archivo.

---

## 9. Recrear el Agent

Ejecuta:

```bash
docker compose up -d
```

O solamente:

```bash
docker compose up -d --force-recreate beszel-agent
```

Comprueba los logs:

```bash
docker logs -f beszel-agent
```

---

## 10. Verificar el monitoreo

Dentro del dashboard deberías empezar a ver información del servidor:

```text
Servidor
├── CPU
├── RAM
├── Load Average
├── Disco
├── Red
└── Docker
    ├── aplicación-1
    ├── aplicación-2
    ├── mysql
    ├── redis
    ├── n8n
    └── ...
```

Beszel obtiene información de los contenedores mediante:

```text
/var/run/docker.sock
```

El socket está montado como solo lectura:

```yaml
- /var/run/docker.sock:/var/run/docker.sock:ro
```

---

## 11. Crear alertas

Desde la interfaz de Beszel puedes crear alertas para recursos del servidor.

Ejemplos recomendados:

```text
CPU > 80%
RAM > 85%
Disco > 85%
Load Average alto
Servidor no disponible
```

Para CPU, evita alertar por picos momentáneos. Es preferible configurar una duración mínima antes de considerar el evento como problema, si la opción está disponible en la versión instalada.

---

## Comandos útiles

### Ver estado

```bash
docker compose ps
```

### Ver logs del Hub

```bash
docker logs -f beszel
```

### Ver logs del Agent

```bash
docker logs -f beszel-agent
```

### Reiniciar Beszel

```bash
docker compose restart
```

### Detener Beszel

```bash
docker compose down
```

### Volver a levantarlo

```bash
docker compose up -d
```

### Actualizar las imágenes

```bash
docker compose pull
docker compose up -d
```

### Ver consumo de Beszel

```bash
docker stats beszel beszel-agent
```

---

## Seguridad

El Hub está publicado de esta forma:

```yaml
ports:
  - "127.0.0.1:${BESZEL_PORT}:8090"
```

Por lo tanto, el puerto `8090` solamente está disponible desde el propio servidor.

El acceso desde Internet ocurre únicamente mediante:

```text
Internet
   ↓
HTTPS / Caddy
   ↓
127.0.0.1:8090
   ↓
Beszel
```

No es necesario abrir el puerto `8090` en el firewall.

---

## Ubicación de los datos

Los datos persistentes se guardan en:

```text
./beszel_data
```

Los datos del Agent:

```text
./beszel_agent_data
```

Y el socket de comunicación entre Hub y Agent:

```text
./beszel_socket
```

No elimines estas carpetas si quieres conservar la configuración y el histórico.

---

## Respaldo

Para respaldar Beszel puedes comprimir sus datos:

```bash
cd /var/docker/beszel

tar -czf beszel-backup.tar.gz \
    beszel_data \
    beszel_agent_data
```

También conviene conservar:

```text
.env
docker-compose.yml
README.md
```

No publiques el archivo `.env` en un repositorio Git si contiene tokens o llaves privadas.
