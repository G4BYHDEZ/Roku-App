/* ============================================================
   SISTEMA DE CHECADOR - SMART DISPLAY / TV
   ============================================================

   Base de datos:
       checador_db

   Arquitectura:
       MySQL
          ↓
       Node.js + Express API
          ↓
       ┌─────────────────────┐
       │                     │
       App móvil         Smart TV
       │                     │
       └─────────────────────┘

   FUNCIONES PRINCIPALES:

   APP MÓVIL:
       - Identificar empleado mediante número de empleado
       - Consultar información del empleado
       - Validar huella / rostro mediante el teléfono
       - Registrar entrada
       - Registrar salida
       - Consultar estado de la checada

   SMART TV:
       - Consultar retardos del día
       - Mostrar empleados con retardo
       - Mostrar información de las checadas

   ADMINISTRADOR:
       - Administrar administradores
       - Administrar departamentos
       - Administrar empleados
       - Administrar horarios
       - Consultar empleados
       - Consultar checadas
       - Consultar historial
       - Generar reportes

   IMPORTANTE:

   1. Las huellas y rostros NO se almacenan en MySQL.
      La biometría es validada por el sistema operativo
      del teléfono.

   2. Las fotografías se almacenan como archivos.
      MySQL solamente guarda la ruta o URL.

   3. La hora de entrada/salida se toma del servidor MySQL.

   4. Los empleados no se eliminan físicamente.
      Se utiliza activo = FALSE para conservar su historial.

   5. No utilizamos una columna "checada_abierta".
      Las entradas abiertas se detectan mediante:

          fecha_salida IS NULL

   6. No se utilizan triggers.
      La integridad se controla mediante:
          - Foreign Keys
          - Unique
          - Check
          - Procedures
          - Transacciones

   ============================================================ */


/* ============================================================
   1. ELIMINAR BASE DE DATOS ANTERIOR
   ============================================================

   ADVERTENCIA:

   Esto elimina absolutamente todo lo que exista dentro de
   checador_db.

   UTILIZAR SOLAMENTE EN DESARROLLO / PRUEBAS.

   NO ejecutar esto en producción porque elimina:
       - empleados
       - administradores
       - horarios
       - checadas
       - procedimientos
       - todos los datos
   ============================================================ */

DROP DATABASE IF EXISTS checador_db;


/* ============================================================
   2. CREAR BASE DE DATOS
   ============================================================ */

CREATE DATABASE checador_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;


/* ============================================================
   3. SELECCIONAR BASE DE DATOS
   ============================================================ */

USE checador_db;


/* ============================================================
   4. TABLA: admin
   ============================================================

   Usuarios administradores del sistema.

   password_hash:
       Nunca almacenar la contraseña original.

       El backend debe generar el hash utilizando:
           - bcrypt
           - Argon2
           - u otro algoritmo seguro

   El procedimiento sp_login_admin devuelve el hash para que
   Node.js pueda comparar la contraseña enviada por el usuario.
   ============================================================ */

CREATE TABLE admin (

    id_admin INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    usuario VARCHAR(50) NOT NULL UNIQUE,

    password_hash VARCHAR(255) NOT NULL,

    nombre VARCHAR(100) NOT NULL,

    fecha_creacion DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    activo BOOLEAN NOT NULL
        DEFAULT TRUE
);


/* ============================================================
   5. TABLA: departamentos
   ============================================================ */

CREATE TABLE departamentos (

    id_departamento INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    nombre_departamento VARCHAR(100) NOT NULL UNIQUE,

    descripcion VARCHAR(255),

    activo BOOLEAN NOT NULL
        DEFAULT TRUE,

    fecha_creacion DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


/* ============================================================
   6. TABLA: empleados
   ============================================================

   Información principal del empleado.

   numero_empleado:
       Identificador que el empleado utilizará para entrar
       a la aplicación móvil.

   Ejemplo:

       EMP001
       EMP002
       10025

   foto_url:
       Ruta de la fotografía del empleado.

   activo:
       Permite desactivar empleados sin eliminar su historial.
   ============================================================ */

CREATE TABLE empleados (

    id_empleado INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero_empleado VARCHAR(20) NULL UNIQUE,

    nombre VARCHAR(100) NOT NULL,

    apellido_paterno VARCHAR(100) NOT NULL,

    apellido_materno VARCHAR(100),

    id_departamento INT UNSIGNED NOT NULL,

    password_hash VARCHAR(255) NOT NULL,
    
    foto_url VARCHAR(500),

    activo BOOLEAN NOT NULL
        DEFAULT TRUE,

    fecha_ingreso DATE,

    fecha_creacion DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_empleado_departamento

        FOREIGN KEY (id_departamento)

        REFERENCES departamentos(id_departamento)

        ON UPDATE CASCADE

        ON DELETE RESTRICT
);


/* ============================================================
   7. TABLA: horarios
   ============================================================

   Un empleado puede tener un horario diferente cada día.

   dia_semana:

       1 = Lunes
       2 = Martes
       3 = Miércoles
       4 = Jueves
       5 = Viernes
       6 = Sábado
       7 = Domingo

   Ejemplo:

       Lunes:
           08:00 - 17:00
           tolerancia 10 minutos

       Martes:
           08:00 - 17:00
           tolerancia 10 minutos

   También se permiten horarios nocturnos:

       22:00 - 06:00

   Un empleado solamente puede tener un horario por día.
   ============================================================ */

CREATE TABLE horarios (

    id_horario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    id_empleado INT UNSIGNED NOT NULL,

    dia_semana TINYINT UNSIGNED NOT NULL,

    hora_entrada TIME NOT NULL,

    hora_salida TIME NOT NULL,

    tolerancia_minutos TINYINT UNSIGNED NOT NULL
        DEFAULT 10,

    CONSTRAINT fk_horario_empleado

        FOREIGN KEY (id_empleado)

        REFERENCES empleados(id_empleado)

        ON UPDATE CASCADE

        ON DELETE CASCADE,

    CONSTRAINT chk_dia_semana

        CHECK (
            dia_semana BETWEEN 1 AND 7
        ),

    CONSTRAINT chk_horas_horario

        CHECK (
            hora_entrada <> hora_salida
        ),

    CONSTRAINT uk_empleado_dia

        UNIQUE (
            id_empleado,
            dia_semana
        )
);


/* ============================================================
   8. TABLA: checadas
   ============================================================

   Registra las entradas y salidas.

   Una fila representa una jornada:

       fecha_entrada
       fecha_salida

   Si:

       fecha_salida IS NULL

   significa que el empleado todavía tiene una entrada abierta.

   estado:

       A_TIEMPO
       RETARDO

   Las fotografías se almacenan fuera de MySQL.
   ============================================================ */

CREATE TABLE checadas (

    id_checada BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    id_empleado INT UNSIGNED NOT NULL,

    fecha_entrada DATETIME NOT NULL,

    fecha_salida DATETIME NULL,

    estado ENUM(
        'A_TIEMPO',
        'RETARDO'
    ) NOT NULL,

    foto_entrada_url VARCHAR(500),

    foto_salida_url VARCHAR(500),

    observaciones VARCHAR(255),

    fecha_creacion DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_fecha_salida

        CHECK (
            fecha_salida IS NULL

            OR fecha_salida >= fecha_entrada
        ),

    CONSTRAINT fk_checadas_empleado

        FOREIGN KEY (id_empleado)

        REFERENCES empleados(id_empleado)

        ON UPDATE CASCADE

        ON DELETE RESTRICT
);


/* ============================================================
   9. ÍNDICES
   ============================================================ */

CREATE INDEX idx_empleados_departamento
ON empleados(id_departamento);


CREATE INDEX idx_horarios_empleado
ON horarios(id_empleado);


CREATE INDEX idx_checadas_empleado
ON checadas(id_empleado);


CREATE INDEX idx_checadas_fecha_entrada
ON checadas(fecha_entrada);


CREATE INDEX idx_checadas_empleado_salida
ON checadas(
    id_empleado,
    fecha_salida
);


/* ============================================================
   10. PROCEDIMIENTOS ALMACENADOS
   ============================================================ */

DELIMITER //


/* ============================================================
   10.1 VERIFICAR ADMINISTRADOR
   ============================================================

   Procedimiento auxiliar.

   Comprueba que:
       - el administrador exista
       - esté activo

   Se utiliza dentro de todos los procedures administrativos.
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_verificar_admin//

CREATE PROCEDURE sp_verificar_admin(

    IN p_id_admin INT UNSIGNED,

    OUT p_es_admin BOOLEAN

)
BEGIN

    SET p_es_admin = FALSE;


    SELECT EXISTS (

        SELECT 1

        FROM admin

        WHERE id_admin = p_id_admin

          AND activo = TRUE

    )

    INTO p_es_admin;

END//


/* ============================================================
   10.2 LOGIN ADMINISTRADOR
   ============================================================

   Busca un administrador por usuario.

   IMPORTANTE:

   Este procedure NO compara la contraseña.

   Node.js debe hacer:

       contraseña enviada
              ↓
       bcrypt.compare()
              ↓
       password_hash

   No requiere p_id_admin porque se utiliza antes de
   autenticarse.
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_login_admin//

CREATE PROCEDURE sp_login_admin(

    IN p_usuario VARCHAR(50)

)
BEGIN

    SELECT

        id_admin,

        usuario,

        password_hash,

        nombre,

        activo,

        fecha_creacion

    FROM admin

    WHERE usuario = TRIM(p_usuario)

    LIMIT 1;

END//


/* ============================================================
   11. ADMINISTRADORES
   ============================================================ */


/* ============================================================
   CREAR ADMINISTRADOR
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_crear_admin//

CREATE PROCEDURE sp_crear_admin(

    IN p_id_admin INT UNSIGNED,

    IN p_usuario VARCHAR(50),

    IN p_password_hash VARCHAR(255),

    IN p_nombre VARCHAR(100)

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF TRIM(p_usuario) = ''
       OR TRIM(p_password_hash) = ''
       OR TRIM(p_nombre) = '' THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'Usuario, contraseña y nombre son obligatorios.';

    END IF;


    IF EXISTS (

        SELECT 1

        FROM admin

        WHERE usuario = TRIM(p_usuario)

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El usuario de administrador ya existe.';

    END IF;


    INSERT INTO admin (

        usuario,
        password_hash,
        nombre

    )

    VALUES (

        TRIM(p_usuario),
        p_password_hash,
        TRIM(p_nombre)

    );


    SELECT

        TRUE AS exito,

        LAST_INSERT_ID() AS id_admin,

        'Administrador creado correctamente.' AS mensaje;

END//


/* ============================================================
   LISTAR ADMINISTRADORES
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_listar_admins//

CREATE PROCEDURE sp_listar_admins(

    IN p_id_admin INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    SELECT

        id_admin,
        usuario,
        nombre,
        activo,
        fecha_creacion

    FROM admin

    ORDER BY nombre ASC;

END//


/* ============================================================
   ACTUALIZAR ADMINISTRADOR
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_actualizar_admin//

CREATE PROCEDURE sp_actualizar_admin(

    IN p_id_admin INT UNSIGNED,

    IN p_id_admin_editar INT UNSIGNED,

    IN p_usuario VARCHAR(50),

    IN p_nombre VARCHAR(100)

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF TRIM(p_usuario) = ''
       OR TRIM(p_nombre) = '' THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'Usuario y nombre son obligatorios.';

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM admin

        WHERE id_admin = p_id_admin_editar

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El administrador no existe.';

    END IF;


    IF EXISTS (

        SELECT 1

        FROM admin

        WHERE usuario = TRIM(p_usuario)

          AND id_admin <> p_id_admin_editar

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El usuario ya pertenece a otro administrador.';

    END IF;


    UPDATE admin

    SET

        usuario = TRIM(p_usuario),

        nombre = TRIM(p_nombre)

    WHERE id_admin = p_id_admin_editar;


    SELECT

        TRUE AS exito,

        'Administrador actualizado correctamente.'
            AS mensaje;

END//


/* ============================================================
   CAMBIAR CONTRASEÑA
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_cambiar_password_admin//

CREATE PROCEDURE sp_cambiar_password_admin(

    IN p_id_admin INT UNSIGNED,

    IN p_id_admin_editar INT UNSIGNED,

    IN p_password_hash VARCHAR(255)

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF TRIM(p_password_hash) = '' THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'La contraseña no puede estar vacía.';

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM admin

        WHERE id_admin = p_id_admin_editar

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El administrador no existe.';

    END IF;


    UPDATE admin

    SET password_hash = p_password_hash

    WHERE id_admin = p_id_admin_editar;


    SELECT

        TRUE AS exito,

        'Contraseña actualizada correctamente.'
            AS mensaje;

END//


/* ============================================================
   DESACTIVAR ADMINISTRADOR
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_desactivar_admin//

CREATE PROCEDURE sp_desactivar_admin(

    IN p_id_admin INT UNSIGNED,

    IN p_id_admin_desactivar INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;

    DECLARE v_activos INT DEFAULT 0;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM admin

        WHERE id_admin = p_id_admin_desactivar

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El administrador no existe.';

    END IF;


    SELECT COUNT(*)

    INTO v_activos

    FROM admin

    WHERE activo = TRUE;


    IF p_id_admin_desactivar = p_id_admin
       AND v_activos <= 1 THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'No se puede desactivar al ultimo administrador activo.';

    END IF;


    UPDATE admin

    SET activo = FALSE

    WHERE id_admin = p_id_admin_desactivar;


    SELECT

        TRUE AS exito,

        'Administrador desactivado correctamente.'
            AS mensaje;

END//


/* ============================================================
   ACTIVAR ADMINISTRADOR
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_activar_admin//

CREATE PROCEDURE sp_activar_admin(

    IN p_id_admin INT UNSIGNED,

    IN p_id_admin_activar INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM admin

        WHERE id_admin = p_id_admin_activar

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El administrador no existe.';

    END IF;


    UPDATE admin

    SET activo = TRUE

    WHERE id_admin = p_id_admin_activar;


    SELECT

        TRUE AS exito,

        'Administrador activado correctamente.'
            AS mensaje;

END//


/* ============================================================
   12. DEPARTAMENTOS
   ============================================================ */


/* ============================================================
   CREAR DEPARTAMENTO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_crear_departamento//

CREATE PROCEDURE sp_crear_departamento(

    IN p_id_admin INT UNSIGNED,

    IN p_nombre VARCHAR(100),

    IN p_descripcion VARCHAR(255)

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF TRIM(p_nombre) = '' THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El nombre del departamento es obligatorio.';

    END IF;


    IF EXISTS (

        SELECT 1

        FROM departamentos

        WHERE nombre_departamento = TRIM(p_nombre)

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El departamento ya existe.';

    END IF;


    INSERT INTO departamentos (

        nombre_departamento,
        descripcion

    )

    VALUES (

        TRIM(p_nombre),

        NULLIF(
            TRIM(p_descripcion),
            ''
        )

    );


    SELECT

        TRUE AS exito,

        LAST_INSERT_ID() AS id_departamento,

        'Departamento creado correctamente.'
            AS mensaje;

END//


/* ============================================================
   LISTAR DEPARTAMENTOS
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_listar_departamentos//

CREATE PROCEDURE sp_listar_departamentos(

    IN p_id_admin INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    SELECT

        id_departamento,
        nombre_departamento,
        descripcion,
        activo,
        fecha_creacion

    FROM departamentos

    ORDER BY nombre_departamento ASC;

END//


/* ============================================================
   ACTUALIZAR DEPARTAMENTO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_actualizar_departamento//

CREATE PROCEDURE sp_actualizar_departamento(

    IN p_id_admin INT UNSIGNED,

    IN p_id_departamento INT UNSIGNED,

    IN p_nombre VARCHAR(100),

    IN p_descripcion VARCHAR(255)

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF TRIM(p_nombre) = '' THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El nombre del departamento es obligatorio.';

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM departamentos

        WHERE id_departamento = p_id_departamento

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El departamento no existe.';

    END IF;


    IF EXISTS (

        SELECT 1

        FROM departamentos

        WHERE nombre_departamento = TRIM(p_nombre)

          AND id_departamento <> p_id_departamento

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'Ya existe otro departamento con ese nombre.';

    END IF;


    UPDATE departamentos

    SET

        nombre_departamento = TRIM(p_nombre),

        descripcion =
            NULLIF(
                TRIM(p_descripcion),
                ''
            )

    WHERE id_departamento = p_id_departamento;


    SELECT

        TRUE AS exito,

        'Departamento actualizado correctamente.'
            AS mensaje;

END//


/* ============================================================
   ACTIVAR DEPARTAMENTO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_activar_departamento//

CREATE PROCEDURE sp_activar_departamento(

    IN p_id_admin INT UNSIGNED,

    IN p_id_departamento INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM departamentos

        WHERE id_departamento = p_id_departamento

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El departamento no existe.';

    END IF;


    UPDATE departamentos

    SET activo = TRUE

    WHERE id_departamento = p_id_departamento;


    SELECT

        TRUE AS exito,

        'Departamento activado correctamente.'
            AS mensaje;

END//


/* ============================================================
   DESACTIVAR DEPARTAMENTO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_desactivar_departamento//

CREATE PROCEDURE sp_desactivar_departamento(

    IN p_id_admin INT UNSIGNED,

    IN p_id_departamento INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM departamentos

        WHERE id_departamento = p_id_departamento

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El departamento no existe.';

    END IF;


    UPDATE departamentos

    SET activo = FALSE

    WHERE id_departamento = p_id_departamento;


    SELECT

        TRUE AS exito,

        'Departamento desactivado correctamente.'
            AS mensaje;

END//


/* ============================================================
   13. EMPLEADOS
   ============================================================ */


/* ============================================================
   CREAR EMPLEADO
   ============================================================ */

/* ============================================================
   CREAR EMPLEADO CON NUMERO AUTOMATICO
   ============================================================

   Este procedimiento crea un empleado y genera automáticamente
   su numero de empleado.

   FORMATO:

       EMP001
       EMP002
       EMP003
       EMP004
       ...

   ¿Cómo funciona?

       1. Se inserta el empleado sin numero de empleado.
       2. MySQL genera automáticamente id_empleado.
       3. Se obtiene el ID generado con LAST_INSERT_ID().
       4. Se construye el numero:

              EMP + ID con 3 digitos

          Ejemplo:

              id_empleado = 1
              numero = EMP001

              id_empleado = 25
              numero = EMP025

       5. Se actualiza el empleado con ese numero.

   IMPORTANTE:

       El usuario NO necesita enviar numero_empleado.

       El backend solamente necesita enviar:

           - id_admin
           - nombre
           - apellido_paterno
           - apellido_materno
           - id_departamento
           - foto_url
           - fecha_ingreso

   ============================================================ */

DROP PROCEDURE IF EXISTS sp_crear_empleado//

CREATE PROCEDURE sp_crear_empleado(
    IN p_id_admin INT UNSIGNED,
    IN p_nombre VARCHAR(100),
    IN p_apellido_paterno VARCHAR(100),
    IN p_apellido_materno VARCHAR(100),
    IN p_id_departamento INT UNSIGNED,
    IN p_password_hash VARCHAR(255),
    IN p_foto_url VARCHAR(500),
    IN p_fecha_ingreso DATE
)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;
    DECLARE v_id_empleado INT UNSIGNED;
    DECLARE v_numero_empleado VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Verificar que quien crea al empleado sea administrador
    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );

    IF v_es_admin = FALSE THEN
        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;
        LEAVE admin_proc;
    END IF;

    -- Validar nombre y apellido
    IF TRIM(p_nombre) = ''
       OR TRIM(p_apellido_paterno) = '' THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Nombre y apellido paterno son obligatorios.';

    END IF;

    -- Verificar que el departamento exista y esté activo
    IF NOT EXISTS (
        SELECT 1
        FROM departamentos
        WHERE id_departamento = p_id_departamento
          AND activo = TRUE
    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'El departamento no existe o esta inactivo.';

    END IF;

IF TRIM(p_password_hash) = '' THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT =
        'La contraseña del empleado es obligatoria.';
END IF;
    START TRANSACTION;

    -- Crear empleado sin número
    INSERT INTO empleados (
        numero_empleado,
        nombre,
        apellido_paterno,
        apellido_materno,
        id_departamento,
        password_hash,
        foto_url,
        fecha_ingreso
    )
    VALUES (
        NULL,
        TRIM(p_nombre),
        TRIM(p_apellido_paterno),
        NULLIF(TRIM(p_apellido_materno), ''),
        p_id_departamento,
        p_password_hash,
        NULLIF(TRIM(p_foto_url), ''),
        p_fecha_ingreso
    );

    -- Obtener ID generado automáticamente
    SET v_id_empleado = LAST_INSERT_ID();

    -- Generar número: EMP001, EMP002, EMP003...
    SET v_numero_empleado = CONCAT(
        'EMP',
        LPAD(v_id_empleado, 3, '0')
    );

    -- Guardar número generado
    UPDATE empleados
    SET numero_empleado = v_numero_empleado
    WHERE id_empleado = v_id_empleado;

    COMMIT;

    -- Devolver empleado creado
    SELECT
        TRUE AS exito,
        e.id_empleado,
        e.numero_empleado,
        e.nombre,
        e.apellido_paterno,
        e.apellido_materno,
        e.id_departamento,
        d.nombre_departamento,
        e.foto_url,
        e.activo,
        e.fecha_ingreso,
        'Empleado creado correctamente.' AS mensaje
    FROM empleados e
    INNER JOIN departamentos d
        ON d.id_departamento = e.id_departamento
    WHERE e.id_empleado = v_id_empleado
    LIMIT 1;

END//
/* ============================================================
   LISTAR TODOS LOS EMPLEADOS
   ============================================================

   USO:

       Panel administrativo

   Devuelve:
       - información personal
       - departamento
       - fotografía
       - estado
       - fecha de ingreso
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_listar_empleados//

CREATE PROCEDURE sp_listar_empleados(

    IN p_id_admin INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    SELECT

        e.id_empleado,

        e.numero_empleado,

        e.nombre,

        e.apellido_paterno,

        e.apellido_materno,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        e.id_departamento,

        d.nombre_departamento,

        e.foto_url,

        e.activo,

        e.fecha_ingreso,

        e.fecha_creacion

    FROM empleados e

    INNER JOIN departamentos d

        ON d.id_departamento =
           e.id_departamento

    ORDER BY

        e.apellido_paterno ASC,

        e.nombre ASC;

END//


/* ============================================================
   OBTENER EMPLEADO POR ID
   ============================================================

   Para el administrador.

   Permite consultar los datos de un empleado específico.
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_obtener_empleado//

CREATE PROCEDURE sp_obtener_empleado(

    IN p_id_admin INT UNSIGNED,

    IN p_id_empleado INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    SELECT

        e.id_empleado,

        e.numero_empleado,

        e.nombre,

        e.apellido_paterno,

        e.apellido_materno,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        e.id_departamento,

        d.nombre_departamento,

        e.foto_url,

        e.activo,

        e.fecha_ingreso,

        e.fecha_creacion

    FROM empleados e

    INNER JOIN departamentos d

        ON d.id_departamento =
           e.id_departamento

    WHERE e.id_empleado = p_id_empleado

    LIMIT 1;

END//


/* ============================================================
   LOGIN DE EMPLEADO
   ============================================================

   ESTE ES EL PROCEDIMIENTO QUE FALTABA PARA EL FLUJO
   DE LA APLICACION MOVIL.

   La app móvil envía:

       numero_empleado

   Ejemplo:

       EMP001

   El procedure devuelve los datos necesarios para que
   la aplicación identifique al empleado.

   NO necesita administrador.

   IMPORTANTE:

   Este procedure NO valida biometría.

   El flujo correcto es:

       1. Empleado escribe numero.
       2. API consulta este procedure.
       3. App muestra/identifica al empleado.
       4. Teléfono solicita huella/rostro.
       5. Si la biometría es correcta:
          se permite registrar entrada/salida.
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_login_empleado//

CREATE PROCEDURE sp_login_empleado(

    IN p_numero_empleado VARCHAR(20)

)
BEGIN

    SELECT

        e.id_empleado,

        e.numero_empleado,

		e.password_hash,
        
        e.nombre,

        e.apellido_paterno,

        e.apellido_materno,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        e.id_departamento,
		

        d.nombre_departamento,
        
        e.foto_url,

        e.activo,

        e.fecha_ingreso

    FROM empleados e

    INNER JOIN departamentos d

        ON d.id_departamento =
           e.id_departamento

    WHERE e.numero_empleado =
        TRIM(p_numero_empleado)

      AND e.activo = TRUE

    LIMIT 1;

END//


/* ============================================================
   OBTENER EMPLEADO POR NUMERO
   ============================================================

   Similar al login, pero puede utilizarse para consultar
   los datos del empleado después de que ya inició sesión.

   NO necesita administrador.

   La diferencia conceptual:

       sp_login_empleado
           -> identificación inicial

       sp_obtener_empleado_numero
           -> consulta posterior mediante número
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_obtener_empleado_numero//

CREATE PROCEDURE sp_obtener_empleado_numero(

    IN p_numero_empleado VARCHAR(20)

)
BEGIN

    SELECT

        e.id_empleado,

        e.numero_empleado,

        e.nombre,

        e.apellido_paterno,

        e.apellido_materno,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        e.id_departamento,

        d.nombre_departamento,

        e.foto_url,

        e.activo,

        e.fecha_ingreso

    FROM empleados e

    INNER JOIN departamentos d

        ON d.id_departamento =
           e.id_departamento

    WHERE e.numero_empleado =
        TRIM(p_numero_empleado)

    LIMIT 1;

END//


/* ============================================================
   ACTUALIZAR EMPLEADO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_actualizar_empleado//

CREATE PROCEDURE sp_actualizar_empleado(

    IN p_id_admin INT UNSIGNED,

    IN p_id_empleado INT UNSIGNED,

    IN p_numero_empleado VARCHAR(20),

    IN p_nombre VARCHAR(100),

    IN p_apellido_paterno VARCHAR(100),

    IN p_apellido_materno VARCHAR(100),

    IN p_id_departamento INT UNSIGNED,

    IN p_foto_url VARCHAR(500),

    IN p_fecha_ingreso DATE

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF TRIM(p_numero_empleado) = ''
       OR TRIM(p_nombre) = ''
       OR TRIM(p_apellido_paterno) = '' THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'Numero, nombre y apellido paterno son obligatorios.';

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM empleados

        WHERE id_empleado = p_id_empleado

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado no existe.';

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM departamentos

        WHERE id_departamento = p_id_departamento

          AND activo = TRUE

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El departamento no existe o esta inactivo.';

    END IF;


    IF EXISTS (

        SELECT 1

        FROM empleados

        WHERE numero_empleado =
            TRIM(p_numero_empleado)

          AND id_empleado <> p_id_empleado

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El numero de empleado ya pertenece a otro empleado.';

    END IF;


    UPDATE empleados

    SET

        numero_empleado =
            TRIM(p_numero_empleado),

        nombre =
            TRIM(p_nombre),

        apellido_paterno =
            TRIM(p_apellido_paterno),

        apellido_materno =
            NULLIF(
                TRIM(p_apellido_materno),
                ''
            ),

        id_departamento =
            p_id_departamento,

        foto_url =
            NULLIF(
                TRIM(p_foto_url),
                ''
            ),

        fecha_ingreso =
            p_fecha_ingreso

    WHERE id_empleado = p_id_empleado;


    SELECT

        TRUE AS exito,

        'Empleado actualizado correctamente.'
            AS mensaje;

END//

/* ============================================================
   CAMBIAR CONTRASEÑA DE EMPLEADO
   ============================================================

   Permite que un administrador cambie o restablezca la contraseña
   de un empleado.

   IMPORTANTE:
       - El administrador debe estar activo.
       - El backend debe generar el hash antes de llamar al procedure.
       - Nunca se recibe ni se almacena la contraseña original.
       - El procedure no devuelve el password_hash.
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_cambiar_password_empleado//

CREATE PROCEDURE sp_cambiar_password_empleado(

    IN p_id_admin INT UNSIGNED,

    IN p_numero_empleado VARCHAR(255),

    IN p_password_hash VARCHAR(255)

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;

    /* ========================================================
       1. Verificar administrador
       ======================================================== */

    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );

    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;

    /* ========================================================
       2. Validar hash
       ======================================================== */

    IF TRIM(p_password_hash) = '' THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'La contraseña del empleado es obligatoria.';

    END IF;

    /* ========================================================
       3. Verificar que el empleado exista
       ======================================================== */

    IF NOT EXISTS (

        SELECT 1
        FROM empleados
        WHERE numero_empleado = p_numero_empleado

    ) THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'El empleado no existe.';

    END IF;

    /* ========================================================
       4. Actualizar únicamente el hash
       ======================================================== */

    UPDATE empleados

    SET password_hash = p_password_hash

    WHERE numero_empleado = p_numero_empleado;

    /* No devolver el hash por seguridad. */
    SELECT
        TRUE AS exito,
        'Contraseña del empleado actualizada correctamente.'
            AS mensaje;

END//


/* ============================================================
   ACTIVAR EMPLEADO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_activar_empleado//

CREATE PROCEDURE sp_activar_empleado(

    IN p_id_admin INT UNSIGNED,

    IN p_id_empleado INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM empleados

        WHERE id_empleado = p_id_empleado

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado no existe.';

    END IF;


    UPDATE empleados

    SET activo = TRUE

    WHERE id_empleado = p_id_empleado;


    SELECT

        TRUE AS exito,

        'Empleado activado correctamente.'
            AS mensaje;

END//


/* ============================================================
   DESACTIVAR EMPLEADO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_desactivar_empleado//

CREATE PROCEDURE sp_desactivar_empleado(

    IN p_id_admin INT UNSIGNED,

    IN p_id_empleado INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM empleados

        WHERE id_empleado = p_id_empleado

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado no existe.';

    END IF;


    UPDATE empleados

    SET activo = FALSE

    WHERE id_empleado = p_id_empleado;


    SELECT

        TRUE AS exito,

        'Empleado desactivado correctamente.'
            AS mensaje;

END//


/* ============================================================
   14. HORARIOS
   ============================================================ */


/* ============================================================
   CREAR HORARIO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_crear_horario//

CREATE PROCEDURE sp_crear_horario(

    IN p_id_admin INT UNSIGNED,

    IN p_id_empleado INT UNSIGNED,

    IN p_dia_semana TINYINT UNSIGNED,

    IN p_hora_entrada TIME,

    IN p_hora_salida TIME,

    IN p_tolerancia_minutos TINYINT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF p_dia_semana < 1
       OR p_dia_semana > 7 THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El dia de semana debe estar entre 1 y 7.';

    END IF;


    IF p_hora_entrada = p_hora_salida THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'La hora de entrada y salida no pueden ser iguales.';

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM empleados

        WHERE id_empleado = p_id_empleado

          AND activo = TRUE

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado no existe o esta inactivo.';

    END IF;


    IF EXISTS (

        SELECT 1

        FROM horarios

        WHERE id_empleado = p_id_empleado

          AND dia_semana = p_dia_semana

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado ya tiene horario para ese dia.';

    END IF;


    INSERT INTO horarios (

        id_empleado,

        dia_semana,

        hora_entrada,

        hora_salida,

        tolerancia_minutos

    )

    VALUES (

        p_id_empleado,

        p_dia_semana,

        p_hora_entrada,

        p_hora_salida,

        COALESCE(
            p_tolerancia_minutos,
            10
        )

    );


    SELECT

        TRUE AS exito,

        LAST_INSERT_ID() AS id_horario,

        'Horario creado correctamente.'
            AS mensaje;

END//



DELIMITER ;
/* ============================================================
   LISTAR HORARIOS DE UN EMPLEADO
   Puede buscar por ID o por número de empleado.
   El parámetro que no se use debe enviarse como NULL.
   ============================================================ */

DELIMITER //

DROP PROCEDURE IF EXISTS sp_listar_horarios_empleado//

CREATE PROCEDURE sp_listar_horarios_empleado(

    IN p_id_admin INT UNSIGNED,
    IN p_id_empleado INT UNSIGNED,
    IN p_numero_empleado VARCHAR(20)

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    SELECT

        h.id_horario,

        h.id_empleado,

        e.numero_empleado,

        CONCAT(
            e.nombre,
            ' ',
            e.apellido_paterno,
            IF(
                e.apellido_materno IS NULL
                OR e.apellido_materno = '',
                '',
                CONCAT(' ', e.apellido_materno)
            )
        ) AS nombre_completo,

        h.dia_semana,

        CASE h.dia_semana

            WHEN 1 THEN 'Lunes'
            WHEN 2 THEN 'Martes'
            WHEN 3 THEN 'Miercoles'
            WHEN 4 THEN 'Jueves'
            WHEN 5 THEN 'Viernes'
            WHEN 6 THEN 'Sabado'
            WHEN 7 THEN 'Domingo'

        END AS nombre_dia,

        h.hora_entrada,

        h.hora_salida,

        h.tolerancia_minutos

    FROM horarios h

    INNER JOIN empleados e
        ON e.id_empleado = h.id_empleado

    WHERE

        (
            p_id_empleado IS NULL
            OR h.id_empleado = p_id_empleado
        )

        AND

        (
            p_numero_empleado IS NULL
            OR e.numero_empleado = p_numero_empleado
        )

    ORDER BY
        h.dia_semana ASC;

END//





/* ============================================================
   ACTUALIZAR HORARIO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_actualizar_horario//

CREATE PROCEDURE sp_actualizar_horario(

    IN p_id_admin INT UNSIGNED,

    IN p_id_horario INT UNSIGNED,

    IN p_dia_semana TINYINT UNSIGNED,

    IN p_hora_entrada TIME,

    IN p_hora_salida TIME,

    IN p_tolerancia_minutos TINYINT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;

    DECLARE v_id_empleado INT UNSIGNED DEFAULT NULL;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF p_dia_semana < 1
       OR p_dia_semana > 7 THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El dia de semana debe estar entre 1 y 7.';

    END IF;


    IF p_hora_entrada = p_hora_salida THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'La hora de entrada y salida no pueden ser iguales.';

    END IF;


    SELECT id_empleado

    INTO v_id_empleado

    FROM horarios

    WHERE id_horario = p_id_horario

    LIMIT 1;


    IF v_id_empleado IS NULL THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El horario no existe.';

    END IF;


    IF EXISTS (

        SELECT 1

        FROM horarios

        WHERE id_empleado = v_id_empleado

          AND dia_semana = p_dia_semana

          AND id_horario <> p_id_horario

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado ya tiene otro horario para ese dia.';

    END IF;


    UPDATE horarios

    SET

        dia_semana = p_dia_semana,

        hora_entrada = p_hora_entrada,

        hora_salida = p_hora_salida,

        tolerancia_minutos =
            COALESCE(
                p_tolerancia_minutos,
                10
            )

    WHERE id_horario = p_id_horario;


    SELECT

        TRUE AS exito,

        'Horario actualizado correctamente.'
            AS mensaje;

END//


/* ============================================================
   ELIMINAR HORARIO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_eliminar_horario//

CREATE PROCEDURE sp_eliminar_horario(

    IN p_id_admin INT UNSIGNED,

    IN p_id_horario INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM horarios

        WHERE id_horario = p_id_horario

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El horario no existe.';

    END IF;


    DELETE FROM horarios

    WHERE id_horario = p_id_horario;


    SELECT

        TRUE AS exito,

        'Horario eliminado correctamente.'
            AS mensaje;

END//


/* ============================================================
   15. PROCEDIMIENTOS PARA APP MOVIL
   ============================================================ */


/* ============================================================
   BUSCAR EMPLEADO
   ============================================================

   Permite realizar búsquedas por:

       - número
       - nombre
       - apellido paterno
       - apellido materno

   NO requiere administrador.
   ============================================================ */


DROP PROCEDURE IF EXISTS sp_buscar_empleado//

CREATE PROCEDURE sp_buscar_empleado(

    IN p_id_empleado INT UNSIGNED,

    IN p_numero_empleado VARCHAR(20),

    IN p_nombre VARCHAR(100),

    IN p_apellido_paterno VARCHAR(100),

    IN p_apellido_materno VARCHAR(100),

    IN p_nombre_departamento VARCHAR(100),

    IN p_activo BOOLEAN,

    IN p_fecha_ingreso DATE

)
BEGIN

    SELECT

        e.id_empleado,

        e.numero_empleado,

        e.nombre,

        e.apellido_paterno,

        e.apellido_materno,

        CONCAT(
            e.nombre,
            ' ',
            e.apellido_paterno,
            IF(
                e.apellido_materno IS NULL
                OR e.apellido_materno = '',
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )
        ) AS nombre_completo,

        e.id_departamento,

        d.nombre_departamento,

        d.descripcion AS descripcion_departamento,

        e.foto_url,

        e.activo,

        e.fecha_ingreso,

        e.fecha_creacion

    FROM empleados e

    INNER JOIN departamentos d
        ON d.id_departamento = e.id_departamento

    WHERE

        (
            p_id_empleado IS NULL
            OR e.id_empleado = p_id_empleado
        )

        AND (
            p_numero_empleado IS NULL
            OR e.numero_empleado LIKE CONCAT(
                '%',
                TRIM(p_numero_empleado),
                '%'
            )
        )

        AND (
            p_nombre IS NULL
            OR e.nombre LIKE CONCAT(
                '%',
                TRIM(p_nombre),
                '%'
            )
        )

        AND (
            p_apellido_paterno IS NULL
            OR e.apellido_paterno LIKE CONCAT(
                '%',
                TRIM(p_apellido_paterno),
                '%'
            )
        )

        AND (
            p_apellido_materno IS NULL
            OR e.apellido_materno LIKE CONCAT(
                '%',
                TRIM(p_apellido_materno),
                '%'
            )
        )

        AND (
            p_nombre_departamento IS NULL
            OR d.nombre_departamento LIKE CONCAT(
                '%',
                TRIM(p_nombre_departamento),
                '%'
            )
        )

        AND (
            p_activo IS NULL
            OR e.activo = p_activo
        )

        AND (
            p_fecha_ingreso IS NULL
            OR e.fecha_ingreso = p_fecha_ingreso
        )

    ORDER BY
        e.apellido_paterno ASC,
        e.apellido_materno ASC,
        e.nombre ASC;

END//

DELIMITER ;


/* ============================================================
   ESTADO DE CHECADA DEL EMPLEADO
   ============================================================

   MUY IMPORTANTE PARA LA APP MOVIL.

   Permite saber si el empleado:

       - No ha checado hoy
       - Tiene entrada abierta
       - Ya registró entrada y salida

   La aplicación puede utilizar esto para decidir si
   mostrar el botón:

       "Registrar entrada"

   o:

       "Registrar salida"

   NO requiere administrador.
   ============================================================ */
DELIMITER //

DROP PROCEDURE IF EXISTS sp_estado_checada_empleado//

CREATE PROCEDURE sp_estado_checada_empleado(

    IN p_id_empleado INT UNSIGNED

)
BEGIN

    SELECT

        e.id_empleado,

        e.numero_empleado,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        CASE

            WHEN c.id_checada IS NULL
                THEN 'SIN_CHECADA'

            WHEN c.fecha_salida IS NULL
                THEN 'ENTRADA_ABIERTA'

            ELSE 'JORNADA_COMPLETA'

        END AS estado_checada,

        c.id_checada,

        c.fecha_entrada,

        c.fecha_salida,

        c.estado

    FROM empleados e

    LEFT JOIN checadas c

        ON c.id_checada = (

            SELECT c2.id_checada

            FROM checadas c2

            WHERE c2.id_empleado = e.id_empleado

              AND c2.fecha_entrada >= CURDATE()

              AND c2.fecha_entrada <
                  CURDATE() + INTERVAL 1 DAY

            ORDER BY c2.fecha_entrada DESC

            LIMIT 1

        )

    WHERE e.id_empleado = p_id_empleado

      AND e.activo = TRUE

    LIMIT 1;

END//


/* ============================================================
   ESTADO DE CHECADA POR NUMERO DE EMPLEADO
   ============================================================

   Versión cómoda para la aplicación móvil.

   La app puede trabajar únicamente con:

       numero_empleado

   sin tener que conocer previamente el id_empleado.
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_estado_checada_numero//

CREATE PROCEDURE sp_estado_checada_numero(

    IN p_numero_empleado VARCHAR(20)

)
BEGIN

    SELECT

        e.id_empleado,

        e.numero_empleado,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        CASE

            WHEN c.id_checada IS NULL
                THEN 'SIN_CHECADA'

            WHEN c.fecha_salida IS NULL
                THEN 'ENTRADA_ABIERTA'

            ELSE 'JORNADA_COMPLETA'

        END AS estado_checada,

        c.id_checada,

        c.fecha_entrada,

        c.fecha_salida,

        c.estado

    FROM empleados e

    LEFT JOIN checadas c

        ON c.id_checada = (

            SELECT c2.id_checada

            FROM checadas c2

            WHERE c2.id_empleado =
                  e.id_empleado

              AND c2.fecha_entrada >= CURDATE()

              AND c2.fecha_entrada <
                  CURDATE() + INTERVAL 1 DAY

            ORDER BY
                c2.fecha_entrada DESC

            LIMIT 1

        )

    WHERE e.numero_empleado =
          TRIM(p_numero_empleado)

      AND e.activo = TRUE

    LIMIT 1;

END//


/* ============================================================
   REGISTRAR ENTRADA
   ============================================================

   Flujo:

       App móvil
          ↓
       biometría
          ↓
       API
          ↓
       sp_registrar_entrada()
          ↓
       MySQL

   MySQL:

       1. Verifica empleado
       2. Verifica activo
       3. Obtiene horario
       4. Verifica entrada abierta
       5. Verifica entrada del día
       6. Determina A_TIEMPO / RETARDO
       7. Guarda checada
       8. Confirma transacción

   La biometría NO se almacena.
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_registrar_entrada//

CREATE PROCEDURE sp_registrar_entrada(

    IN p_id_empleado INT UNSIGNED,

    IN p_foto_entrada_url VARCHAR(500)

)
entrada_proc: BEGIN

    DECLARE v_now DATETIME;

    DECLARE v_fecha DATE;

    DECLARE v_dia_semana
        TINYINT UNSIGNED;

    DECLARE v_activo BOOLEAN DEFAULT FALSE;

    DECLARE v_hora_entrada TIME;

    DECLARE v_tolerancia
        TINYINT UNSIGNED;

    DECLARE v_estado VARCHAR(20);

    DECLARE v_id_horario
        INT UNSIGNED DEFAULT NULL;

    DECLARE v_id_checada_abierta
        BIGINT UNSIGNED DEFAULT NULL;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN

        ROLLBACK;

        RESIGNAL;

    END;


    SET v_now = NOW();

    SET v_fecha = DATE(v_now);

    SET v_dia_semana =
        WEEKDAY(v_fecha) + 1;


    START TRANSACTION;


    /* --------------------------------------------------------
       BLOQUEAR EMPLEADO

       Esto ayuda a evitar dos registros simultáneos para
       el mismo empleado.
       -------------------------------------------------------- */

    SELECT activo

    INTO v_activo

    FROM empleados

    WHERE id_empleado = p_id_empleado

    LIMIT 1

    FOR UPDATE;


    IF v_activo IS NULL
       OR v_activo = FALSE THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado no existe o esta inactivo.';

    END IF;


    /* --------------------------------------------------------
       OBTENER HORARIO DE HOY
       -------------------------------------------------------- */

    SELECT

        id_horario,

        hora_entrada,

        tolerancia_minutos

    INTO

        v_id_horario,

        v_hora_entrada,

        v_tolerancia

    FROM horarios

    WHERE id_empleado = p_id_empleado

      AND dia_semana = v_dia_semana

    LIMIT 1

    FOR UPDATE;


    IF v_id_horario IS NULL THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado no tiene horario configurado para hoy.';

    END IF;


    /* --------------------------------------------------------
       BUSCAR ENTRADA ABIERTA
       -------------------------------------------------------- */

    SELECT id_checada

    INTO v_id_checada_abierta

    FROM checadas

    WHERE id_empleado = p_id_empleado

      AND fecha_salida IS NULL

    ORDER BY fecha_entrada DESC

    LIMIT 1

    FOR UPDATE;


    IF v_id_checada_abierta IS NOT NULL THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado ya tiene una entrada abierta.';

    END IF;


    /* --------------------------------------------------------
       VERIFICAR ENTRADA DEL DIA
       -------------------------------------------------------- */

    IF EXISTS (

        SELECT 1

        FROM checadas

        WHERE id_empleado = p_id_empleado

          AND fecha_entrada >= v_fecha

          AND fecha_entrada <
              v_fecha + INTERVAL 1 DAY

    ) THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado ya registro una entrada el dia de hoy.';

    END IF;


    /* --------------------------------------------------------
       DETERMINAR ESTADO
       -------------------------------------------------------- */

    IF TIME(v_now) <= ADDTIME(

        v_hora_entrada,

        SEC_TO_TIME(
            v_tolerancia * 60
        )

    ) THEN

        SET v_estado = 'A_TIEMPO';

    ELSE

        SET v_estado = 'RETARDO';

    END IF;


    /* --------------------------------------------------------
       INSERTAR CHECADA
       -------------------------------------------------------- */

    INSERT INTO checadas (

        id_empleado,

        fecha_entrada,

        estado,

        foto_entrada_url

    )

    VALUES (

        p_id_empleado,

        v_now,

        v_estado,

        NULLIF(
            TRIM(p_foto_entrada_url),
            ''
        )

    );


    COMMIT;


    /* --------------------------------------------------------
       RESPUESTA
       -------------------------------------------------------- */

    SELECT

        TRUE AS exito,

        LAST_INSERT_ID() AS id_checada,

        v_estado AS estado,

        v_now AS fecha_entrada,

        'Entrada registrada correctamente.'
            AS mensaje;

END//


/* ============================================================
   REGISTRAR SALIDA
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_registrar_salida//

CREATE PROCEDURE sp_registrar_salida(

    IN p_id_empleado INT UNSIGNED,

    IN p_foto_salida_url VARCHAR(500)

)
salida_proc: BEGIN

    DECLARE v_id_checada
        BIGINT UNSIGNED DEFAULT NULL;

    DECLARE v_fecha_entrada DATETIME;

    DECLARE v_now DATETIME;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN

        ROLLBACK;

        RESIGNAL;

    END;


    SET v_now = NOW();


    START TRANSACTION;


    /* --------------------------------------------------------
       BUSCAR ENTRADA ABIERTA
       -------------------------------------------------------- */

    SELECT

        id_checada,

        fecha_entrada

    INTO

        v_id_checada,

        v_fecha_entrada

    FROM checadas

    WHERE id_empleado = p_id_empleado

      AND fecha_salida IS NULL

    ORDER BY fecha_entrada DESC

    LIMIT 1

    FOR UPDATE;


    IF v_id_checada IS NULL THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'El empleado no tiene una entrada abierta.';

    END IF;


    /* --------------------------------------------------------
       REGISTRAR SALIDA
       -------------------------------------------------------- */

    UPDATE checadas

    SET

        fecha_salida = v_now,

        foto_salida_url =
            NULLIF(
                TRIM(p_foto_salida_url),
                ''
            )

    WHERE id_checada = v_id_checada;


    COMMIT;


    SELECT

        TRUE AS exito,

        v_id_checada AS id_checada,

        v_fecha_entrada AS fecha_entrada,

        v_now AS fecha_salida,

        'Salida registrada correctamente.'
            AS mensaje;

END//



/* ============================================================
   HISTORIAL PROPIO POR NUMERO DE EMPLEADO
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_historial_empleado_numero//

CREATE PROCEDURE sp_historial_empleado_numero(

    IN p_numero_empleado VARCHAR(20)

)
BEGIN

    SELECT

        c.id_checada,

        e.id_empleado,

        e.numero_empleado,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        c.fecha_entrada,

        c.fecha_salida,

        c.estado,

        c.foto_entrada_url,

        c.foto_salida_url,

        c.observaciones

    FROM empleados e

    INNER JOIN checadas c

        ON c.id_empleado =
           e.id_empleado

    WHERE e.numero_empleado =
          TRIM(p_numero_empleado)

    ORDER BY
        c.fecha_entrada DESC;

END//


/* ============================================================
   17. PROCEDIMIENTOS PARA SMART TV
   ============================================================ */


/* ============================================================
   RETARDOS DEL DIA
   ============================================================

   NO requiere administrador.

   La TV puede llamar:

       CALL sp_retardos_hoy();

   El backend puede ejecutar esto cada 5 segundos.

   La TV recibe únicamente los empleados que llegaron tarde.
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_retardos_hoy//

CREATE PROCEDURE sp_retardos_hoy()

BEGIN

    SELECT

        c.id_checada,

        c.id_empleado,

        e.numero_empleado,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        d.nombre_departamento,

        c.fecha_entrada,

        c.estado,

        c.foto_entrada_url

    FROM checadas c

    INNER JOIN empleados e

        ON e.id_empleado =
           c.id_empleado

    INNER JOIN departamentos d

        ON d.id_departamento =
           e.id_departamento

    WHERE c.fecha_entrada >= CURDATE()

      AND c.fecha_entrada <
          CURDATE() + INTERVAL 1 DAY

      AND c.estado = 'RETARDO'

    ORDER BY
        c.fecha_entrada DESC;

END//



/* ============================================================
   18. PROCEDIMIENTOS PARA ADMINISTRADOR
   ============================================================ */


/* ============================================================
   CHECADAS DEL DIA
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_checadas_hoy//

CREATE PROCEDURE sp_checadas_hoy(

    IN p_id_admin INT UNSIGNED

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    SELECT

        c.id_checada,

        c.id_empleado,

        e.numero_empleado,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        d.nombre_departamento,

        c.fecha_entrada,

        c.fecha_salida,

        c.estado,

        c.foto_entrada_url,

        c.foto_salida_url,

        c.observaciones

    FROM checadas c

    INNER JOIN empleados e

        ON e.id_empleado =
           c.id_empleado

    INNER JOIN departamentos d

        ON d.id_departamento =
           e.id_departamento

    WHERE c.fecha_entrada >= CURDATE()

      AND c.fecha_entrada <
          CURDATE() + INTERVAL 1 DAY

    ORDER BY
        c.fecha_entrada DESC;

END//


/* ============================================================
   HISTORIAL DE UN EMPLEADO PARA ADMIN
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_historial_empleado//

CREATE PROCEDURE sp_historial_empleado(

    IN p_id_admin INT UNSIGNED,

    IN p_numero_empleado VARCHAR(20)

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    -- Verificar que el usuario sea un administrador activo
    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    -- Si no es administrador, detener el procedimiento
    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    -- Obtener historial usando el número de empleado
    SELECT

        c.id_checada,

        c.id_empleado,

        e.numero_empleado,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        c.fecha_entrada,

        c.fecha_salida,

        c.estado,

        c.foto_entrada_url,

        c.foto_salida_url,

        c.observaciones,

        c.fecha_creacion

    FROM checadas c

    INNER JOIN empleados e

        ON e.id_empleado =
           c.id_empleado

    WHERE e.numero_empleado =
          p_numero_empleado

    ORDER BY
        c.fecha_entrada DESC;

END//
/* ============================================================
   REPORTE POR FECHA
   ============================================================ */

DROP PROCEDURE IF EXISTS sp_reporte_fecha//

CREATE PROCEDURE sp_reporte_fecha(

    IN p_id_admin INT UNSIGNED,

    IN p_fecha DATE

)
admin_proc: BEGIN

    DECLARE v_es_admin BOOLEAN DEFAULT FALSE;


    CALL sp_verificar_admin(
        p_id_admin,
        v_es_admin
    );


    IF v_es_admin = FALSE THEN

        SELECT
            FALSE AS exito,
            'No autorizado. Se requiere un administrador activo.'
                AS mensaje;

        LEAVE admin_proc;

    END IF;


    IF p_fecha IS NULL THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT =
            'La fecha es obligatoria.';

    END IF;


    SELECT

        c.id_checada,

        c.id_empleado,

        e.numero_empleado,

        CONCAT(

            e.nombre,
            ' ',
            e.apellido_paterno,

            IF(
                e.apellido_materno IS NULL,
                '',
                CONCAT(
                    ' ',
                    e.apellido_materno
                )
            )

        ) AS nombre_completo,

        d.nombre_departamento,

        c.fecha_entrada,

        c.fecha_salida,

        c.estado,

        c.foto_entrada_url,

        c.foto_salida_url,

        c.observaciones

    FROM checadas c

    INNER JOIN empleados e

        ON e.id_empleado =
           c.id_empleado

    INNER JOIN departamentos d

        ON d.id_departamento =
           e.id_departamento

    WHERE c.fecha_entrada >= p_fecha

      AND c.fecha_entrada <
          p_fecha + INTERVAL 1 DAY

    ORDER BY
        c.fecha_entrada ASC;

END//


/* ============================================================
   19. FINALIZAR DELIMITER
   ============================================================ */

DELIMITER ;


/* ============================================================
   20. VERIFICACION DE TABLAS
   ============================================================ */

SHOW TABLES;


/* ============================================================
   21. VERIFICAR ESTRUCTURA DE CHECADAS
   ============================================================

   Aquí NO debe aparecer:

       checada_abierta

   ============================================================ */

DESCRIBE checadas;


/* ============================================================
   22. VERIFICAR PROCEDIMIENTOS
   ============================================================ */

SHOW PROCEDURE STATUS

WHERE Db = 'checador_db';


/* ============================================================
   23. CREAR PRIMER ADMINISTRADOR
   ============================================================

   IMPORTANTE:

   Este INSERT es solamente un ejemplo.

   El valor de password_hash debe ser generado por Node.js
   utilizando bcrypt o Argon2.

   Ejemplo conceptual:

       usuario:
           admin

       contraseña:
           Admin123

   NO guardar:

       Admin123

   directamente en password_hash.

   Debe guardarse el HASH.

   Ejemplo:

       INSERT INTO admin (
           usuario,
           password_hash,
           nombre
       )
       VALUES (
           'admin',
           'HASH_GENERADO_POR_NODE',
           'Administrador'
       );

   ============================================================ */


/* ============================================================
   FIN DEL SCRIPT
   ============================================================ */
