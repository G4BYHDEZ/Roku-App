# Checador TV

Canal Roku SceneGraph conectado a una API Express que consulta MySQL.

## API

Requisitos: Node.js 18 o posterior y MySQL 8 o compatible.

Desde PowerShell, ejecuta los comandos dentro de `api`:

```powershell
cd api
npm install
Copy-Item .env.example .env
```

La estructura de tablas está en `api/BD_app_roku.sql`. **Ese script empieza con `DROP DATABASE IF EXISTS checador_db` y borra toda la base existente. No lo ejecutes si quieres conservar los datos actuales.** Solo impórtalo para crear/restablecer una base de desarrollo vacía:

```powershell
cmd /c "mysql -u root -p < BD_app_roku.sql"
```

La API usa `checador_db` y solo necesita lectura de `checadas`, `empleados` y `departamentos`. Crea el usuario de API con permisos de solo lectura:

```powershell
cmd /c "mysql -u root -p < create-api-user.sql"
```

Ese archivo crea `checador_app` en `127.0.0.1` con la contraseña inicial `cambia_esta_clave`. Cámbiala en MySQL y en `api/.env` antes de usar datos reales. Si ya tienes un usuario MySQL, puedes omitirlo y poner sus credenciales en `.env`; debe tener `SELECT` sobre esas tres tablas. Si MySQL está en otro equipo, ajusta el host permitido del usuario al host/IP del servidor Node.

Comprueba que `api/.env` tenga los datos correctos de conexión (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` y `DB_NAME=checador_db`).

Arranca la API:

```powershell
npm start
```

La API escucha en el puerto `3000` y enlaza por defecto a `0.0.0.0`, necesario para que otro dispositivo de la red pueda acceder. Comprueba la conexión a MySQL en `http://localhost:3000/health`. Las rutas para el Roku son:

- `GET /api/roku/checadas`
- `GET /api/roku/retardos`

Ambas devuelven `{ "success": true, "data": [...] }`. Los retardos se identifican en `checadas` mediante `estado = 'RETARDO'`; no se consulta una tabla separada de retardos.

## Conectar el Roku

1. En `components/ApiTask.xml`, cambia el valor de `baseUrl` a `http://<IP_DEL_EQUIPO>:3000/api/roku`. Usa la IP local del equipo con Node.js, no `localhost` ni `127.0.0.1`.
2. Permite conexiones entrantes al puerto `3000` en el firewall y confirma que Roku y equipo estén en la misma red.
3. Con el backend en ejecución, crea el ZIP del canal desde la raíz del proyecto:

   ```powershell
   Compress-Archive -Path .\manifest, .\source, .\components -DestinationPath .\channel.zip -Force
   ```

4. Activa el modo desarrollador en el Roku, abre la página de instalación de desarrolladores en `http://<IP_DEL_ROKU>`, inicia sesión como `rokudev` y carga `channel.zip`.

Para encontrar la IP local del equipo, ejecuta `ipconfig` y toma la dirección IPv4 de la interfaz conectada a la red del Roku.