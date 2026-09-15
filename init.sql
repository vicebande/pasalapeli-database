-- =======================================================
-- Script de Creacion de Base de Datos - Pasa La Peli
-- Asignatura: Desarrollo Cloud Native I (DSY1107) - Duoc UC
-- Basado en: Diagrama BDD.png y Guia de Especificacion
-- =======================================================

CREATE DATABASE IF NOT EXISTS `pasalapeli_db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `pasalapeli_db`;

-- -------------------------------------------------------
-- 1. Tabla Usuario
-- Almacena las identidades base y roles del sistema.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Usuario` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `nombre` VARCHAR(100) NOT NULL,
  `correo` VARCHAR(100) NOT NULL UNIQUE,
  `password` VARCHAR(255) NOT NULL,
  `rol` ENUM('ADMIN', 'CLIENTE') NOT NULL DEFAULT 'CLIENTE',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- 2. Tabla Pelicula
-- Contiene el catalogo de peliculas e imagen (S3 URL).
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Pelicula` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `titulo` VARCHAR(100) NOT NULL,
  `descripcion` TEXT NULL,
  `genero` VARCHAR(50) NOT NULL,
  `duracion` INT NOT NULL,
  `clasificacion` VARCHAR(10) NOT NULL,
  `imagen` VARCHAR(255) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- 3. Tabla Funcion
-- Proyecciones en sala asociadas a una pelicula.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Funcion` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `fecha` DATE NOT NULL,
  `hora` TIME NOT NULL,
  `sala` VARCHAR(50) NOT NULL,
  `entradas_disponibles` INT NOT NULL DEFAULT 0,
  `precio` DECIMAL(10,2) NOT NULL,
  `pelicula_id` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_funcion_pelicula` (`pelicula_id`),
  CONSTRAINT `fk_funcion_pelicula`
    FOREIGN KEY (`pelicula_id`) REFERENCES `Pelicula` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- 4. Tabla Ticket
-- Registra reservas de asientos de un usuario para una funcion.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Ticket` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `fecha_compra` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `codigo` VARCHAR(100) NOT NULL UNIQUE,
  `estado` ENUM('PENDIENTE', 'PAGADO', 'CANCELADO') NOT NULL DEFAULT 'PENDIENTE',
  `usuario_id` BIGINT NOT NULL,
  `funcion_id` BIGINT NOT NULL,
  `cantidad` INT NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  INDEX `idx_ticket_usuario` (`usuario_id`),
  INDEX `idx_ticket_funcion` (`funcion_id`),
  CONSTRAINT `fk_ticket_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `Usuario` (`id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT `fk_ticket_funcion`
    FOREIGN KEY (`funcion_id`) REFERENCES `Funcion` (`id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------
-- 5. Tabla Pago
-- Consolida la transaccion economica del ticket.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Pago` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `monto` DECIMAL(10,2) NOT NULL,
  `metodo` VARCHAR(30) NOT NULL,
  `estado` ENUM('PENDIENTE', 'APROBADO', 'RECHAZADO') NOT NULL DEFAULT 'PENDIENTE',
  `fecha_pago` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ticket_id` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_pago_ticket` (`ticket_id`),
  CONSTRAINT `fk_pago_ticket`
    FOREIGN KEY (`ticket_id`) REFERENCES `Ticket` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =======================================================
-- DATOS INICIALES DE PRUEBA (SEED DATA)
-- =======================================================

INSERT INTO `Usuario` (`id`, `nombre`, `correo`, `password`, `rol`) VALUES
(1, 'Administrador Cine', 'admin@pasalapeli.cl', '', 'ADMIN'),
(2, 'Vicente Banderas', 'vicente.banderas@duocuc.cl', '', 'CLIENTE'),
(3, 'Martin Vergara', 'martin.vergara@duocuc.cl', '', 'CLIENTE');

INSERT INTO `Pelicula` (`id`, `titulo`, `descripcion`, `genero`, `duracion`, `clasificacion`, `imagen`) VALUES
(1, 'The Batman', 'En su segundo año luchando contra el crimen, Batman explora la corrupcion existente en Gotham City y el vinculo de esta con su propia familia.', 'Accion / Suspenso', 176, 'TE+14', 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80'),
(2, 'Spider-Man: Across the Spider-Verse', 'Miles Morales se catapulta a traves del Multiverso, donde se encuentra con un equipo de Spider-People encargados de proteger su existencia.', 'Animacion / Aventura', 140, 'TE', 'https://images.unsplash.com/photo-1635805737707-575885ab0820?w=600&auto=format&fit=crop&q=80'),
(3, 'Avatar: The Way of Water', 'Ambientada mas de una decada despues de los acontecimientos de la primera pelicula, Avatar: The Way of Water empieza contando la historia de la familia Sully.', 'Ciencia Ficcion', 192, 'TE+7', 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80'),
(4, 'Oppenheimer', 'La historia del cientifico estadounidense J. Robert Oppenheimer y su rol en el desarrollo de la bomba atomica durante la Segunda Guerra Mundial.', 'Drama / Historica', 180, 'TE+14', 'https://images.unsplash.com/photo-1440404653325-ab127d49abc1?w=600&auto=format&fit=crop&q=80'),
(5, 'Dune: Parte Dos', 'Paul Atreides se une a Chani y a los Fremen mientras busca venganza contra los conspiradores que destruyeron a su familia.', 'Ciencia Ficcion / Aventura', 166, 'TE+14', 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80');

INSERT INTO `Funcion` (`id`, `fecha`, `hora`, `sala`, `entradas_disponibles`, `precio`, `pelicula_id`) VALUES
(1, CURRENT_DATE(), '16:00:00', 'Sala 1 - IMAX', 45, 5500.00, 1),
(2, CURRENT_DATE(), '19:30:00', 'Sala 1 - IMAX', 50, 5500.00, 1),
(3, CURRENT_DATE(), '17:15:00', 'Sala 2 - 3D', 30, 4800.00, 2),
(4, CURRENT_DATE(), '20:45:00', 'Sala 2 - 3D', 40, 4800.00, 2),
(5, CURRENT_DATE(), '18:00:00', 'Sala 3 - 2D', 60, 4200.00, 3),
(6, CURRENT_DATE(), '21:30:00', 'Sala 3 - 2D', 1, 4200.00, 3),
(7, DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY), '15:00:00', 'Sala 4 - 2D', 50, 4200.00, 4),
(8, DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY), '18:30:00', 'Sala 4 - 2D', 50, 4200.00, 4),
(9, DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY), '20:00:00', 'Sala 1 - IMAX', 55, 5500.00, 5);

INSERT INTO `Ticket` (`id`, `fecha_compra`, `codigo`, `estado`, `usuario_id`, `funcion_id`, `cantidad`) VALUES
(1, DATE_SUB(NOW(), INTERVAL 2 HOUR), 'PLP-2026-0001', 'PAGADO', 2, 1, 1),
(2, DATE_SUB(NOW(), INTERVAL 1 HOUR), 'PLP-2026-0002', 'PAGADO', 3, 3, 2);

INSERT INTO `Pago` (`id`, `monto`, `metodo`, `estado`, `fecha_pago`, `ticket_id`) VALUES
(1, 5500.00, 'WEBPAY', 'APROBADO', DATE_SUB(NOW(), INTERVAL 2 HOUR), 1),
(2, 9600.00, 'TARJETA_CREDITO', 'APROBADO', DATE_SUB(NOW(), INTERVAL 1 HOUR), 2);