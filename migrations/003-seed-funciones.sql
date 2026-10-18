-- Seed de Funciones en producción (EC2-BDD / pasalapeli_db)
-- Lunes a sábado, horario típico de cine, desde 2026-10-25 hasta 2026-11-30
-- Películas reales en prod: 7..10, 13..16 (tabla Funcion con F mayúscula)
-- Idempotente por (fecha, hora, sala, pelicula_id)

SET @desde = '2026-10-25';
SET @hasta = '2026-11-30';

INSERT INTO `Funcion` (`fecha`, `hora`, `sala`, `entradas_disponibles`, `aforo`, `precio`, `pelicula_id`)
WITH RECURSIVE dias AS (
  SELECT CAST(@desde AS DATE) AS d
  UNION ALL
  SELECT d + INTERVAL 1 DAY FROM dias WHERE d < @hasta
),
slots AS (
  -- Sala 1 - IMAX (estrenos / blockbuster)
  SELECT '15:00:00' AS hora, 'Sala 1 - IMAX' AS sala, 50 AS aforo, 5500.00 AS precio, 9 AS pelicula_id
  UNION ALL SELECT '18:00:00', 'Sala 1 - IMAX', 50, 5500.00, 16
  UNION ALL SELECT '21:00:00', 'Sala 1 - IMAX', 50, 5500.00, 8
  -- Sala 2 - 3D
  UNION ALL SELECT '14:30:00', 'Sala 2 - 3D', 40, 4800.00, 10
  UNION ALL SELECT '17:15:00', 'Sala 2 - 3D', 40, 4800.00, 13
  UNION ALL SELECT '20:00:00', 'Sala 2 - 3D', 40, 4800.00, 7
  -- Sala 3 - 2D (comedias / family)
  UNION ALL SELECT '15:30:00', 'Sala 3 - 2D', 60, 4200.00, 14
  UNION ALL SELECT '17:00:00', 'Sala 3 - 2D', 60, 4200.00, 15
  UNION ALL SELECT '18:30:00', 'Sala 3 - 2D', 60, 4200.00, 14
  UNION ALL SELECT '20:45:00', 'Sala 3 - 2D', 60, 4200.00, 13
)
SELECT
  d.d AS fecha,
  s.hora,
  s.sala,
  s.aforo AS entradas_disponibles,
  s.aforo,
  s.precio,
  s.pelicula_id
FROM dias d
CROSS JOIN slots s
WHERE DAYOFWEEK(d.d) BETWEEN 2 AND 7  -- 2=Lun ... 7=Sáb (1=Dom)
  AND NOT EXISTS (
    SELECT 1 FROM `Funcion` f
    WHERE f.fecha = d.d AND f.hora = s.hora AND f.sala = s.sala AND f.pelicula_id = s.pelicula_id
  )
ORDER BY d.d, s.hora, s.sala;

SELECT COUNT(*) AS funciones_total FROM `Funcion`;
SELECT fecha, COUNT(*) AS n FROM `Funcion` GROUP BY fecha ORDER BY fecha LIMIT 10;
SELECT MIN(fecha) AS desde, MAX(fecha) AS hasta, COUNT(DISTINCT fecha) AS dias FROM `Funcion`;
