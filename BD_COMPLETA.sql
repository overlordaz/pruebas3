-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Versión del servidor:         8.0.30 - MySQL Community Server - GPL
-- SO del servidor:              Win64
-- HeidiSQL Versión:             12.1.0.6537
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Volcando estructura de base de datos para laravel
CREATE DATABASE IF NOT EXISTS `laravel` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `laravel`;

-- Volcando estructura para procedimiento laravel.Actualizar_lote
DELIMITER //
CREATE PROCEDURE `Actualizar_lote`(
	IN `ve_idlote` BIGINT(20),
	IN `ve_num_lote` varchar(45),
	IN `ve_idmedicamento` BIGINT(20),
	IN `ve_stock` DECIMAL(15,2),
	IN `ve_fecha_venc` DATE,
	IN `ve_iduser` INT(11),
	IN `ve_accion` CHAR(1),
	OUT `vo_coderror` INT(10),
	OUT `vo_msgerror` VARCHAR(100)
)
BEGIN
    -- Declaración e inicialización de variables locales
    DECLARE v_stock_actual DECIMAL(15,2);
    DECLARE vi_idlote BIGINT(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Manejo de la Excepción
        ROLLBACK;
        SET vo_coderror = -1;
         SHOW ERRORS LIMIT 1;
         SET vo_msgerror = CONCAT('Error: ', MYSQL_ERRNO, ' - ', SQLERRM());
    END;
    
    SET vo_coderror = 0;
    SET vo_msgerror = '';
    
    START TRANSACTION;
    
    -- Actualizar el stock
    IF ve_accion = 'U' AND ve_idlote > 0 THEN
        -- Obtener el stock actual
        SELECT stock INTO v_stock_actual
        FROM MEDICAMENTO_LOTE
        WHERE medicamento_id = ve_idmedicamento
        AND lote_id = ve_idlote;
        
        IF v_stock_actual IS NOT NULL THEN
            -- Actualizar tabla LOTE fecha de vencimiento.
            UPDATE LOTE
            SET stock = ve_stock,
                fecha_vencimiento = ve_fecha_venc,
                fecha_upd = NOW(),
                iduser_upd = ve_iduser
            WHERE id = ve_idlote;
           
            -- Actualizar STOCK en tabla MEDICAMENTO_LOTE
            UPDATE MEDICAMENTO_LOTE
            SET stock = ve_stock
            WHERE medicamento_id = ve_idmedicamento
            AND lote_id = ve_idlote;
            
        ELSE
            SET vo_coderror = -1;
            SET vo_msgerror = 'El lote no existe.';
        END IF;
    END IF;
    
    IF ve_accion = 'I' OR (ve_idlote = 0 AND ve_stock > 0) THEN
        -- Insertar nuevo registro en LOTE
        INSERT INTO LOTE (numero_lote, stock, fecha_vencimiento, fecha_reg, iduser_reg)
        VALUES (ve_num_lote, ve_stock, ve_fecha_venc, NOW(), ve_iduser);
        SELECT LAST_INSERT_ID() INTO vi_idlote;
         
        -- Insertar nuevo registro en MEDICAMENTO_LOTE
        INSERT INTO MEDICAMENTO_LOTE (medicamento_id, lote_id, stock)
        VALUES (ve_idmedicamento, vi_idlote, ve_stock);        
        
    END IF;       
    COMMIT;    
END//
DELIMITER ;

-- Volcando estructura para procedimiento laravel.actualizar_stock_medicamentos
DELIMITER //
CREATE PROCEDURE `actualizar_stock_medicamentos`(  IN ve_idcompra BIGINT(20),
																		   	  IN ve_idlote BIGINT(20),
																			  IN ve_idmedicamento BIGINT(20),
																			  IN ve_stock DECIMAL(15,2),
																			  IN ve_fecha_upd DATE,
																			  IN ve_iduser INT(11),
																			  IN ve_accion CHAR(1),
																			  OUT vo_coderror INT(10),
																			  OUT vo_msgerror VARCHAR(100)
																		 )
BEGIN
	  -- Creandos las variables locales
      declare vi_stock_actual int(10);
      declare vi_stock_compra int(10);
      declare vi_diff_stock int(10);
      declare vi_existe int (10);
      
      -- INICIALIZANDO VARIABLES
      SET vi_stock_actual = 0;
      SET vi_stock_compra = 0;
      SET vi_existe = 0;
		     -- VALIDAR SI EXISTEN REGISTROS
			 SELECT count(*)
			   INTO vi_existe
			   FROM MEDICAMENTO_LOTE M
			   WHERE M.medicamento_id = ve_idmedicamento
				 AND M.lote_id = ve_idlote;
             -- OBTENER STOCK ACTUAL    
             IF vi_existe > 0 THEN 
				SELECT stock
	        	  INTO vi_stock_actual
				  FROM MEDICAMENTO_LOTE M
				 WHERE M.medicamento_id = ve_idmedicamento
				   AND M.lote_id = ve_idlote;
             END IF;
	  IF ve_accion = 'U' THEN
         IF vi_existe > 0 THEN         
            -- OBTENER STOCK DE LA COMPRA ANTES DEL CAMBIO        
		 	SELECT cantidad
              INTO vi_stock_compra
			  FROM COMPRA_DETALLE CD
             WHERE CD.compras_id = ve_idcompra
               AND CD.lote_id = ve_idlote;
            -- ACTUALIZAR LOS REGISTROS DEL STOCK SEGUN CORRECCION DE COMPRA
            -- EN CASO QUE LA CANTIDAD HAYA CAMBIADO SE SUMA O SE RESTA SI LA CANTIDA SIGUE SIENDO LA MISMA NO HAY CAMBIOS
		 	IF vi_stock_compra <> ve_stock THEN
               SET vi_diff_stock = (ve_stock - vi_stock_compra);
               UPDATE MEDICAMENTO_LOTE m
                  SET stock = (vi_stock_actual + vi_diff_stock)
			    WHERE M.medicamento_id = ve_idmedicamento
				  AND M.lote_id = ve_idlote;
               UPDATE LOTE
			      SET stock = (vi_stock_actual + vi_diff_stock)
                WHERE id = ve_idlote;     
		    END IF; 
         else
			INSERT INTO MEDICAMENTO_LOTE(medicamento_id,lote_id,stock) VALUES(ve_idmedicamento,ve_idlote,ve_stock);
         END IF;
      END IF;   
      IF ve_accion = 'I' THEN
          -- OBTENER EL STOCK ACTUAL 
          IF vi_existe > 0 THEN			 
             -- SI YA EXISTE ADICIONAMOS AL STOCK EXITENTE EL STOCK DE LA COMPRA
               UPDATE MEDICAMENTO_LOTE m
                  SET stock = (vi_stock_actual + ve_stock)
			    WHERE M.medicamento_id = ve_idmedicamento
				  AND M.lote_id = ve_idlote;
         ELSE 
			 INSERT INTO MEDICAMENTO_LOTE(medicamento_id,lote_id,stock) VALUES(ve_idmedicamento,ve_idlote,ve_stock);
         END IF;        
      END IF;
END//
DELIMITER ;

-- Volcando estructura para tabla laravel.cliente
CREATE TABLE IF NOT EXISTS `cliente` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `nombresyapellidos` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `DNI` varchar(12) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `celular` varchar(12) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `correo` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `direccion` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.cliente: ~1 rows (aproximadamente)
REPLACE INTO `cliente` (`id`, `nombresyapellidos`, `DNI`, `celular`, `correo`, `direccion`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`) VALUES
	(1, 'Anonimo', '00000000', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(3, 'Henry Angel Suarez Lazarte', '46140580', '939537564', 'henry.ti.3000@gmail.com', NULL, '2023-06-04 20:40:13', NULL, NULL, NULL);

-- Volcando estructura para tabla laravel.compras
CREATE TABLE IF NOT EXISTS `compras` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `nro_factura` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `proveedor_id` bigint unsigned NOT NULL,
  `fecha_compra` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `total_compra` decimal(10,2) DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `compras_proveedor_id_foreign` (`proveedor_id`),
  CONSTRAINT `compras_proveedor_id_foreign` FOREIGN KEY (`proveedor_id`) REFERENCES `proveedor` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.compras: ~2 rows (aproximadamente)
REPLACE INTO `compras` (`id`, `nro_factura`, `proveedor_id`, `fecha_compra`, `total_compra`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`) VALUES
	(50, 'prueba2', 2, '2023-05-25', 39.00, '2023-05-25 10:36:17', '2023-05-25 10:37:42', NULL, 2),
	(51, 'CXXX', 2, '2023-05-28', 1.00, '2023-05-29 04:54:59', NULL, NULL, NULL),
	(63, 'FAC-ANONIMA-2023-06-06', 2, '2023-06-06', 153.50, '2023-06-06 23:42:52', NULL, 1, NULL);

-- Volcando estructura para tabla laravel.compra_detalle
CREATE TABLE IF NOT EXISTS `compra_detalle` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `medicamento_id` bigint unsigned NOT NULL,
  `compras_id` bigint unsigned NOT NULL,
  `lote_id` bigint unsigned NOT NULL,
  `cantidad` int DEFAULT NULL,
  `precio_compra` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `compra_detalle_medicamento_id_foreign` (`medicamento_id`),
  KEY `compra_detalle_compras_id_foreign` (`compras_id`),
  KEY `compra_detalle_lote_id_foreign` (`lote_id`),
  CONSTRAINT `compra_detalle_compras_id_foreign` FOREIGN KEY (`compras_id`) REFERENCES `compras` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `compra_detalle_lote_id_foreign` FOREIGN KEY (`lote_id`) REFERENCES `lote` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `compra_detalle_medicamento_id_foreign` FOREIGN KEY (`medicamento_id`) REFERENCES `medicamento` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=61 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.compra_detalle: ~0 rows (aproximadamente)
REPLACE INTO `compra_detalle` (`id`, `medicamento_id`, `compras_id`, `lote_id`, `cantidad`, `precio_compra`) VALUES
	(53, 310, 63, 197, 57, 0.50),
	(54, 311, 63, 198, 33, 0.50),
	(55, 312, 63, 199, 19, 0.50),
	(56, 313, 63, 200, 56, 0.50),
	(57, 314, 63, 201, 36, 0.50),
	(58, 315, 63, 202, 6, 3.00),
	(59, 316, 63, 203, 8, 2.50),
	(60, 317, 63, 204, 10, 1.50);

-- Volcando estructura para tabla laravel.dosificacion
CREATE TABLE IF NOT EXISTS `dosificacion` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `descripcion` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.dosificacion: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.failed_jobs
CREATE TABLE IF NOT EXISTS `failed_jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `connection` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `queue` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `exception` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.failed_jobs: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.forma_farmaceutica
CREATE TABLE IF NOT EXISTS `forma_farmaceutica` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `descripcion` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `simplificada` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.forma_farmaceutica: ~5 rows (aproximadamente)
REPLACE INTO `forma_farmaceutica` (`id`, `descripcion`, `simplificada`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`) VALUES
	(1, 'forma Farmaceutica', NULL, '2023-05-21 12:51:35', '2023-05-21 12:51:43', NULL, NULL),
	(3, 'asdfgh', NULL, '2023-05-28 18:13:41', NULL, 1, NULL),
	(4, 'wsxedc', NULL, '2023-05-28 18:13:41', NULL, 1, NULL),
	(5, 'qwert', NULL, '2023-05-28 18:13:41', NULL, 1, NULL),
	(6, 'zxcvbn', NULL, '2023-05-28 18:13:41', NULL, 1, NULL);

-- Volcando estructura para tabla laravel.inventario
CREATE TABLE IF NOT EXISTS `inventario` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `medicamento_id` bigint unsigned NOT NULL,
  `stock` decimal(10,2) DEFAULT NULL,
  `stock_fraccion` decimal(10,2) DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `inventario_medicamento_id_foreign` (`medicamento_id`),
  CONSTRAINT `inventario_medicamento_id_foreign` FOREIGN KEY (`medicamento_id`) REFERENCES `medicamento` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.inventario: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.laboratorio
CREATE TABLE IF NOT EXISTS `laboratorio` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.laboratorio: ~5 rows (aproximadamente)
REPLACE INTO `laboratorio` (`id`, `nombre`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`) VALUES
	(1, 'Medifarma', NULL, NULL, NULL, NULL),
	(6, 'Inkafarma', '2023-05-28 18:21:43', NULL, 1, NULL),
	(7, 'Gensa', '2023-05-28 18:21:43', NULL, 1, NULL),
	(8, 'Quimica Suisa', '2023-05-28 18:21:43', NULL, 1, NULL),
	(9, 'Generico', '2023-05-28 18:21:43', NULL, 1, NULL);

-- Volcando estructura para tabla laravel.libro
CREATE TABLE IF NOT EXISTS `libro` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tipo` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cantidad` decimal(10,2) DEFAULT NULL,
  `medicamento_id` bigint unsigned NOT NULL,
  `compras_id` bigint unsigned NOT NULL,
  `ventas_id` bigint unsigned NOT NULL,
  `fecha_registro` date DEFAULT NULL,
  `fechah_registro` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `precio_compra` decimal(10,2) DEFAULT NULL,
  `precio_venta` decimal(10,2) DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `libro_medicamento_id_foreign` (`medicamento_id`),
  KEY `libro_compras_id_foreign` (`compras_id`),
  KEY `libro_ventas_id_foreign` (`ventas_id`),
  CONSTRAINT `libro_compras_id_foreign` FOREIGN KEY (`compras_id`) REFERENCES `compras` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `libro_medicamento_id_foreign` FOREIGN KEY (`medicamento_id`) REFERENCES `medicamento` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `libro_ventas_id_foreign` FOREIGN KEY (`ventas_id`) REFERENCES `ventas` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.libro: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.lote
CREATE TABLE IF NOT EXISTS `lote` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `numero_lote` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stock` decimal(10,2) DEFAULT NULL,
  `stock_fraccion` decimal(10,2) DEFAULT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=205 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.lote: ~14 rows (aproximadamente)
REPLACE INTO `lote` (`id`, `numero_lote`, `stock`, `stock_fraccion`, `fecha_vencimiento`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`) VALUES
	(70, 'C011963', 0.00, NULL, '2040-01-01', '2023-05-31 04:13:43', '2023-06-01 04:09:19', 1, 2),
	(74, 'SL-123456', 1.00, NULL, '2022-08-01', NULL, '2023-06-04 15:45:28', NULL, 2),
	(76, 'CS-1234567', NULL, NULL, '2023-01-01', '2023-06-04 18:59:44', '2023-06-04 14:22:48', NULL, 1),
	(77, 'SN-897456', 0.00, NULL, '2023-07-01', '2023-06-04 19:05:50', '2023-06-04 14:20:00', NULL, 1),
	(197, '2071492', 57.00, NULL, '2025-07-01', '2023-06-06 18:53:52', NULL, 1, NULL),
	(198, '2112832', 33.00, NULL, '2025-11-01', '2023-06-06 18:53:52', NULL, 1, NULL),
	(199, '2040882', 19.00, NULL, '2025-04-01', '2023-06-06 18:53:52', NULL, 1, NULL),
	(200, '2081732', 56.00, NULL, '2024-08-01', '2023-06-06 18:53:52', NULL, 1, NULL),
	(201, '2020171', 36.00, NULL, '2024-02-01', '2023-06-06 18:53:52', NULL, 1, NULL),
	(202, '2086082_ 2112032', 6.00, NULL, '2025-11-01', '2023-06-06 18:53:52', NULL, 1, NULL),
	(203, '2080912_ 2028053', 8.00, NULL, '2026-02-01', '2023-06-06 18:53:52', NULL, 1, NULL),
	(204, 'SL-317', 10.00, NULL, NULL, '2023-06-06 18:53:52', NULL, 1, NULL);

-- Volcando estructura para tabla laravel.medicamento
CREATE TABLE IF NOT EXISTS `medicamento` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) COLLATE utf8mb4_unicode_ci NOT NULL,
  `imagen` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `concentracion` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cotenido_total` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `laboratorio_id` bigint unsigned DEFAULT NULL,
  `nombre_comercial_id` bigint unsigned DEFAULT NULL,
  `forma_farmaceutica_id` bigint unsigned DEFAULT NULL,
  `presentacion_id` bigint unsigned DEFAULT NULL,
  `dosificacion_id` bigint unsigned DEFAULT NULL,
  `precio_venta_fraccion` decimal(10,2) DEFAULT NULL,
  `precio_venta` decimal(10,2) DEFAULT NULL,
  `precio_compra` decimal(10,2) DEFAULT NULL,
  `registro_sanitario` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `medicado` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notas` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fraccion` int DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `medicamento_dosificacion_id_foreign` (`dosificacion_id`),
  KEY `medicamento_forma_farmaceutica_id_foreign` (`forma_farmaceutica_id`),
  KEY `medicamento_laboratorio_id_foreign` (`laboratorio_id`),
  KEY `medicamento_nombre_comercial_id_foreign` (`nombre_comercial_id`),
  KEY `medicamento_presentacion_id_foreign` (`presentacion_id`),
  CONSTRAINT `medicamento_dosificacion_id_foreign` FOREIGN KEY (`dosificacion_id`) REFERENCES `dosificacion` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `medicamento_forma_farmaceutica_id_foreign` FOREIGN KEY (`forma_farmaceutica_id`) REFERENCES `forma_farmaceutica` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `medicamento_laboratorio_id_foreign` FOREIGN KEY (`laboratorio_id`) REFERENCES `laboratorio` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `medicamento_nombre_comercial_id_foreign` FOREIGN KEY (`nombre_comercial_id`) REFERENCES `nombre_comercial` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `medicamento_presentacion_id_foreign` FOREIGN KEY (`presentacion_id`) REFERENCES `presentacion` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=318 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.medicamento: ~12 rows (aproximadamente)
REPLACE INTO `medicamento` (`id`, `nombre`, `imagen`, `concentracion`, `cotenido_total`, `laboratorio_id`, `nombre_comercial_id`, `forma_farmaceutica_id`, `presentacion_id`, `dosificacion_id`, `precio_venta_fraccion`, `precio_venta`, `precio_compra`, `registro_sanitario`, `medicado`, `notas`, `fraccion`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`) VALUES
	(3, 'analgan', NULL, '15mgh', NULL, 1, NULL, 1, NULL, NULL, NULL, 4.00, NULL, NULL, NULL, NULL, NULL, NULL, '2023-06-05 07:43:15', NULL, 2),
	(310, 'enterophar forte ', NULL, 'furazolidona 50mg/5ml', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1.00, 0.50, 'b', 'NO', 'c', NULL, '2023-06-06 23:53:52', NULL, 1, NULL),
	(311, 'broncophar plus', NULL, 'dextr15,bromehx 2mg, clorfe2mg,/5ml', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1.00, 0.50, 'c', 'NO', 'ds', NULL, '2023-06-06 23:53:52', NULL, 1, NULL),
	(312, 'broncobutol plus', NULL, 'salbutml2mg, ambrxol clorhidrt7.5mg/5ml', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1.00, 0.50, 'd', 'NO', '4', NULL, '2023-06-06 23:53:52', NULL, 1, NULL),
	(313, 'palatox forte', NULL, 'dextr10mg, guaifenecina100mg,/5ml', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1.00, 0.50, 'e', 'NO', '5', NULL, '2023-06-06 23:53:52', NULL, 1, NULL),
	(314, 'ibupirol', NULL, 'ibuprofeno100mg, /5ml', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1.00, 0.50, 'f', 'NO', '6', NULL, '2023-06-06 23:53:52', NULL, 1, NULL),
	(315, 'ibuprofeno', NULL, 'ibupr 100mg,/5ml frasco de 60ml', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 5.50, 3.00, 'g', 'NO', '7', NULL, '2023-06-06 23:53:52', NULL, 1, NULL),
	(316, 'clorfenamina maleato', NULL, 'clorfe2mg/5ml frasco de 60ml', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 5.00, 2.50, NULL, 'NO', 'recetado para bronquios y dolor general', NULL, '2023-06-06 23:53:52', '2023-06-07 01:06:49', 1, 2),
	(317, 'bismutol', NULL, 'bistmutol de 15ml', NULL, NULL, NULL, NULL, 10, NULL, NULL, 3.00, 1.50, 'a', 'NO', 'Recetado para dolores musculares, bronquios, tos ferina', NULL, '2023-06-06 23:53:52', '2023-06-07 00:51:21', 1, 2);

-- Volcando estructura para tabla laravel.medicamento_lote
CREATE TABLE IF NOT EXISTS `medicamento_lote` (
  `medicamento_id` bigint unsigned NOT NULL,
  `lote_id` bigint unsigned NOT NULL,
  `stock` int DEFAULT '0',
  KEY `medicamento_lote_medicamento_id_foreign` (`medicamento_id`),
  KEY `medicamento_lote_lote_id_foreign` (`lote_id`),
  CONSTRAINT `medicamento_lote_lote_id_foreign` FOREIGN KEY (`lote_id`) REFERENCES `lote` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `medicamento_lote_medicamento_id_foreign` FOREIGN KEY (`medicamento_id`) REFERENCES `medicamento` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.medicamento_lote: ~14 rows (aproximadamente)
REPLACE INTO `medicamento_lote` (`medicamento_id`, `lote_id`, `stock`) VALUES
	(3, 70, 0),
	(3, 74, 111),
	(3, 77, 0),
	(310, 197, 57),
	(311, 198, 33),
	(312, 199, 19),
	(313, 200, 56),
	(314, 201, 36),
	(315, 202, 6),
	(316, 203, 8),
	(317, 204, 10);

-- Volcando estructura para tabla laravel.migrations
CREATE TABLE IF NOT EXISTS `migrations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=69 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.migrations: ~24 rows (aproximadamente)
REPLACE INTO `migrations` (`id`, `migration`, `batch`) VALUES
	(45, '2014_10_12_000000_create_users_table', 1),
	(46, '2014_10_12_100000_create_password_reset_tokens_table', 1),
	(47, '2019_08_19_000000_create_failed_jobs_table', 1),
	(48, '2019_12_14_000001_create_personal_access_tokens_table', 1),
	(49, '2023_05_09_000000_create_cliente_table', 1),
	(50, '2023_05_09_000001_create_laboratorio_table', 1),
	(51, '2023_05_09_000002_create_proveedor_table', 1),
	(52, '2023_05_09_000003_create_nombre_comercial_table', 1),
	(53, '2023_05_09_000004_create_Lote_table', 1),
	(54, '2023_05_09_000005_create_sustancia_activa_table', 1),
	(55, '2023_05_09_000006_create_dosificacion_table', 1),
	(56, '2023_05_09_000007_create_forma_farmaceutica_table', 1),
	(57, '2023_05_09_000008_create_presentacion_table', 1),
	(58, '2023_05_09_000010_create_users_roles_table', 1),
	(59, '2023_05_09_000011_create_ventas_table', 1),
	(60, '2023_05_09_000012_create_principio_activo_medicamento_table', 1),
	(61, '2023_05_09_000013_create_compras_table', 1),
	(62, '2023_05_09_000014_create_medicamento_table', 1),
	(63, '2023_05_09_000015_create_users_roles_has_users_table', 1),
	(64, '2023_05_09_000016_create_libro_table', 1),
	(65, '2023_05_09_000017_create_compra_detalle_table', 1),
	(66, '2023_05_09_000018_create_medicamento_Lote_table', 1),
	(67, '2023_05_09_000019_create_venta_detalle_table', 1),
	(68, '2023_05_09_000020_create_inventario_table', 1);

-- Volcando estructura para tabla laravel.nombre_comercial
CREATE TABLE IF NOT EXISTS `nombre_comercial` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.nombre_comercial: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.password_reset_tokens
CREATE TABLE IF NOT EXISTS `password_reset_tokens` (
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.password_reset_tokens: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.personal_access_tokens
CREATE TABLE IF NOT EXISTS `personal_access_tokens` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tokenable_id` bigint unsigned NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `abilities` text COLLATE utf8mb4_unicode_ci,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.personal_access_tokens: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.presentacion
CREATE TABLE IF NOT EXISTS `presentacion` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `descripcion` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.presentacion: ~4 rows (aproximadamente)
REPLACE INTO `presentacion` (`id`, `descripcion`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`) VALUES
	(7, 'Pastillas', '2023-05-28 18:24:12', NULL, 1, NULL),
	(8, 'Botellas', '2023-05-28 18:24:12', NULL, 1, NULL),
	(9, 'Caja', '2023-05-28 18:24:12', NULL, 1, NULL),
	(10, 'Jarabe', '2023-05-28 18:24:12', NULL, 1, NULL);

-- Volcando estructura para tabla laravel.principio_activo_medicamento
CREATE TABLE IF NOT EXISTS `principio_activo_medicamento` (
  `nombre_comercial_id` bigint NOT NULL,
  `sustancia_activa_id` bigint NOT NULL,
  KEY `principio_activo_medicamento_nombre_comercial_id_foreign` (`nombre_comercial_id`),
  KEY `principio_activo_medicamento_sustancia_activa_id_foreign` (`sustancia_activa_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.principio_activo_medicamento: ~4 rows (aproximadamente)
REPLACE INTO `principio_activo_medicamento` (`nombre_comercial_id`, `sustancia_activa_id`) VALUES
	(3, 1),
	(3, 4),
	(3, 6);

-- Volcando estructura para tabla laravel.proveedor
CREATE TABLE IF NOT EXISTS `proveedor` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) COLLATE utf8mb4_unicode_ci NOT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  `ruc` varchar(12) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `direccion` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `celular` varchar(15) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.proveedor: ~5 rows (aproximadamente)
REPLACE INTO `proveedor` (`id`, `nombre`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`, `ruc`, `direccion`, `celular`) VALUES
	(2, 'Anonimo', NULL, NULL, NULL, NULL, '000000000000', NULL, NULL),
	(19, 'REPCAS', '2023-05-29 03:50:25', '2023-06-04 08:56:53', 1, NULL, '123456789', 'Calvario 1006 - Miraflores', '9393537564'),
	(33, 'INKAFARMA', '2023-06-05 07:23:43', NULL, 1, NULL, '9876543211', '1', '1'),
	(34, 'MIFARMA', '2023-06-05 07:23:43', NULL, 1, NULL, '9638527411', '1', '1'),
	(35, 'QUINZA', '2023-06-05 07:23:43', NULL, 1, NULL, '9632123332', '1', '1');

-- Volcando estructura para tabla laravel.roles_has_users
CREATE TABLE IF NOT EXISTS `roles_has_users` (
  `users_roles_id` bigint unsigned NOT NULL,
  `users_id` bigint unsigned NOT NULL,
  KEY `roles_has_users_users_roles_id_foreign` (`users_roles_id`),
  KEY `roles_has_users_users_id_foreign` (`users_id`),
  CONSTRAINT `roles_has_users_users_id_foreign` FOREIGN KEY (`users_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `roles_has_users_users_roles_id_foreign` FOREIGN KEY (`users_roles_id`) REFERENCES `users_roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.roles_has_users: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.sustancia_activa
CREATE TABLE IF NOT EXISTS `sustancia_activa` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.sustancia_activa: ~11 rows (aproximadamente)
REPLACE INTO `sustancia_activa` (`id`, `nombre`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`) VALUES
	(1, 'paracetamol', NULL, NULL, NULL, NULL),
	(2, 'metamizol', NULL, NULL, NULL, NULL),
	(3, 'diclofenaco', NULL, NULL, NULL, NULL),
	(4, 'clotrimazol', NULL, NULL, NULL, NULL),
	(5, 'gentamicina', NULL, NULL, NULL, NULL),
	(6, 'betametazona', NULL, NULL, NULL, NULL),
	(8, 'kiripínas', '2023-05-21 13:00:03', '2023-05-21 13:00:14', NULL, NULL),
	(14, 'pruebaasdfasd', '2023-05-28 18:11:12', '2023-05-28 18:11:35', 1, 2),
	(15, 'prueba1', '2023-05-28 18:11:12', NULL, 1, NULL),
	(16, 'prueba2', '2023-05-28 18:11:12', NULL, 1, NULL),
	(17, 'prueba3', '2023-05-28 18:11:12', NULL, 1, NULL);

-- Volcando estructura para tabla laravel.users
CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `remember_token` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.users: ~2 rows (aproximadamente)
REPLACE INTO `users` (`id`, `name`, `email`, `email_verified_at`, `password`, `remember_token`, `created_at`, `updated_at`) VALUES
	(1, 'Administrador', 'manager@tuportalfavorito.com', NULL, '$2y$10$Ydt5zMXJ0FdGQ6EsPqV7rOni438yKWOXcNRN7xDbQdpHBEGQc.4di', NULL, '2023-05-12 10:40:11', '2023-05-12 10:40:11'),
	(2, 'Administrador', 'henry.ti.3000@gmail.com', NULL, '$2y$10$BcHccCVCyLJ3TazEo9Mt5eF3Gcz.KtKW8v1gFPdv/fEVMOxoR/UCe', NULL, '2023-05-13 17:51:24', '2023-05-13 17:51:24');

-- Volcando estructura para tabla laravel.users_roles
CREATE TABLE IF NOT EXISTS `users_roles` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nivel` int DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.users_roles: ~0 rows (aproximadamente)

-- Volcando estructura para tabla laravel.ventas
CREATE TABLE IF NOT EXISTS `ventas` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `cliente_id` bigint unsigned NOT NULL,
  `fecha_venta` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `descuento` decimal(10,2) DEFAULT NULL,
  `Total_Venta` decimal(10,2) DEFAULT NULL,
  `fecha_reg` timestamp NULL DEFAULT NULL,
  `fecha_upd` timestamp NULL DEFAULT NULL,
  `iduser_reg` int DEFAULT NULL,
  `iduser_upd` int DEFAULT NULL,
  `contabilizado` varchar(1) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ventas_cliente_id_foreign` (`cliente_id`),
  CONSTRAINT `ventas_cliente_id_foreign` FOREIGN KEY (`cliente_id`) REFERENCES `cliente` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=53 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.ventas: ~35 rows (aproximadamente)
REPLACE INTO `ventas` (`id`, `cliente_id`, `fecha_venta`, `descuento`, `Total_Venta`, `fecha_reg`, `fecha_upd`, `iduser_reg`, `iduser_upd`, `contabilizado`) VALUES
	(1, 1, '2023-05-21', NULL, 36.52, '2023-05-21 16:30:27', NULL, 2, NULL, NULL),
	(2, 1, '2023-05-20', NULL, 37.04, '2023-05-21 09:40:45', NULL, NULL, NULL, 'S'),
	(3, 1, '2023-05-20', NULL, 37.04, '2023-05-21 10:41:15', NULL, NULL, NULL, 'S'),
	(4, 1, '2023-05-20', NULL, 37.04, '2023-05-21 11:41:46', NULL, NULL, NULL, 'S'),
	(5, 1, '2023-05-20', NULL, 37.04, '2023-05-21 09:42:18', NULL, NULL, NULL, 'S'),
	(6, 1, '2023-05-20', NULL, 37.04, '2023-05-21 12:42:47', NULL, NULL, NULL, 'S'),
	(7, 1, '2023-05-20', NULL, 37.04, '2023-05-21 09:43:04', NULL, NULL, NULL, 'S'),
	(8, 1, '2023-05-20', NULL, 37.04, '2023-05-21 15:44:46', NULL, NULL, NULL, 'S'),
	(9, 1, '2023-05-20', NULL, 37.04, '2023-05-21 15:45:18', NULL, NULL, NULL, 'S'),
	(10, 1, '2023-05-20', NULL, 37.04, '2023-05-21 16:46:11', NULL, NULL, NULL, 'S'),
	(11, 1, '2023-05-21', NULL, 39.86, '2023-05-21 09:50:37', NULL, 2, NULL, 'S'),
	(12, 1, '2023-05-21', NULL, 12.52, '2023-05-21 09:52:10', NULL, 2, NULL, 'S'),
	(13, 1, '2023-05-28', NULL, 125.20, '2023-05-28 22:03:26', NULL, 2, NULL, 'S'),
	(14, 1, '2023-05-28', NULL, 125.20, '2023-05-28 22:33:59', NULL, 2, NULL, 'S'),
	(15, 1, '2023-05-28', NULL, 12.52, '2023-05-28 22:36:01', NULL, 2, NULL, 'S'),
	(16, 1, '2023-05-28', NULL, 12.52, '2023-05-28 22:36:38', NULL, 2, NULL, 'S'),
	(17, 1, '2023-05-28', NULL, 12.52, '2023-05-28 22:37:35', NULL, 2, NULL, 'S'),
	(18, 1, '2023-05-28', NULL, 25.04, '2023-05-28 22:38:45', NULL, 2, NULL, 'S'),
	(19, 1, '2023-05-28', NULL, 12.52, '2023-05-28 22:40:23', NULL, 2, NULL, 'S'),
	(20, 1, '2023-05-28', NULL, 12.52, '2023-05-28 22:41:04', NULL, 2, NULL, 'S'),
	(21, 1, '2023-05-28', NULL, 125.20, '2023-05-28 22:52:29', NULL, 2, NULL, 'S'),
	(22, 1, '2023-05-28', NULL, 12.52, '2023-05-28 22:53:55', NULL, 2, NULL, 'S'),
	(23, 1, '2023-05-28', NULL, 125.20, '2023-05-29 01:28:35', NULL, 2, NULL, 'S'),
	(24, 1, '2023-05-28', NULL, 12.52, '2023-05-29 02:03:21', NULL, 2, NULL, 'S'),
	(25, 1, '2023-05-28', NULL, 125.20, '2023-05-29 03:55:29', NULL, 2, NULL, 'S'),
	(26, 1, '2023-05-28', NULL, 125.20, '2023-05-29 03:59:42', NULL, 2, NULL, 'S'),
	(27, 1, '2023-05-29', NULL, 125.20, '2023-05-29 05:16:07', NULL, 2, NULL, 'S'),
	(28, 1, '2023-05-30', NULL, 3.50, '2023-05-30 22:37:55', NULL, 2, NULL, 'S'),
	(29, 1, '2023-05-30', NULL, 12.52, '2023-05-30 23:23:21', NULL, 2, NULL, 'S'),
	(30, 1, '2023-05-30', NULL, 12.52, '2023-05-30 23:25:40', NULL, 2, NULL, 'S'),
	(43, 1, '2023-06-04', NULL, 3.50, '2023-06-04 07:55:32', NULL, 2, NULL, 'S'),
	(44, 1, '2023-06-04', NULL, 3.50, '2023-06-04 07:59:08', NULL, 2, NULL, 'S'),
	(45, 1, '2023-06-04', NULL, 3.50, '2023-06-04 08:01:15', NULL, 2, NULL, 'S'),
	(46, 3, '2023-06-04', NULL, 3.50, '2023-06-04 20:41:27', NULL, 2, NULL, 'S'),
	(47, 3, '2023-06-04', NULL, 3.50, '2023-06-04 20:41:31', NULL, 2, NULL, 'S'),
	(48, 3, '2023-06-04', NULL, 3.50, '2023-06-04 20:41:41', NULL, 2, NULL, 'S'),
	(49, 3, '2023-06-04', NULL, 3.50, '2023-06-04 20:42:18', NULL, 2, NULL, 'S'),
	(50, 3, '2023-06-04', NULL, 3.50, '2023-06-04 20:44:43', NULL, 2, NULL, 'S'),
	(51, 1, '2023-06-04', NULL, 3.50, '2023-06-04 20:45:28', NULL, 2, NULL, 'S'),
	(52, 1, '2023-06-05', NULL, 1.50, '2023-06-05 07:45:26', NULL, 2, NULL, 'S');

-- Volcando estructura para tabla laravel.venta_detalle
CREATE TABLE IF NOT EXISTS `venta_detalle` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ventas_id` bigint unsigned NOT NULL,
  `medicamento_id` bigint unsigned NOT NULL,
  `lote_id` bigint DEFAULT NULL,
  `cantidad` int DEFAULT NULL,
  `fraccion` int DEFAULT NULL,
  `precio_venta` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `venta_detalle_ventas_id_foreign` (`ventas_id`),
  KEY `venta_detalle_medicamento_id_foreign` (`medicamento_id`),
  CONSTRAINT `venta_detalle_medicamento_id_foreign` FOREIGN KEY (`medicamento_id`) REFERENCES `medicamento` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `venta_detalle_ventas_id_foreign` FOREIGN KEY (`ventas_id`) REFERENCES `ventas` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=46 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla laravel.venta_detalle: ~12 rows (aproximadamente)
REPLACE INTO `venta_detalle` (`id`, `ventas_id`, `medicamento_id`, `lote_id`, `cantidad`, `fraccion`, `precio_venta`) VALUES
	(21, 28, 3, NULL, 1, NULL, 3.50),
	(36, 43, 3, NULL, 1, NULL, 3.50),
	(37, 44, 3, NULL, 1, NULL, 3.50),
	(38, 45, 3, 74, 1, NULL, 3.50),
	(39, 46, 3, 74, 1, NULL, 3.50),
	(40, 47, 3, 74, 1, NULL, 3.50),
	(41, 48, 3, 74, 1, NULL, 3.50),
	(42, 49, 3, 74, 1, NULL, 3.50),
	(43, 50, 3, 74, 1, NULL, 3.50),
	(44, 51, 3, 74, 1, NULL, 3.50);

-- Volcando estructura para procedimiento laravel.Venta_lote
DELIMITER //
CREATE PROCEDURE `Venta_lote`(
	IN `ve_idlote` BIGINT(20),
	IN `ve_num_lote` varchar(100),
	IN `ve_idmedicamento` BIGINT(20),
	IN `ve_stock` DECIMAL(15,2),
	IN `ve_fecha_venc` DATE,
	IN `ve_iduser` INT(11),
	IN `ve_accion` CHAR(1),
	OUT `vo_coderror` INT(10),
	OUT `vo_msgerror` VARCHAR(100)
)
BEGIN
    -- Declaración e inicialización de variables locales
    DECLARE v_stock_actual DECIMAL(15,2);
    DECLARE vi_idlote BIGINT(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Manejo de la Excepción
        ROLLBACK;
        SET vo_coderror = -1;
         SHOW ERRORS LIMIT 1;
         SET vo_msgerror = CONCAT('Error: ', MYSQL_ERRNO, ' - ', SQLERRM());
    END;    
    SET vo_coderror = 0;
    SET vo_msgerror = '';    
    START TRANSACTION;    
    -- Actualizar el stock
    IF ve_accion = 'U' AND ve_idlote > 0 THEN
        -- Obtener el stock actual
        SELECT stock INTO v_stock_actual
        FROM MEDICAMENTO_LOTE
        WHERE medicamento_id = ve_idmedicamento
        AND lote_id = ve_idlote;        
        IF v_stock_actual IS NOT NULL THEN
            -- Actualizar tabla LOTE fecha de vencimiento.
            UPDATE LOTE
            SET stock = stock - ve_stock,
                -- fecha_vencimiento = ve_fecha_venc,
                fecha_upd = NOW(),
                iduser_upd = ve_iduser
            WHERE id = ve_idlote;           
            -- Actualizar STOCK en tabla MEDICAMENTO_LOTE
            UPDATE MEDICAMENTO_LOTE
            SET stock = stock - ve_stock
            WHERE medicamento_id = ve_idmedicamento
            AND lote_id = ve_idlote;            
        ELSE
            SET vo_coderror = -1;
            SET vo_msgerror = 'El lote no existe.';
        END IF;
    END IF;
    IF ve_accion = 'D' AND ve_idlote > 0 THEN
        -- Obtener el stock actual
        SELECT stock INTO v_stock_actual
        FROM MEDICAMENTO_LOTE
        WHERE medicamento_id = ve_idmedicamento
        AND lote_id = ve_idlote;        
        IF v_stock_actual IS NOT NULL THEN
            -- Actualizar tabla LOTE fecha de vencimiento.
            UPDATE LOTE
            SET stock = stock + ve_stock,
                -- fecha_vencimiento = ve_fecha_venc,
                fecha_upd = NOW(),
                iduser_upd = ve_iduser
            WHERE id = ve_idlote;           
            -- Actualizar STOCK en tabla MEDICAMENTO_LOTE
            UPDATE MEDICAMENTO_LOTE
            SET stock = stock + ve_stock
            WHERE medicamento_id = ve_idmedicamento
            AND lote_id = ve_idlote;
            
        ELSE
            SET vo_coderror = -1;
            SET vo_msgerror = 'El lote no existe.';
        END IF;
    END IF;
    IF ve_accion = 'R' AND ve_idlote > 0 THEN
        -- Obtener el stock actual
        SELECT stock INTO v_stock_actual
        FROM MEDICAMENTO_LOTE
        WHERE medicamento_id = ve_idmedicamento
        AND lote_id = ve_idlote;        
        IF v_stock_actual IS NOT NULL THEN
            -- Actualizar tabla LOTE fecha de vencimiento.
            UPDATE LOTE
            SET stock = stock - ve_stock,
                -- fecha_vencimiento = ve_fecha_venc,
                fecha_upd = NOW(),
                iduser_upd = ve_iduser
            WHERE id = ve_idlote;           
            -- Actualizar STOCK en tabla MEDICAMENTO_LOTE
            UPDATE MEDICAMENTO_LOTE
            SET stock = stock - ve_stock
            WHERE medicamento_id = ve_idmedicamento
            AND lote_id = ve_idlote;
            
        ELSE
            SET vo_coderror = -1;
            SET vo_msgerror = 'El lote no existe.';
        END IF;
    END IF;
    COMMIT;    
END//
DELIMITER ;

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
