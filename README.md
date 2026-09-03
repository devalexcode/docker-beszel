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
├── install.sh
├── .env
├── .env.example
├── README.md
├── beszel_data/
├── beszel_agent_data/
└── beszel_socket/
```

---

## Instalación

### Requisitos

- Docker Engine en ejecución.
- Docker Compose v2 (`docker compose`).
- Permiso para acceder a Docker.

### 1. Obtener el proyecto

```bash
git clone https://github.com/devalexcode/docker-beszel.git
cd docker-beszel
```

### 2. Configurar la URL pública

Crea tu archivo de configuración local y reemplaza la URL de ejemplo por el dominio que usarás:

```bash
cp .env.example .env
nano .env
```

```env
BESZEL_APP_URL=https://monitor.tudominio.com
```

Si ya existe un archivo `.env`, edita ese archivo; el instalador nunca lo sobrescribe. Si omites este paso, el instalador creará `.env` a partir de la plantilla.

### 3. Ejecutar el instalador

```bash
./install.sh
```

El script crea `.env` desde `.env.example` cuando sea necesario, prepara los directorios persistentes y ejecuta `docker compose up -d`.

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

## 4. Configurar Caddy

Beszel solamente está publicado localmente en:

```text
127.0.0.1:7777
```

Esto evita exponer directamente el puerto de Beszel a Internet.

Abre:

```bash
sudo nano /etc/caddy/Caddyfile
```

Agrega:

```caddyfile
monitor.tudominio.com {
    reverse_proxy 127.0.0.1:7777
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

## 5. Crear la cuenta de administrador

En el primer acceso a Beszel deberás crear la cuenta de administrador.

Entra desde el navegador:

```text
https://monitor.tudominio.com
```

Completa el registro inicial.

---

## 6. Agregar el servidor

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

## 7. Agregar TOKEN y KEY al `.env`

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

## 8. Recrear el Agent

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

## 9. Verificar el monitoreo

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

## 10. Crear alertas

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

## Seguridad

Las imágenes están fijadas a la versión `0.18.8`. Actualízalas de forma controlada y mantén Hub y Agent en la misma versión; no sustituyas esas referencias por `latest`.

El Hub está publicado de esta forma:

```yaml
ports:
  - "127.0.0.1:${BESZEL_PORT}:8090"
```

Por lo tanto, el puerto `7777` solamente está disponible desde el propio servidor.

El acceso desde Internet ocurre únicamente mediante:

```text
Internet
   ↓
HTTPS / Caddy
   ↓
127.0.0.1:7777
   ↓
Beszel
```

No es necesario abrir el puerto `7777` en el firewall.

El Agent usa `network_mode: host` y acceso al socket Docker para recopilar métricas. Esos permisos son necesarios para esta configuración, pero hacen que el Agent sea un componente de alta confianza: no expongas el Hub sin HTTPS y no concedas cuentas a usuarios no confiables.

Como capas adicionales, ambos contenedores usan sistema de archivos de solo lectura, eliminan todas las capacidades Linux, impiden ganar privilegios, limitan procesos/recursos y rotan sus logs.

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
