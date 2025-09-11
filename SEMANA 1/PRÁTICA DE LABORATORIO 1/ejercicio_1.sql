-- Crear base de datos
CREATE DATABASE practica_almacenamiento;

-- Conectarse a la base de datos
\c practica_almacenamiento;

-- Crear tabla estudiantes 
CREATE TABLE estudiantes (
	id_estudiante INTEGER PRIMARY KEY,
	nombres VARCHAR(50) NOT NULL,
	apellido VARCHAR(50) NOT NULL,
	carrera VARCHAR(30),
	semestre INTEGER,
	promedio DECIMAL(4,2)
);
