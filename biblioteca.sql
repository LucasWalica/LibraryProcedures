create table libros(
    ID INT AUTO_Increment primary key,
    titulo varchar(40),
    autor varchar(40),
    añoPub int,
    categoria varchar(50),
    prestado int default 0 check (prestado in (0,1)),
    estado int default 10 check (estado BETWEEN 1 and 10)
)
create table socios(
    ID int primary key AUTO_INCREMENT,
    nombre varchar(30),
    apellidos varchar(30),
    sancionado int default 0 check(sancionado in(0,1)), 
    tienePrestamo int default 0 check(tienePrestamo in (0,1))
)
--todos los estados por los que han pasado los libros
create table auditoria(
    id int primary key AUTO_INCREMENT,
    fecha DATE default CURRENT_DATE,
    idLibro int, 
    idSocio int, 
    tipoDeAccion varchar(20),
    estadoLibro int default 10 check(estadoLibro BETWEEN 1 and 10),
    FOREIGN key(idLibro) references libros(ID),
    FOREIGN key(idSocio) references socios(ID)
)

--tabla audotira mensual
create table auditoriaMensual (
    id int primary key AUTO_INCREMENT,
    fecha DATE default CURRENT_DATE,
    idLibro int, 
    idSocio int, 
    tipoDeAccion varchar(20),
    estadoLibro int default 10 check(estadoLibro BETWEEN 1 and 10),
    FOREIGN key(idLibro) references libros(ID),
    FOREIGN key(idSocio) references socios(ID)
)


DELIMITER $$

create procedure registrarLibro(IN tit varchar(40), IN aut varchar(40), IN añoPubli int,IN cat varchar(50), IN bState int)
BEGIN 
    declare existeTitulo int;
    declare existeAutor int;
    declare existeañoPub int;
    declare existeCategoria int;
    declare existebState int;
    declare mensaje varchar(255);

    select count(titulo) into existeTitulo from libros where titulo=tit;
    select count(autor) into existeAutor from libros where autor=aut;
    select count(añoPubli) into existeañoPub from libros where añoPub = añoPubli;
    select count(categoria) into existeCategoria from libros where categoria = cat;
    select count(estado) into existebState from libros where estado=bState;

    if(existeAutor>=1 and existeAutor>=1 and existeañoPub>=1 and existeCategoria>=1 and existebState>=1) then 
        set mensaje = "Este libro ya existe en la base de datos.";
        SIGNAL SQLSTATE '45000' set MESSAGE_TEXT = mensaje;
    else 
        insert into libros (titulo, autor, añoPub, categoria, estado)
        values (tit, aut, añoPubli, cat, bState);
        set mensaje = "Libro insertado correctamente.";
        SIGNAL SQLSTATE '45000' set MESSAGE_TEXT = mensaje;
    end if;
END $$
DELIMITER ;

 call registrarLibro("Enemigos del comercio", "Antonio Escohotado", 1999, "Historia", 10);


-- este procedure sirve para que los trabajadores de la biblioteca actualizen el estado de degradacion del libro
DELIMITER $$

CREATE PROCEDURE actualizar_estado_libro(IN IDLibro INT, IN BState INT)
BEGIN
    DECLARE libroExiste INT;
    DECLARE mensaje VARCHAR(255);

    SELECT COUNT(ID) INTO libroExiste FROM libros WHERE ID = IDLibro;

    IF (libroExiste >= 1) THEN
        UPDATE libros
        SET estado = BState
        WHERE libros.ID = IDLibro;
        SET mensaje = "Estado del libro actualizado correctamente. ";
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensaje;
    ELSE
        SET mensaje = "No existe un libro con ese ID.";
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensaje;
    END IF;
END $$

DELIMITER ;

call actualizar_estado_libro(1, 8)



DELIMITER $$

CREATE PROCEDURE prestar_libro(IN IDUser INT, IN IDBook INT)
BEGIN 
    DECLARE mensaje VARCHAR(255);
    DECLARE libroDisponible INT;
    DECLARE estadoBook INT;
    DECLARE socioNoPrestamos INT;
    DECLARE accion varchar(30);

    SELECT estado INTO estadoBook FROM libros WHERE ID = IDBook;
    select tienePrestamo INTO socioNoPrestamos from socios where ID = IDUser;

    SELECT COUNT(ID) INTO libroDisponible FROM libros WHERE ID = IDBook AND prestado = 0;
    
    IF (libroDisponible >= 1 AND socioNoPrestamos=0) THEN 
        UPDATE libros SET prestado = 1 WHERE ID = IDBook;

        UPDATE socios SET tienePrestamo = 1 WHERE ID = IDUser;
        
        SET accion = "Prestamo";
        
        INSERT INTO auditoria(idLibro, idSocio, tipoDeAccion, estadoLibro) VALUES (IDBook, IDUser, accion, estadoBook);

        SET mensaje = "El préstamo se ha realizado correctamente.";
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensaje;
    ELSE 
        SET mensaje = "No se ha podido realizar el préstamo.";
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensaje;
    END IF;
END $$ 

DELIMITER ;


insert into socios(nombre, apellidos)
values ("Pepito", "Walica");
call prestar_libro(1, 1)

insert into libros(titulo, autor, añoPub, categoria)
values ("Crepusculo", "JK Rowling", 2004, "Romance")

insert into socios(nombre, apellidos)
values ("Maria", "Rodriguez Garea")

call prestar_libro(1, 1);

DELIMITER $$
create procedure devolver_libro(IN IDUser INT, IN IDbook INT, IN estadoLibroActual int)
BEGIN
    declare mensaje varchar(255);
    declare libroPrestado int;
    declare socioTienePrestamos int;
    declare accion varchar(20);
    set accion = "devolucion";
    select count(ID) into libroPrestado From libros where id = IDbook and prestado = 1;
    select tienePrestamo into socioTienePrestamos from socios where ID = IDUser;

    if(libroPrestado>=1 AND socioTienePrestamos=1) then 

        update libros set libros.prestado = 0 where id = IDbook;

        update libros set libros.estado = estadoLibroActual where libros.id = IDbook;

        update socios set socios.tienePrestamo = 0 where ID = IDUser;
    
        insert into auditoria(idLibro, idSocio, tipoDeAccion, estadoLibro) values (IDbook, IDUser, accion, estadoLibroActual);

    
    
        SET mensaje = "Se ha devuelto el libro. ";
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensaje;
    

    elseif(estadoLibroActual>10 or estadoLibroActual<1) then
        SET mensaje = "El valor no coincide con un estado valido. ";
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensaje;
    else 
        SET mensaje = "No se ha podido devolver el libro. ";
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensaje;
    end if;
end $$ 
DELIMITER ; 


call devolver_libro(1, 1);


DELIMITER $$
create procedure generar_reporte_actividad()
BEGIN 
    declare fecha_mes_anterior DATE;
    set fecha_mes_anterior  = DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH);

    DELETE FROM auditoriaMensual;
    INSERT INTO auditoriaMensual (fecha, idLibro, idSocio, tipoDeAccion, estadoLibro)
    select fecha, idLibro, idSocio, tipoDeAccion, estadoLibro 
    from auditoria where fecha > fecha_mes_anterior;

    select * from auditoriaMensual;
END $$ 
DELIMITER ;