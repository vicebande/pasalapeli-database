-- Seed de Funciones en producción (EC2-BDD / pasalapeli_db)
-- 4 funciones por película (8 películas = 32), lunes a sábado
-- Desde 2026-10-26 (el 25 es domingo) en adelante
-- Películas reales en prod: 7..10, 13..16 · tabla `Funcion`
-- Idempotente: borra solo el rango de fechas del seed si se re-ejecuta

DELETE FROM `Funcion`
WHERE fecha BETWEEN '2026-10-26' AND '2026-11-07'
  AND id NOT IN (SELECT DISTINCT funcion_id FROM Ticket WHERE funcion_id IS NOT NULL);

INSERT INTO `Funcion` (`fecha`, `hora`, `sala`, `entradas_disponibles`, `aforo`, `precio`, `pelicula_id`) VALUES
-- 9 Spider-Man (IMAX) x4
('2026-10-26', '15:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 9),
('2026-10-28', '18:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 9),
('2026-11-02', '15:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 9),
('2026-11-04', '18:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 9),
-- 16 Rapidos y Furiosos (IMAX) x4
('2026-10-26', '18:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 16),
('2026-10-29', '18:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 16),
('2026-11-03', '18:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 16),
('2026-11-05', '18:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 16),
-- 8 La Odisea (IMAX noche) x4
('2026-10-27', '21:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 8),
('2026-10-30', '21:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 8),
('2026-11-04', '21:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 8),
('2026-11-07', '21:00:00', 'Sala 1 - IMAX', 50, 50, 5500.00, 8),
-- 10 Coyote vs Acme (3D) x4
('2026-10-26', '14:30:00', 'Sala 2 - 3D', 40, 40, 4800.00, 10),
('2026-10-28', '14:30:00', 'Sala 2 - 3D', 40, 40, 4800.00, 10),
('2026-11-02', '14:30:00', 'Sala 2 - 3D', 40, 40, 4800.00, 10),
('2026-11-04', '14:30:00', 'Sala 2 - 3D', 40, 40, 4800.00, 10),
-- 13 Obsession (3D) x4
('2026-10-27', '17:15:00', 'Sala 2 - 3D', 40, 40, 4800.00, 13),
('2026-10-30', '17:15:00', 'Sala 2 - 3D', 40, 40, 4800.00, 13),
('2026-11-03', '17:15:00', 'Sala 2 - 3D', 40, 40, 4800.00, 13),
('2026-11-06', '17:15:00', 'Sala 2 - 3D', 40, 40, 4800.00, 13),
-- 7 Tung Tung Sahur (3D) x4
('2026-10-27', '20:00:00', 'Sala 2 - 3D', 40, 40, 4800.00, 7),
('2026-10-29', '20:00:00', 'Sala 2 - 3D', 40, 40, 4800.00, 7),
('2026-11-03', '20:00:00', 'Sala 2 - 3D', 40, 40, 4800.00, 7),
('2026-11-05', '20:00:00', 'Sala 2 - 3D', 40, 40, 4800.00, 7),
-- 14 Niu Lai (2D) x4
('2026-10-26', '15:30:00', 'Sala 3 - 2D', 60, 60, 4200.00, 14),
('2026-10-28', '15:30:00', 'Sala 3 - 2D', 60, 60, 4200.00, 14),
('2026-11-02', '15:30:00', 'Sala 3 - 2D', 60, 60, 4200.00, 14),
('2026-11-04', '15:30:00', 'Sala 3 - 2D', 60, 60, 4200.00, 14),
-- 15 Roberto Manfinfla (2D) x4
('2026-10-26', '17:00:00', 'Sala 3 - 2D', 60, 60, 4200.00, 15),
('2026-10-29', '17:00:00', 'Sala 3 - 2D', 60, 60, 4200.00, 15),
('2026-11-02', '17:00:00', 'Sala 3 - 2D', 60, 60, 4200.00, 15),
('2026-11-05', '17:00:00', 'Sala 3 - 2D', 60, 60, 4200.00, 15);

SELECT p.id, p.titulo, COUNT(*) AS funciones
FROM Funcion f JOIN Pelicula p ON p.id = f.pelicula_id
GROUP BY p.id, p.titulo ORDER BY p.id;
SELECT COUNT(*) AS total FROM Funcion;
