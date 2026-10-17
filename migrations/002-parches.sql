-- ============================================================
-- Migracion 002 - Parches de auditoria (Pasa La Peli)
-- Idempotente: puede ejecutarse multiples veces en EC2-BDD.
-- Uso (desde el host de la BDD o via ssh):
--   mysql -u <user> -p pasalapeli_db < migrations/002-parches.sql
-- Nota: MySQL 8 no admite "ADD COLUMN IF NOT EXISTS"; se usa
-- information_schema + prepared statements.
-- ============================================================

USE `pasalapeli_db`;

-- ------------------------------------------------------------
-- 1) Funcion.aforo: tope maximo vendible por funcion (0 = sin tope)
-- ------------------------------------------------------------
SET @col := (SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Funcion' AND COLUMN_NAME = 'aforo');

SET @sql := IF(@col = 0,
  'ALTER TABLE `Funcion` ADD COLUMN `aforo` INT NOT NULL DEFAULT 0 COMMENT ''Tope maximo de entradas vendibles (0 = sin tope)'' AFTER `entradas_disponibles`',
  'SELECT ''[OK] Funcion.aforo ya existe'' AS mensaje');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Sembrado conservador: las funciones existentes heredan su stock actual como aforo
UPDATE `Funcion` SET `aforo` = `entradas_disponibles`
 WHERE `aforo` = 0 AND `entradas_disponibles` > 0;

-- ------------------------------------------------------------
-- 2) UNIQUE (sala, fecha, hora): impide solapes de programacion
--    (si hay duplicados previos, el ALTER fallara con un error
--     claro; resolverlos manualmente antes de re-ejecutar)
-- ------------------------------------------------------------
SELECT 'Aviso: funciones con solape previo (resolver antes del UNIQUE si las hay)' AS aviso,
       `sala`, `fecha`, `hora`, COUNT(*) AS cantidad
  FROM `Funcion`
 GROUP BY `sala`, `fecha`, `hora`
HAVING COUNT(*) > 1;

SET @idx := (SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Funcion' AND INDEX_NAME = 'uq_funcion_sala_fecha_hora');

SET @sql := IF(@idx = 0,
  'ALTER TABLE `Funcion` ADD UNIQUE KEY `uq_funcion_sala_fecha_hora` (`sala`, `fecha`, `hora`)',
  'SELECT ''[OK] uq_funcion_sala_fecha_hora ya existe'' AS mensaje');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ------------------------------------------------------------
-- 3) Ticket.idempotency_key + UNIQUE (usuario_id, funcion_id, idempotency_key)
-- ------------------------------------------------------------
SET @col := (SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Ticket' AND COLUMN_NAME = 'idempotency_key');

SET @sql := IF(@col = 0,
  'ALTER TABLE `Ticket` ADD COLUMN `idempotency_key` VARCHAR(64) NULL COMMENT ''Clave opcional de reintentos seguros'' AFTER `cantidad`',
  'SELECT ''[OK] Ticket.idempotency_key ya existe'' AS mensaje');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx := (SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Ticket' AND INDEX_NAME = 'uq_ticket_usuario_funcion_idem');

SET @sql := IF(@idx = 0,
  'ALTER TABLE `Ticket` ADD UNIQUE KEY `uq_ticket_usuario_funcion_idem` (`usuario_id`, `funcion_id`, `idempotency_key`)',
  'SELECT ''[OK] uq_ticket_usuario_funcion_idem ya existe'' AS mensaje');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ------------------------------------------------------------
-- 4) UNIQUE (usuario_id, tipo, referencia) en Notificacion:
--    deduplica reentregas de SQS (al-menos-una-vez).
--    Se conserva la fila mas reciente (mayor id) de cada grupo.
--    Las filas con referencia NULL no se consideran duplicadas
--    (NULL = NULL es desconocido en SQL).
-- ------------------------------------------------------------
DELETE n1 FROM `Notificacion` n1
  INNER JOIN `Notificacion` n2
     ON n1.`usuario_id` = n2.`usuario_id`
    AND n1.`tipo` = n2.`tipo`
    AND n1.`referencia` = n2.`referencia`
    AND n1.`id` < n2.`id`;

SET @idx := (SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Notificacion' AND INDEX_NAME = 'uq_notificacion_usuario_tipo_ref');

SET @sql := IF(@idx = 0,
  'ALTER TABLE `Notificacion` ADD UNIQUE KEY `uq_notificacion_usuario_tipo_ref` (`usuario_id`, `tipo`, `referencia`)',
  'SELECT ''[OK] uq_notificacion_usuario_tipo_ref ya existe'' AS mensaje');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT 'Migracion 002 completada (idempotente)' AS resultado;
