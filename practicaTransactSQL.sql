 /*******************************************************/
 /*                        T-SQL                        */
/*******************************************************/
/*
1. Hacer una función que dado un artículo y un deposito devuelva un string que
indique el estado del depósito según el artículo. Si la cantidad almacenada es menor
al límite retornar “OCUPACION DEL DEPOSITO XX %” siendo XX el % de
ocupación. Si la cantidad almacenada es mayor o igual al límite retornar
“DEPOSITO COMPLETO”.
*/
GO
IF EXISTS (SELECT name FROM sysobjects WHERE name='estado_deposito' AND type in ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION estado_deposito
GO
CREATE FUNCTION estado_deposito
(  @prod_codigo char(8), @depo_codigo char(2) )
RETURNS Nvarchar(200)
BEGIN
	DECLARE @cant_stock int
	DECLARE @max_stock int
	DECLARE @RESPUESTA varchar(200)

	SELECT TOP 1 @cant_stock=isnull(stoc_cantidad,0), @max_stock=isnull(stoc_stock_maximo,0)
	FROM STOCK
	WHERE stoc_deposito=@depo_codigo AND stoc_producto=@prod_codigo
	

	if (@cant_stock>=@max_stock)
		SET @RESPUESTA= 'DEPOSITO COMPLETO'
	else 
	BEGIN
		DECLARE @porcentaje int
		SET @porcentaje = case when @max_stock=0 then 0 else @cant_stock*100/@max_stock end
		SET @RESPUESTA= convert(varchar,CONCAT('OCUPACION DEL DEPOSITO ',@porcentaje, '%'))
	END
RETURN @RESPUESTA
END
GO

select dbo.estado_deposito(stoc_producto, stoc_deposito) as funcion, isnull(stoc_cantidad,0) cant, isnull(stoc_stock_maximo,0) limit
FROM STOCK 

/*2. Realizar una función que dado un artículo y una fecha, retorne el stock que existía a
esa fecha
*/
GO
CREATE FUNCTION stock_fecha
(@prod_codigo char(8), @fecha smalldatetime)
returns int
BEGIN --ni idea como funciona lo de reposicion, si tuviera una fecha de cuando se repuso 
	  --por ultima vez (en lugar hay de la prox que se va a reponer podria hacer algo mas
	DECLARE @Vendidos_Desde_Entonces int
	DECLARE @Stock_Actual int
	
	SELECT @Vendidos_Desde_Entonces=
			SUM(case when @prod_codigo=item_producto then item_cantidad
		   else case when @prod_codigo=c1.comp_componente then item_cantidad*c1.comp_cantidad
		   else case when @prod_codigo=c2.comp_componente then item_cantidad*c1.comp_cantidad*c2.comp_cantidad end end end)
	FROM Item_Factura JOIN Factura ON (item_numero=fact_numero AND item_sucursal=fact_sucursal AND item_tipo=fact_tipo)
					  LEFT JOIN Composicion c1 ON (c1.comp_componente=item_producto)
					  LEFT JOIN Composicion c2 ON (c2.comp_componente=c1.comp_producto)
	WHERE convert(DATE,fact_fecha) BETWEEN convert(DATE,@fecha) AND convert(DATE,GETDATE())
		  AND @prod_codigo in (item_producto,c1.comp_componente,c2.comp_componente)

	SELECT @Stock_Actual=SUM(stoc_cantidad)
	FROM STOCK
	WHERE stoc_producto=@prod_codigo

	RETURN @Stock_Actual+@Vendidos_Desde_Entonces
END 
GO

DROP FUNCTION stock_fecha

/*3. Cree el/los objetos de base de datos necesarios para corregir la tabla empleado en
caso que sea necesario. Se sabe que debería existir un único gerente general (debería
ser el único empleado sin jefe). Si detecta que hay más de un empleado sin jefe
deberá elegir entre ellos el gerente general, el cual será seleccionado por mayor
salario. Si hay más de uno se seleccionara el de mayor antigüedad en la empresa.
Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla de un único
empleado sin jefe (el gerente general) y deberá retornar la cantidad de empleados
que había sin jefe antes de la ejecución.
*/
GO
IF EXISTS (SELECT name FROM sysobjects WHERE name='arreglar_gerente' AND type='p')
	DROP PROCEDURE arreglar_gerente
GO
CREATE PROC arreglar_gerente
(@cant_emps_sin_jefe int OUTPUT)
AS
BEGIN
	DECLARE @jefe_codigo numeric(6,0)
	DECLARE @emps_sin_jefe TABLE(
		empl_codigo numeric(6,0)
	)
	INSERT INTO @emps_sin_jefe
	SELECT empl_codigo 
	FROM Empleado
	WHERE empl_jefe IS NULL
	ORDER BY empl_salario DESC, empl_ingreso ASC
	
	set @cant_emps_sin_jefe =(SELECT  COUNT (*) FROM @emps_sin_jefe)
	
	IF (@cant_emps_sin_jefe>1)
		BEGIN
			SELECT TOP 1 @jefe_codigo=empl_codigo
			FROM @emps_sin_jefe
			
			UPDATE Empleado
			SET empl_jefe=@jefe_codigo
			WHERE empl_jefe is null AND empl_codigo!=@jefe_codigo

		END
	RETURN @cant_emps_sin_jefe
END
GO

	
/*4. Cree el/los objetos de base de datos necesarios para actualizar la columna de
empleado empl_comision con la sumatoria del total de lo vendido por ese empleado
a lo largo del último año. Se deberá retornar el código del vendedor que más vendió
(en monto) a lo largo del último año.
*/
--SE INTERPRETA ULTIMO AÑO COMO EL AÑO ANTERIOR A ESTE
--EL MONTO SE CALCULA SIN fact_total_impuestos
GO
IF OBJECT_ID('actualizar_comision_empleados','P') IS NOT NULL
	DROP PROCEDURE actualizar_comision_empleados
GO
CREATE PROCEDURE actualizar_comision_empleados
(@mayor_vendedor numeric(6) OUTPUT)
AS
BEGIN
	
	UPDATE Empleado
	SET empl_comision = isnull(
					   (SELECT SUM(f1.fact_total)
						FROM Factura AS f1
						WHERE f1.fact_vendedor=empl_codigo AND YEAR(f1.fact_fecha)=YEAR(GETDATE())-1)
						,0)
	
	set @mayor_vendedor = (SELECT TOP 1 empl_codigo
						   FROM Empleado
						   ORDER BY empl_comision DESC)
END
GO
/*5. Realizar un procedimiento que complete con los datos existentes en el modelo
provisto la tabla de hechos denominada Fact_table tiene las siguiente definición:
Create table Fact_table
( anio char(4),
mes char(2),
familia char(3),
rubro char(4),
zona char(3),
cliente char(6),
producto char(8),
cantidad decimal(12,2),
monto decimal(12,2)
)
Alter table Fact_table
Add constraint primary key(anio,mes,familia,rubro,zona,cliente,producto)
*/

if OBJECT_ID('Fact_table','U') IS NOT NULL 
DROP TABLE Fact_table
GO
Create table Fact_table
(
anio char(4) NOT NULL, --YEAR(fact_fecha)
mes char(2) NOT NULL, --RIGHT('0' + convert(varchar(2),MONTH(fact_fecha)),2)
familia char(3) NOT NULL,--prod_familia
rubro char(4) NOT NULL,--prod_rubro
zona char(3) NOT NULL,--depa_zona
cliente char(6) NOT NULL,--fact_cliente
producto char(8) NOT NULL,--item_producto
cantidad decimal(12,2) NOT NULL,--item_cantidad
monto decimal(12,2)--asumo que es item_precio debido a que es por cada producto, 
				   --asumo tambien que el precio ya esta determinado por total y no por unidad (no debe multiplicarse por cantidad)
)
Alter table Fact_table
Add constraint pk_Fact_table_ID primary key(anio,mes,familia,rubro,zona,cliente,producto)
GO

if OBJECT_ID('llenar_fact_table','P') IS NOT NULL
DROP PROCEDURE llenar_fact_table
GO

CREATE PROCEDURE llenar_fact_table
AS
BEGIN
	INSERT INTO Fact_table 
	SELECT YEAR(fact_fecha)
		  ,RIGHT('0' + convert(varchar(2),MONTH(fact_fecha)),2)
		  ,prod_familia
		  ,prod_rubro
		  ,depa_zona
		  ,fact_cliente
		  ,item_producto
		  ,sum(item_cantidad)
		  ,sum(item_precio)
	FROM Factura
		 JOIN Item_Factura
			ON fact_sucursal = item_sucursal
			AND fact_tipo = item_tipo
			AND fact_numero=item_numero
		 JOIN Producto ON item_producto=prod_codigo
		 JOIN Empleado ON fact_vendedor=empl_codigo
		 JOIN Departamento ON empl_departamento=depa_codigo
	GROUP BY  YEAR(fact_fecha)
			  ,RIGHT('0' + convert(varchar(2),MONTH(fact_fecha)),2)
			  ,prod_familia
			  ,prod_rubro
			  ,depa_zona
			  ,fact_cliente
			  ,item_producto
END
GO

EXECUTE llenar_fact_table
GO 
/*6. Realizar un procedimiento que si en alguna factura se facturaron componentes que
conforman un combo determinado (o sea que juntos componen otro producto de
mayor nivel), en cuyo caso deberá reemplazar las filas correspondientes a dichos
productos por una sola fila con el producto que componen con la cantidad de dicho
producto que corresponda.
*/
GO
IF EXISTS (SELECT *
           FROM   sys.objects
           WHERE  object_id = OBJECT_ID(N'compuesto_en_factura')
                  AND type IN ( 'P' ))
  DROP PROCEDURE compuesto_en_factura
GO

CREATE PROCEDURE compuesto_en_factura (@Prod_codigo char(8),@Fact_tipo char(1), @Fact_sucursal char(4), @Fact_numero char(8))
AS
BEGIN
	--si el producto no esta ya en la factura
	if (@Prod_codigo not in (SELECT item_producto FROM Item_Factura WHERE  @Fact_sucursal = item_sucursal AND @Fact_tipo = item_tipo AND @Fact_numero=item_numero))
	--si estan todos los componentes
	if (SELECT count(comp_componente) FROM Composicion WHERE comp_producto=@Prod_codigo)
	  =(SELECT count(distinct item_producto) FROM Item_Factura WHERE @Fact_sucursal = item_sucursal AND @Fact_tipo = item_tipo AND @Fact_numero=item_numero)
	
	BEGIN
		DECLARE @cantidad int
		DECLARE @precio decimal(12,2)
		
		--se busca la cantidad de unidades a partir del componente limitante
		SELECT @cantidad = min(item_cantidad/comp_cantidad)
		FROM Item_Factura JOIN Composicion ON item_producto=comp_componente
		WHERE @Prod_codigo=comp_producto AND @Fact_sucursal = item_sucursal AND @Fact_tipo = item_tipo AND @Fact_numero=item_numero
		
		SELECT @precio=prod_precio*@cantidad FROM Producto WHERE prod_codigo=@Prod_codigo

		--si el limitante es mayor a 0 (si se puede formar al menos un ejemplar de producto)
		IF @cantidad>0
		BEGIN
			DELETE FROM Item_Factura
			WHERE  @Fact_sucursal = item_sucursal AND @Fact_tipo = item_tipo AND @Fact_numero=item_numero 
			AND item_producto in (SELECT comp_componente FROM Composicion WHERE comp_producto=@Prod_codigo)
		
			INSERT INTO Item_Factura (item_numero,  item_tipo,  item_sucursal,  item_producto, item_cantidad, item_precio)
							  values (@Fact_numero, @Fact_tipo, @Fact_sucursal, @Prod_codigo,  @cantidad,     @precio)
		END
	END
END
GO 
--FALTA APLICARLO A TODAS LAS FACTURAS Y TODOS LOS PRODUCTOS

/*7. Hacer un procedimiento que dadas dos fechas complete la tabla Ventas. Debe
insertar una línea por cada artículo con los movimientos de stock realizados entre
esas fechas. La tabla se encuentra creada y vacía.
VENTAS 
| Código  | Detalle | Cant. Mov. | Precio de Venta | Renglón  | Ganancia |
  Código    Detalle  (suma Item	   Precio promedio   Nro Linea  Cantidad*
  del       del       facturas)			             de la      Costo 
  articulo  articulo								 tabla      Actual
*/
if OBJECT_ID('Ventas','U') IS NOT NULL 
DROP TABLE Ventas
GO
Create table Ventas
(
vent_codigo char(8) NULL,
vent_detalle char(50) NULL,
vent_cant_mov int NULL,
vent_precio decimal(12,2) NULL,
vent_renglon int PRIMARY KEY,
vent_ganancia decimal (12,2) NULL
)
if OBJECT_ID('llenar_ventas','P') is not null
DROP PROCEDURE llenar_ventas
GO

CREATE PROCEDURE llenar_ventas
(@A date,@B date)
AS 
BEGIN
	if @A>@B
	BEGIN
		DECLARE @aux datetime
		set @aux = @A
		set @A = @B
		set @B = @aux
	END
	BEGIN
		DECLARE @Codigo char(8), @Detalle char(50), @Cant_Mov int, @Precio_de_venta decimal(12,2), @Renglon int, @Ganancia decimal(12,2)
		DECLARE cursor_articulos CURSOR LOCAL FAST_FORWARD   
		FOR SELECT prod_codigo, prod_detalle, SUM(item_cantidad), AVG(item_precio), SUM(item_cantidad*item_precio)
			FROM Producto LEFT JOIN 
								(Item_Factura JOIN Factura ON fact_sucursal=item_sucursal AND fact_tipo=item_tipo AND fact_numero=item_numero)
								ON item_producto=prod_codigo
			WHERE fact_fecha between @A and @B
			GROUP BY prod_codigo,prod_detalle
		OPEN cursor_articulos
		set @Renglon=0
		-- Perform the first fetch.
		FETCH NEXT FROM cursor_articulos
		INTO @Codigo, @Detalle, @Cant_Mov, @Precio_de_venta, @Ganancia
		-- Check @@FETCH_STATUS to see if there are any more rows to fetch.
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- This is executed as long as the previous fetch succeeds.
			set @Renglon=@Renglon+1
			INSERT INTO Ventas VALUES (@Codigo, @Detalle, @Cant_Mov, @Precio_de_venta, @Renglon, @Ganancia)
			FETCH NEXT FROM cursor_articulos
			INTO @Codigo, @Detalle, @Cant_Mov, @Precio_de_venta, @Ganancia
		END
		CLOSE cursor_articulos
		DEALLOCATE cursor_articulos
		
	END
END
GO
/*8. Realizar un procedimiento que complete la tabla Diferencias de precios, para los
productos facturados que tengan composición y en los cuales el precio de
facturación sea diferente al precio del cálculo de los precios unitarios por cantidad
de sus componentes, se aclara que un producto que compone a otro, también puede
estar compuesto por otros y así sucesivamente, la tabla se debe crear y está formada
por las siguientes columnas:
DIFERENCIAS
Código Detalle Cantidad Precio_generado Precio_facturado
(prod) (prod)   (comp)
*/
GO
IF EXISTS (SELECT name FROM sysobjects WHERE name='precio_compuesto'  AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION precio_compuesto 
GO

CREATE FUNCTION precio_compuesto (@Producto char(8))
RETURNS decimal(12,2)
AS
BEGIN
	DECLARE @Precio decimal(12,2)
		SELECT @Precio=SUM(comp_cantidad * dbo.precio_compuesto(comp_componente))
		FROM Composicion
		WHERE comp_producto=@Producto
	--si el select falló es porque no hay composicion, en cuyo caso se devuelve el precio original
	if @Precio is null
	set @Precio = (SELECT prod_precio FROM Producto WHERE prod_codigo=@Producto)
	RETURN @Precio
END

GO
IF EXISTS (SELECT name FROM sysobjects WHERE name='Diferencias' AND type='U')
DROP TABLE Diferencias 
GO
CREATE TABLE Diferencias (
							Codigo char(8) PRIMARY KEY,
							Detalle char(50),
							Cantidad int,
							Precio_generado decimal(12,2),
							Precio_facturado decimal(12,2)
						)
INSERT INTO Diferencias SELECT prod_codigo, prod_detalle, count(*), dbo.precio_compuesto(prod_codigo), prod_precio
FROM Producto JOIN Composicion ON prod_codigo=comp_producto
GROUP BY prod_codigo, prod_detalle, prod_precio

SELECT * FROM Diferencias

/*9. Hacer un trigger que ante alguna modificación de un ítem de factura de un artículo
con composición realice el movimiento de sus correspondientes componentes.
*/
/*
NO LO PUEDO RESOLVER
EL MOVIMIENTO DE SUS COMPONENTES LO INTERPRETO COMO QUE SI UN ITEM SE BORRA
O SU CANTIDAD SE ALTERA TENGO QUE ACTUALIZAR EL STOCK DE SUS COMPONENTES,
PERO EL MISMO DEPENDE DEL DEPOSITO, QUE NO TENGO FORMA (HASTA DONDE SE) DE CONOCER

*/

IF EXISTS (SELECT name FROM sysobjects WHERE name='trigger_mod_item')
DROP TRIGGER trigger_mod_item
GO

CREATE TRIGGER trigger_mod_item ON ITEM_FACTURA AFTER INSERT, UPDATE, DELETE
AS
BEGIN

	DECLARE @i_tipo char(1)	
	DECLARE @i_sucursal char(4)
	DECLARE	@i_numero char(8)
	DECLARE @i_producto char(8)
	DECLARE @i_cantidad decimal(12,2)
	DECLARE @i_precio decimal(12,2)
	DECLARE @d_tipo char(1)
	DECLARE @d_sucursal char(4)
	DECLARE	@d_numero char(8)
	DECLARE @d_producto char(8)
	DECLARE @d_cantidad decimal(12,2)
	DECLARE @d_precio decimal(12,2)
	DECLARE @componente char(8)

	DECLARE @diferencia int
	DECLARE @cantidad int




	DECLARE MODIFICACION CURSOR for
	select 
	i.item_tipo, i.item_sucursal,i.item_numero,i.item_producto,i.item_cantidad,i.item_precio,
	d.item_tipo, d.item_sucursal,d.item_numero,d.item_producto,d.item_cantidad,d.item_precio,
	ISNULL(i.item_cantidad,0) - ISNULL(d.item_cantidad,0) diferencia, comp_componente
	from INSERTED i FULL OUTER JOIN DELETED d on 
		d.item_tipo = i.item_tipo
	and d.item_sucursal = i.item_sucursal
	and d.item_numero = i.item_numero
	and d.item_producto = i.item_producto
	JOIN Composicion c on c.comp_producto = ISNULL(i.item_producto,d.item_producto)

	open MODIFICACION
	
	FETCH NEXT FROM MODIFICACION INTO @i_tipo,@i_sucursal,@i_numero,@i_producto,@i_cantidad,@i_precio,
	@d_tipo,@d_sucursal,@d_numero,@d_producto,@d_cantidad,@d_precio,@diferencia, @componente

	DECLARE @cant int = @diferencia

	WHILE @@FETCH_STATUS=0
		BEGIN
			--SI ES UPDATE, QUE CREO QUE ES LO QUE PIDE EL EJERCICIO
			if (@i_producto is not null and @d_producto is not null)
			BEGIN
				
				--hay que agregar
				IF (@diferencia > 0)
				BEGIN
					--veo si hay stock					
					select @cantidad = SUM(STOC_CANTIDAD) from STOCK where stoc_producto = @componente

					if (@diferencia > @cantidad) -- no hay stock
					BEGIN

						rollback transaction
						RAISERROR('No hay suficiente stock',16,1)

					END

					else --hay stock
					BEGIN
						WHILE @diferencia != 0
						BEGIN --lo resto del deposito donde haya mas stock primero
							
							
							select @cant = @diferencia - 
							(CASE WHEN (select top 1 stoc_cantidad from STOCK where stoc_producto = @componente order by stoc_cantidad desc) > @diferencia 
							THEN @diferencia
							else (select top 1 stoc_cantidad from STOCK where stoc_producto = @componente order by stoc_cantidad desc) END)
							
							UPDATE STOCK set stoc_cantidad = stoc_cantidad - (@diferencia - @cant)
							where stoc_deposito = (select top 1 stoc_deposito from stock where stoc_producto = @componente order by stoc_cantidad desc)

							select @diferencia = @cant

						END

					END
				END


				--hay que devolver al stock
				ELSE IF (@diferencia < 0)
				BEGIN
					--busco la disponibilidad y si entra lo que tengo que devolver a los depositos
					select @cantidad = SUM(STOC_STOCK_MAXIMO) - SUM(STOC_CANTIDAD)
					from stock where stoc_producto = @componente
					
					IF (@cantidad < ABS(@diferencia)) --no alcanza el espacio disponible
					BEGIN
						rollback transaction
						RAISERROR('Los depositos estan llenos',16,1)
					END
					ELSE --hay espacio disponible
					BEGIN
						WHILE @diferencia != 0
						BEGIN --se lo sumo al deposito donde haya mas espacio primero
							select @cant = @diferencia +
							(CASE WHEN (select top 1 stoc_stock_maximo - stoc_cantidad from STOCK where stoc_producto = @componente order by 1 desc) > ABS(@diferencia)
							THEN ABS(@diferencia) 
							else (select top 1 stoc_stock_maximo - stoc_cantidad from STOCK where stoc_producto = @componente order by 1 desc) END)

							UPDATE STOCK set stoc_cantidad = stoc_cantidad - (@diferencia - @cant)
							where stoc_deposito = (select top 1 stoc_deposito from stock where stoc_producto = @componente order by (stoc_stock_maximo - stoc_cantidad) desc)


						END
					END

				END

			END
			else if (@i_producto is null and @d_producto is not null) --hay que reponer al stock
			BEGIN

			--busco la disponibilidad y si entra lo que tengo que devolver a los depositos
				select @cantidad = SUM(STOC_STOCK_MAXIMO) - SUM(STOC_CANTIDAD)
				from stock where stoc_producto = @componente
					
				IF (@cantidad < ABS(@diferencia)) --no alcanza el espacio disponible
				BEGIN
					rollback transaction
					RAISERROR('Los depositos estan llenos',16,1)
				END
				ELSE --hay espacio disponible
				BEGIN
					WHILE @diferencia != 0
					BEGIN --se lo sumo al deposito donde haya mas espacio primero
						select @cant = @diferencia +
						(CASE WHEN (select top 1 stoc_stock_maximo - stoc_cantidad from STOCK where stoc_producto = @componente order by 1 desc) > ABS(@diferencia)
						THEN ABS(@diferencia) 
						else (select top 1 stoc_stock_maximo - stoc_cantidad from STOCK where stoc_producto = @componente order by 1 desc) END)

						UPDATE STOCK set stoc_cantidad = stoc_cantidad - (@diferencia - @cant)
						where stoc_deposito = (select top 1 stoc_deposito from stock where stoc_producto = @componente order by (stoc_stock_maximo - stoc_cantidad) desc)


					END
				END




			END

			else if (@i_producto is not null and @d_producto is null) --hay que sacar del stock
			BEGIN

				select @cantidad = SUM(STOC_CANTIDAD) from STOCK where stoc_producto = @componente

				if (@diferencia > @cantidad) -- no hay stock
				BEGIN

					rollback transaction
					RAISERROR('No hay suficiente stock',16,1)

				END

				else --hay stock
				BEGIN
					WHILE @diferencia != 0
					BEGIN --lo resto del deposito donde haya mas stock primero
							
							
						select @cant = @diferencia - 
						(CASE WHEN (select top 1 stoc_cantidad from STOCK where stoc_producto = @componente order by stoc_cantidad desc) > @diferencia
						THEN @diferencia
						else (select top 1 stoc_cantidad from STOCK where stoc_producto = @componente order by stoc_cantidad desc) END)
							
						UPDATE STOCK set stoc_cantidad = stoc_cantidad - (@diferencia - @cant)
						where stoc_deposito = (select top 1 stoc_deposito from stock where stoc_producto = @componente order by stoc_cantidad desc)
				
						select @diferencia = @cant

					END

				END

			END

		
		END

END
GO

/*
10. Hacer un trigger que ante el intento de borrar un artículo verifique que no exista
stock y si es así lo borre en caso contrario que emita un mensaje de error.
*/
IF EXISTS (SELECT name FROM sysobjects WHERE name='trigger_borrar_compuesto')
DROP TRIGGER trigger_borrar_compuesto
GO
CREATE TRIGGER trigger_borrar_compuesto ON Producto INSTEAD OF DELETE
AS
BEGIN
	DECLARE borrados CURSOR FOR
	SELECT prod_codigo
	FROM deleted

	DECLARE @borrado char(8)
	
	OPEN borrados
	FETCH NEXT FROM borrados into @borrado
	WHILE @@FETCH_STATUS=0
	BEGIN
	--si hay stock positivo
		IF isnull((SELECT SUM(isnull (stoc_cantidad,0)) 
				   FROM STOCK 
				   WHERE stoc_producto in (SELECT prod_codigo FROM deleted))
				  ,0) <= 0
			DELETE FROM Producto WHERE prod_codigo=@borrado
		ELSE
			RAISERROR('Error al intentar borrar producto %s, aun hay stock del producto.',1,1,@borrado)
		FETCH NEXT FROM borrados into @borrado
	END
	DEALLOCATE borrados
	
END
GO
--PRUEBA QUE FUNCAA
--DELETE FROM Producto WHERE prod_codigo = '00000000' 
--SELECT * FROM Producto WHERE prod_codigo = '00000000'
/*
11. Cree el/los objetos de base de datos necesarios para que dado un código de
empleado se retorne la cantidad de empleados que este tiene a su cargo (directa o
indirectamente). Solo contar aquellos empleados (directos o indirectos) que sean
menores que su jefe directo.
*/
GO
IF EXISTS (SELECT name FROM sysobjects WHERE name='empleados_menores_a_cargo' and type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION empleados_menores_a_cargo
GO

GO
CREATE FUNCTION empleados_menores_a_cargo
(@Jefe numeric(6))
returns int
AS
BEGIN
	DECLARE @cant int
	DECLARE @jefe_nacimiento smalldatetime
	SELECT @jefe_nacimiento=empl_nacimiento FROM Empleado WHERE empl_codigo=@Jefe
	--sumamos los empleados a cargo del man con sus empleados a cargo
	SELECT @cant = isnull(sum(dbo.empleados_menores_a_cargo(empl_codigo)+1),0) FROM Empleado WHERE empl_jefe=@Jefe AND empl_nacimiento>@jefe_nacimiento
	RETURN @cant
END
GO--FUNCA BIEN PILLO
--SELECT dbo.empleados_menores_a_cargo

/*12. Cree el/los objetos de base de datos necesarios para implantar la siguiente regla
“Ningún jefe puede tener a su cargo más de 50 empleados en total (directos +
indirectos)”. Se sabe que en la actualidad dicha regla se cumple y que la base de
datos es accedida por n aplicaciones de diferentes tipos y tecnologías.
*/
IF EXISTS (SELECT name FROM sysobjects WHERE name='empleados_a_cargo' and type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION empleados_a_cargo
GO

GO
CREATE FUNCTION empleados_a_cargo
(@Jefe numeric(6))
returns int
AS
BEGIN
	DECLARE @cant int
	--sumamos los empleados a cargo del man con sus empleados a cargo
	SELECT @cant = isnull(sum(dbo.empleados_a_cargo(empl_codigo)+1),0) FROM Empleado WHERE empl_jefe=@Jefe
	RETURN @cant
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name='jefe_mayor' and type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION jefe_mayor
GO
CREATE FUNCTION jefe_mayor
(@empleado numeric(6))
returns numeric(6)
AS
BEGIN
	DECLARE @jefe numeric(6)
	SELECT @jefe = (case when empl_jefe is null then @empleado else dbo.jefe_mayor(empl_jefe) end) FROM Empleado WHERE empl_codigo=@empleado
	RETURN @jefe
END
GO

IF EXISTS(SELECT name FROM sysobjects WHERE name='trigger_50_empleados')
DROP TRIGGER trigger_50_empleados
GO

CREATE TRIGGER trigger_50_empleados ON Empleado FOR UPDATE, INSERT
AS
BEGIN
--agarramos los jefes "supremos"(sin jefe) de los empleados modificados y si el que tiene mas empleados tiene mas de 50 rompe
	if (SELECT MAX(dbo.empleados_a_cargo(dbo.jefe_mayor(empl_codigo))) FROM inserted)>50
	BEGIN
		RAISERROR('DALE GILAZO NO PUEDE HABER MAS DE 50 EMPLEADOS POR JEFE',1,1)
		ROLLBACK TRANSACTION
		RETURN
	END
END
GO

--INSERT INTO Empleado (empl_codigo, empl_jefe) values (19, 1),(87, 2)


--SELECT dbo.empleados_a_cargo(1)

/*13. Cree el/los objetos de base de datos necesarios para que nunca un producto pueda
ser compuesto por sí mismo. Se sabe que en la actualidad dicha regla se cumple y
que la base de datos es accedida por n aplicaciones de diferentes tipos y tecnologías.
No se conoce la cantidad de niveles de composición existentes.
*/
/*
ACLARACIÓN: SI EXISTÍA UNA FORMA SENCILLA DE RESOLVER ESTE PUNTO, MURIÓ EN EL CAMINO

BUENO EN ESENCIA ESTE PUNTO CONSISTE EN RECORRER UN GRAFO DIRIGIDO CON
LA TABLA COMPOSICION COMO TABLA DE ARISTAS Y LOS PRODUCTOS COMO NODOS
DONDE HAY QUE EVITAR TODO POSIBLE BUCLE, PARA ESO HAY QUE TENER EN CUENTA LO SIGUIENTE
-UN PRODUCTO 'A' COMPONE A OTRO 'B' SI HAY UN "CAMINO" ENTRE LAS RELACIONES DE COMPOSICION QUE VA DE 'A' A 'B'
-CON LOGRAR LLEGAR DESDE UN PRODUCTO A SI MISMO RECORRIENDO EL GRAFO ALCANZA PARA DEMOSTRAR QUE SE COMPONE POR SI MISMO
-DEMOSTRAR QUE EL COMPUESTO DE LA COMPOSICION QUE SE QUIERE INSERTAR SE COMPONE POR SI MISMO ES NECESARIO Y SUFICIENTE PARA DEMOSTRAR QUE LA
COMPOSICION AGREGADA CAGA TODO (LO QUE IMPLICA QUE SI NO HAY BUCLE EN NINGUN COMPUESTO DE LA INSERCION FUNCA TODO)
-EL PROGRAMA TIENE QUE EVITAR RECORRER BUCLES ETERNAMENTE (por ejemplo, supongamos que queremos ver si un producto A
se compone por sí mismo, pero en su recorrido pasa por un bucle ida y vuelta entre B y C del cual A no forma parte,
esto quiere decir que si bien se encontraron dos productos que se componen por sí mismos (B y C), A no es uno de ellos,
y por lo tanto no le interesa al programa, que va a seguir recorriendo el bucle sin parar), ESTO SE LOGRA LLEVANDO CUENTA DE LOS NODOS YA VISITADOS
*/

--declaro un tipo de tabla para poder pasarlo por parametro, va a llevar cuenta de los nodos visitados
GO
--descomentar en primera ejecucion y comentarlo luego
--CREATE TYPE tipo_tabla_componentes AS TABLE (codigo char(8))
GO

--esta funcion se va a encargar de recorrer el grafo desde un nodo dado
IF EXISTS( SELECT name FROM sysobjects WHERE name='get_componentes' AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION get_componentes
GO
CREATE FUNCTION get_componentes (@Nodo char(8),@ya_visitados tipo_tabla_componentes READONLY)
RETURNS @visitados_ret TABLE (nombre char(8))
AS
BEGIN
--ESTO ES PORQUE LOS PARAMETROS TABLA SI O SI SON READONLY
	DECLARE @visitados tipo_tabla_componentes
	INSERT INTO @visitados
	SELECT * FROM @ya_visitados
	
	
	DECLARE @adyacentes_sin_visitar tipo_tabla_componentes
	INSERT INTO @adyacentes_sin_visitar
	SELECT comp_componente FROM Composicion
	WHERE comp_producto=@Nodo AND comp_componente not in (SELECT * FROM @visitados)
	
	INSERT INTO @visitados
	SELECT * FROM @adyacentes_sin_visitar

	--STATIC para que en sus filas no aparezcan las inserciones que se van a realizar en la tabla
	DECLARE cursor_adyacentes_sin_visitar CURSOR STATIC FOR
	SELECT * FROM @adyacentes_sin_visitar
	DECLARE @adyacente char(8)

	OPEN cursor_adyacentes_sin_visitar
	FETCH NEXT FROM cursor_adyacentes_sin_visitar into @adyacente
	WHILE @@FETCH_STATUS=0
	BEGIN
		INSERT INTO @visitados
		SELECT * FROM get_componentes(@adyacente,@visitados)

		FETCH NEXT FROM cursor_adyacentes_sin_visitar into @adyacente
	END
	INSERT INTO @visitados_ret
	SELECT * FROM @visitados
	RETURN
END
GO

IF EXISTS( SELECT name FROM sysobjects WHERE name='trigger_composicion_objetos')
DROP TRIGGER trigger_composicion_objetos
GO
CREATE TRIGGER trigger_composicion_objetos ON  Composicion FOR UPDATE, INSERT
AS
BEGIN
	--declaramos una tabla vacia para pasarle al get_componentes
	DECLARE @visitados tipo_tabla_componentes
	--SI EXISTE UN PRODUCTO COMPUESTO POR SI MISMO
	IF EXISTS(SELECT * FROM inserted WHERE comp_producto in (SELECT * FROM get_componentes(comp_producto,@visitados)))
	BEGIN
		RAISERROR('SI UN PRODUCTO SE COMPONE POR SI MISMO EXPLOTA EL MUNDO PAPU',1,1)
		ROLLBACK TRANSACTION
	END
END
GO
--codigo de prueba
BEGIN	
	DECLARE @A char(8), @B char(8), @C char(8)
	SELECT TOP 1 @A=prod_codigo FROM Producto
	SELECT TOP 1 @B=prod_codigo FROM Producto WHERE prod_codigo not in (@A)
	SELECT TOP 1 @C=prod_codigo FROM Producto WHERE prod_codigo not in (@A, @B)
	
	-- bucle de 1 nodo (reflexividad) SALTA EL TRIGGER
	--INSERT INTO Composicion values (1,@A,@A)

	-- bucle de 2 nodos (simetría) SALTA EL TRIGGER
	--SELECT TOP 1 @producto=comp_componente, @componente=comp_producto FROM Composicion
	--INSERT INTO Composicion values (1,@A,@B),(1,@B,@A)

	-- bucle de 3 nodos (composicion indirecta) SALTA EL TRIGGER
	--INSERT INTO Composicion values (1,@A,@B),(1,@B,@C),(1,@C,@A)

	--prueba que no deberia tirar trigger NO HAY TRIGGER CARAJO
	--INSERT INTO Composicion values (1,@A,@B)
	--DELETE FROM Composicion WHERE comp_producto=@A AND comp_componente=@B
	
END
GO
/*14. Cree el/los objetos de base de datos necesarios para implantar la siguiente regla
“Ningún jefe puede tener un salario mayor al 20% de las suma de los salarios de sus
empleados totales (directos + indirectos)”. Se sabe que en la actualidad dicha regla
se cumple y que la base de datos es accedida por n aplicaciones de diferentes tipos y
tecnologías*/

/*
aclaro que actuo ignorando funciones hechas con anterioridad

Primero que nada, esta regla se puede ver afectada cuando se insertan empleados o se modifican
sus sueldos, pero tambien puede ocurrir cuando se borran empleados, ya que la suma de los sueldos cambia

Nuevamente si vemos la red de empleado/jefe como un grafo dirigido, lo que hay que evitar es que,
al recorrer todos los nodos desde un supuesto jefe, no haya camino que salga de su nodo (no es jefe de nadie)
o el sueldo de este no sea mayor que el 20% la suma de sueldos de dichos nodos

los casos que se pueden dar son:
-aumenta el sueldo de un jefe:
	-un jefe aumenta su sueldo, superando su limite, rompiendo la regla
-disminuye el limite de un jefe:
	-un empleado reduce su sueldo, disminuyendo el límite de su jefe, rompiendo la regla
	-se reducen los empleados a cargo de un jefe, lo que reduce su limite, rompiendo la regla
-un empleado se vuelve jefe de alguien, lo que le da un limite que se supera de entrada, rompiendo la regla

Una forma seria:
Para los empleados insertados, se observa si cumplen la regla él y sus jefes (los jefes porque por ahí antes no tenían empleados).
Para los empleados borrados, se observa si cumplen la regla sus jefes, cuyos límites se redujeron.

La otra seria fijarse si todos los jefes cumplen y se van todos a lA CON- (aca puse esa porque me dio fiaca)
*/
IF EXISTS (SELECT name FROM sysobjects WHERE name='get_empleados' and type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION get_empleados 
GO
CREATE FUNCTION get_empleados (@jefe numeric(6,0))
RETURNS @EMPLEADOS TABLE (empleado numeric (6,0))
AS--SE PRESUPONE QUE NO PUEDE HABER RECURSIVIDAD (nadie es simultaneamente jefe y empleado de otro)
BEGIN
	DECLARE cursor_empleados CURSOR FOR
	SELECT empl_codigo FROM Empleado WHERE empl_jefe=@jefe
	DECLARE @codigo numeric(6,0)
	OPEN cursor_empleados
	FETCH NEXT FROM cursor_empleados INTO @codigo
	WHILE @@FETCH_STATUS = 0
	--para cada empleado directo
	BEGIN
		--se inserta al empleado directo
		INSERT INTO @EMPLEADOS VALUES (@codigo)
		--se insertan los empleados indirectos a cargo de dicho empleado directo
		INSERT INTO @EMPLEADOS
		SELECT * FROM get_empleados(@codigo)
		
		FETCH NEXT FROM cursor_empleados INTO @codigo
	END
	RETURN
END
GO


--la hice al pedo esta, aunque a partir de una funcion get_empleados se puede hacer get_jefes y viceversa, mepa que
--get_jefes es mas performante
IF EXISTS (SELECT name FROM sysobjects WHERE name='get_jefes' and type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION get_jefes
GO
CREATE FUNCTION get_jefes (@empleado numeric(6,0))
RETURNS @JEFES TABLE (jefe numeric (6,0))
AS--SE PRESUPONE QUE NO PUEDE HABER RECURSIVIDAD (nadie es simultaneamente jefe y empleado de otro)
BEGIN
	DECLARE @Jefe numeric (6,0)
	SELECT @Jefe=empl_jefe FROM Empleado WHERE empl_codigo=@empleado
	
	
	--se inserta al empleado directo
	INSERT INTO @JEFES VALUES (@Jefe)
	--se insertan los empleados indirectos a cargo de dicho empleado directo
	INSERT INTO @JEFES
	SELECT * FROM get_jefes(@Jefe)
		
	RETURN
END
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name='trigger_jefe_sueldo_sarpado')
DROP TRIGGER trigger_jefe_sueldo_sarpado
GO
CREATE TRIGGER trigger_jefe_sueldo_sarpado ON Empleado FOR UPDATE, DELETE, INSERT
AS
BEGIN
	IF EXISTS(
	SELECT * 
	FROM Empleado jefe
	WHERE
		--tiene empleados...
		EXISTS(SELECT * FROM dbo.get_empleados(empl_codigo))
		--... y rompe la regla
		AND empl_salario > 0.20*(
			SELECT SUM(empleado.empl_salario)
			FROM Empleado empleado
			WHERE empleado.empl_codigo IN (SELECT * FROM dbo.get_empleados(jefe.empl_codigo))
			)
	)
	BEGIN
		RAISERROR('man no te quiero decir nada pero hay un jefe que gana UNA BANDA',1,1)
		ROLLBACK TRANSACTION
		
	END
END
go