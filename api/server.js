import 'dotenv/config';
import express from 'express';
import mysql from 'mysql2/promise';

const app = express();
const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || '0.0.0.0';

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'checador_db',
  waitForConnections: true,
  connectionLimit: Number(process.env.DB_CONNECTION_LIMIT || 10),
  dateStrings: true,
});

const checadasQuery = `
  SELECT
    e.numero_empleado,
    TRIM(CONCAT_WS(' ', e.nombre, e.apellido_paterno, NULLIF(e.apellido_materno, ''))) AS nombre_completo,
    d.nombre_departamento,
    DATE_FORMAT(c.fecha_entrada, '%Y-%m-%d %H:%i:%s') AS fecha_entrada,
    CASE
      WHEN c.fecha_salida IS NULL THEN NULL
      ELSE DATE_FORMAT(c.fecha_salida, '%Y-%m-%d %H:%i:%s')
    END AS fecha_salida,
    c.estado
  FROM checadas AS c
  INNER JOIN empleados AS e ON e.id_empleado = c.id_empleado
  INNER JOIN departamentos AS d ON d.id_departamento = e.id_departamento
  WHERE c.fecha_entrada >= CURDATE()
    AND c.fecha_entrada < CURDATE() + INTERVAL 1 DAY
  ORDER BY c.fecha_entrada DESC
`;

const retardosQuery = `
  SELECT
    e.numero_empleado,
    TRIM(CONCAT_WS(' ', e.nombre, e.apellido_paterno, NULLIF(e.apellido_materno, ''))) AS nombre_completo,
    d.nombre_departamento,
    DATE_FORMAT(c.fecha_entrada, '%Y-%m-%d %H:%i:%s') AS fecha_entrada,
    c.estado
  FROM checadas AS c
  INNER JOIN empleados AS e ON e.id_empleado = c.id_empleado
  INNER JOIN departamentos AS d ON d.id_departamento = e.id_departamento
  WHERE c.fecha_entrada >= CURDATE()
    AND c.fecha_entrada < CURDATE() + INTERVAL 1 DAY
    AND c.estado = 'RETARDO'
  ORDER BY c.fecha_entrada DESC
`;

app.get('/health', async (_request, response, next) => {
  try {
    await pool.query('SELECT 1');
    response.json({ success: true, database: 'connected' });
  } catch (error) {
    next(error);
  }
});

app.get('/api/roku/checadas', async (_request, response, next) => {
  try {
    const [rows] = await pool.query(checadasQuery);
    response.json({ success: true, data: rows });
  } catch (error) {
    next(error);
  }
});

app.get('/api/roku/retardos', async (_request, response, next) => {
  try {
    const [rows] = await pool.query(retardosQuery);
    response.json({ success: true, data: rows });
  } catch (error) {
    next(error);
  }
});

app.use((_request, response) => {
  response.status(404).json({ success: false, error: 'Ruta no encontrada' });
});

app.use((error, _request, response, _next) => {
  console.error('Error de API/MySQL:', error.message);
  response.status(503).json({
    success: false,
    error: 'No fue posible consultar la base de datos',
  });
});

const server = app.listen(port, host, () => {
  console.log(`API escuchando en http://${host}:${port}`);
});

process.on('SIGINT', () => {
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
});