-- PARTE 1: MODELADO RELACIONAL TRADICIONAL

-- PASO 1: CREAR LA BASE DE DATOS
CREATE DATABASE lab_bdoo;

-- PASO 2: CREAR TABLAS RELACIONALES TRADICIONALES

-- Tabla de direcciones
CREATE TABLE direcciones (
	id SERIAL PRIMARY KEY,
	calle VARCHAR(100),
	numero VARCHAR(10),
	ciudad VARCHAR(50),
	codigo_postal VARCHAR(10)
);

-- Tabla de autores
CREATE TABLE autores (
	id SERIAL PRIMARY KEY,
	nombre VARCHAR(100),
	apellido VARCHAR(100),
	fecha_nacimiento DATE,
	direccion_id INTEGER REFERENCES direcciones(id)
);

-- Tabla de libros
CREATE TABLE libros (
	id SERIAL PRIMARY KEY,
	titulo VARCHAR(200),
	isbn VARCHAR(20),
	año_publicacion INTEGER,
	precio NUMERIC(10, 2),
	autor_id INTEGER REFERENCES autores(id)
);

-- PASO 3: INSERTAR DATOS EN EL MODELO RELACIONAL

-- Insertar dirección
INSERT INTO direcciones (calle, numero, ciudad, codigo_postal)
VALUES ('Av. Arequipa', '1234', 'Lima', '15001');

-- Insertar autor
INSERT INTO autores (nombre, apellido, fecha_nacimiento, direccion_id)
VALUES ('Mario', 'Vargas Llosa', '1936-03-28', 1);

-- Insertar libros
INSERT INTO libros (titulo, isbn, año_publicacion, precio, autor_id)
VALUES
	('La ciudad y los perros', '978-8420471839', 1963, 45.50, 1),
	('Conversación en La Catedral', '978-8466326070', 1969, 52.00, 1);

-- PASO 4: CONSULTAR DATOS (requiere JOINs)

-- Para obtener libro con datos de autor y su dirección
SELECT
	l.titulo,
	l.isbn,
	a.nombre || ' ' || a.apellido AS autor,
	d.ciudad
FROM libros l
JOIN autores a ON l.autor_id = a.id
JOIN direcciones d ON a.direccion_id = d.id

-- OBSERVACIÓN: Note que necesitamos 2 JOINs para obtener información completa 


-- PARTE 2: MODELADO OBJETO-RELACIONAL

-- Paso 5: CREAR TIPOS DE DATOS PERSONALIZADOS

-- Tipo personalizado para direccion
CREATE TYPE tipo_direccion AS (
	calle VARCHAR(100),
	numero VARCHAR(10),
	ciudad VARCHAR(50),
	codigo_postal VARCHAR(10)
);

-- Tipo personalizado para autor
CREATE TYPE tipo_autor AS (
	nombre VARCHAR(100),
	apellido VARCHAR(100),
	fecha_nacimiento DATE,
	direccion tipo_direccion
);

-- Paso 6: CREAR TABLA CON TIPOS COMPUESTOS

-- Tabla de libros con tipos compuestos 
CREATE TABLE libros_oo (
	id SERIAL PRIMARY KEY,
	titulo VARCHAR(200),
	isbn VARCHAR(20),
	año_publicacion INTEGER,
	precio NUMERIC(10, 2),
	autor tipo_autor
);

-- OBSERVACIÓN: Note que el campo 'autor' es un tipo complejo que contiene toda la información del autor, incluyendo su dirección anidada.

-- PASO 7: INSERTAR DATOS EN EL MODELO OBJETO-RELACIONAL 

-- Insertar libro con autor y direccion anidados
INSERT INTO libros_oo (titulo, isbn, año_publicacion, precio, autor)
VALUES (
	'La ciudad y los perros',
	'978-8420471839',
	1963,
	45.50,
	ROW('Mario', 'Vargas Llosa', '1936-03-28',
		ROW('Av. Arequipa', '1234', 'Lima', '15001'))::tipo_autor
);

INSERT INTO libros_oo (titulo, isbn, año_publicacion, precio, autor)
VALUES (
	'Conversación en La Catedral',
	'978-84266326070',
	1969,
	52.00,
	ROW('Mario', 'Vargas Llosa', '1936-03-28',
		ROW('Av. Arequipa', '1234', 'Lima', '15001'))::tipo_autor
);

-- Paso 8: CONSULTAR DATOS SIN JOINS (navegación por puntos)

-- Acceso directo a campos anidados usando notación de punto
SELECT
	titulo,
	isbn,
	(autor).nombre || ' ' || (autor).apellido AS nombre_autor,
	((autor).direccion).ciudad AS ciudad_autor
FROM libros_oo;

-- OBSERVACIÓN: No necesitamos JOINs. Accedemos directamente a los datos anidados usando notación de punto, similar a la programación orientada a objetos.


-- PARTE 3: COMPARACIÓN Y ANÁLISIS

-- Paso 9: COMPARAR CONSULTAS

-- Consulta relacional 
SELECT
	l.titulo,
	a.nombre || ' ' || a.apellido AS autor,
	d.ciudad
FROM libros l
JOIN autores a ON l.autor_id = a.id
JOIN direcciones d ON a.direccion_id = d.id

-- Consulta objeto-relacional
SELECT
	titulo,
	(autor).nombre || ' ' || (autor).apellido AS nombre_autor,
	((autor).direccion).ciudad AS ciudad_autor
FROM libros_oo;




