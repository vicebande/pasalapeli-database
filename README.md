# 🗄️ Pasa La Peli - Base de Datos MySQL & Infraestructura

Repositorio que contiene el script oficial de creación e inicialización de base de datos MySQL para la plataforma de cine **Pasa La Peli**.

Parte del ecosistema Cloud Native **Pasa La Peli** para **Desarrollo Cloud Native I (DSY1107) - Duoc UC**.

---

## 📋 Contenido
- **`init.sql`**: Script DDL y DML para MySQL 8.0.
  - Tablas: `Usuario`, `Pelicula`, `Funcion`, `Ticket`, `Pago`.
  - Llaves foráneas, índices y restricciones de integridad.
  - Datos de prueba iniciales (seed data).

---

## 🛠️ Ejecución con MySQL
```bash
mysql -u root -p < init.sql
```
O mediante contenedor Docker:
```bash
docker run --name pasalapeli-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=pasalapeli_db -p 3306:3306 -v $(pwd)/init.sql:/docker-entrypoint-initdb.d/init.sql:ro -d mysql:8.0
```
