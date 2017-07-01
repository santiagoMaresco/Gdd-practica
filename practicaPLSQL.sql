use GD2015C1

  /*******************************************************/
 /*                         SQL                         */
/*******************************************************/

/*
1. Mostrar el código, razón social de todos los clientes cuyo límite de crédito sea
mayor o igual a $ 1000 ordenado por código de cliente.
*/

SELECT clie_codigo, clie_razon_social
FROM Cliente
WHERE clie_limite_credito >= 1000
ORDER BY clie_codigo ASC

/*
2. Mostrar el código, detalle de todos los artículos vendidos en el año 2012 ordenados
por cantidad vendida.
*/

SELECT prod_codigo, prod_detalle
FROM Producto p
	JOIN Item_Factura i 
		ON p.prod_codigo=i.item_producto
	JOIN Factura f 
		ON f.fact_tipo = i.item_tipo
	   AND f.fact_sucursal = i.item_sucursal
	   AND f.fact_numero = i.item_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle
ORDER BY SUM(i.item_cantidad); -- ¿porque el sum? ya entendi, el grup by me funciona como un select distinct ordenandome todo los grupos de productos iguales, este sum me junta todo y me trae 1 solo de cada grupo

/*
3. Realizar una consulta que muestre código de producto, nombre de producto y el
stock total, sin importar en que deposito se encuentre, los datos deben ser ordenados
por nombre del artículo de menor a mayor.
*/
SELECT prod_codigo, prod_detalle, SUM(stoc_cantidad) -- por lo que veo este sum me suma todos los stoc_cantidad repetidos por prod_codigo que figuren STOCK
FROM Producto 
	JOIN STOCK 
		ON prod_codigo = stoc_producto
GROUP BY prod_codigo, prod_detalle
ORDER BY prod_detalle ASC;

/*
4. Realizar una consulta que muestre para todos los artículos código, detalle y cantidad
de artículos que lo componen. Mostrar solo aquellos artículos para los cuales el
stock promedio por depósito sea mayor a 100.
*/

SELECT prod_codigo, prod_detalle, SUM(comp_cantidad) prod_componentes
FROM Producto p
	LEFT JOIN Composicion c
		ON p.prod_codigo=c.comp_producto
	JOIN STOCK s
		ON p.prod_codigo=s.stoc_producto
GROUP BY prod_codigo, prod_detalle
HAVING AVG(s.stoc_cantidad) > 100.00

-- otra forma mejor
SELECT prod_codigo, prod_detalle, 
		isnull(
			(SELECT SUM(comp_cantidad)
				FROM Composicion
				WHERE comp_producto = prod_codigo), 
			0) prod_componentes
FROM Producto
	LEFT JOIN STOCK s -- este left esta medio al pedo... porque en fin me interesan los que coiniciden
		ON prod_codigo = stoc_producto
GROUP BY prod_codigo, prod_detalle
HAVING AVG(isnull(stoc_cantidad,0)) > 100

/*
5. Realizar una consulta que muestre código de artículo, detalle y cantidad de egresos
de stock que se realizaron para ese artículo en el año 2012 (egresan los productos
que fueron vendidos). Mostrar solo aquellos que hayan tenido más egresos que en el
2011.
*/

SELECT p.prod_codigo, p.prod_detalle, SUM(i1.item_cantidad) as egresos
FROM Producto p
	JOIN Item_Factura i1 
		ON p.prod_codigo = i1.item_producto
	JOIN Factura f1
		ON f1.fact_tipo = i1.item_tipo
	   AND f1.fact_sucursal = i1.item_sucursal
	   AND f1.fact_numero = i1.item_numero
WHERE YEAR(f1.fact_fecha) = 2012
GROUP BY p.prod_codigo, p.prod_detalle
HAVING SUM(i1.item_cantidad) > (
	SELECT SUM(i2.item_cantidad)
	FROM Item_Factura i2
		JOIN Factura f2 
			ON f2.fact_tipo = i2.item_tipo
		   AND f2.fact_sucursal = i2.item_sucursal
		   AND f2.fact_numero = i2.item_numero
	WHERE YEAR(fact_fecha) = 2011
		AND item_producto=p.prod_codigo 
	)

/*
6. Mostrar para todos los rubros de artículos código, detalle, cantidad de artículos de
ese rubro y stock total de ese rubro de artículos. Solo tener en cuenta aquellos
artículos que tengan un stock mayor al del artículo ‘00000000’ en el depósito ‘00’.
*/


select rubr_id, rubr_detalle, count(DISTINCT prod_codigo) cant_articulos, sum(stoc_cantidad) stock_total
from Rubro 
	LEFT JOIN Producto -- tenes que usar left join porque te pide TODOS los rubros
		on prod_rubro = rubr_id
	LEFT JOIN STOCK 
		on stoc_producto = prod_codigo
group by rubr_id, rubr_detalle
having sum(stoc_cantidad) > (
	select SUM(stoc_cantidad)
	from STOCK 
		JOIN Producto 
			on prod_codigo = stoc_producto
	where stoc_deposito = '00' and prod_codigo = '00000000'  
)

/*
7. Generar una consulta que muestre para cada articulo código, detalle, mayor precio
menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio
= 10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que
posean stock.
*/

SELECT									  
	prod_codigo, 
	prod_detalle,
	MAX(prod_precio) precio_maximo, 
	MIN(prod_precio) precio_minimo,
	case when MIN(prod_precio)=0 then 0 else(MAX(prod_precio)/ MIN(prod_precio)-1)*100 end diferencia_porcentual
FROM Producto 
	JOIN STOCK 
		ON prod_codigo = stoc_producto
GROUP BY prod_codigo, prod_detalle
HAVING SUM(ISNULL(stoc_cantidad,0))>0

/*
8. Mostrar para el o los artículos que tengan stock en todos los depósitos, nombre del
artículo, stock del depósito que más stock tiene.
*/

select prod_detalle, MAX(stoc_cantidad)
from Producto
left join STOCK on prod_codigo = stoc_producto
WHERE isnull(stoc_cantidad,0) >0
group by  prod_detalle

/*
9. Mostrar el código del jefe, código del empleado que lo tiene como jefe, nombre del
mismo y la cantidad de depósitos que ambos tienen asignados.
*/

SELECT 
	j.empl_codigo jefe, 
	(SELECT COUNT(depo_codigo) FROM DEPOSITO WHERE depo_encargado = j.empl_codigo) depos_jefe,
	e.empl_codigo empleado, 
	e.empl_nombre nombre_empleado,
	(SELECT COUNT(depo_codigo) FROM DEPOSITO WHERE depo_encargado = e.empl_codigo) depos_empleado
FROM Empleado e 
	JOIN Empleado j 
		ON e.empl_jefe = j.empl_codigo -- este join solo me descarta que no hayan jefes null por ejemplo...

/*
10. Mostrar los 10 productos mas vendidos en la historia y también los 10 productos
menos vendidos en la historia. Además mostrar de esos productos, quien fue el
cliente que mayor compra realizo.
*/


select prod_codigo, prod_detalle, (
select top 1 clie_codigo
FROM Item_Factura 
join Factura on item_tipo = fact_tipo AND
				item_sucursal = fact_sucursal AND
				item_numero = fact_numero
join Cliente on fact_cliente = clie_codigo
where item_producto = prod_codigo
group by clie_codigo
order by SUM(item_cantidad) DESC
)
from Producto
WHERE prod_codigo IN (SELECT TOP 10 p.prod_codigo FROM Producto p
				join Item_Factura itf on prod_codigo = itf.item_producto
				group by p.prod_codigo
				order by SUM(itf.item_cantidad) DESC)
				OR prod_codigo IN (SELECT TOP 10 p.prod_codigo FROM Producto p
				join Item_Factura itf on prod_codigo = itf.item_producto
				group by p.prod_codigo
				order by SUM(itf.item_cantidad) ASC)

/*
11. Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de
productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán
ordenar de mayor a menor, por la familia que más productos diferentes vendidos
tenga, solo se deberán mostrar las familias que tengan una venta superior a 20000
pesos para el año 2012.
*/

select fami_detalle ,count(item_producto) as prodVendidos, 
		sum(itf.item_precio*itf.item_cantidad) as montoVentas
from Familia
left join Producto on prod_familia = fami_id
join Item_Factura itf on prod_codigo = itf.item_producto
join Factura on fact_tipo = item_tipo AND fact_sucursal = item_sucursal AND
		fact_numero = item_numero
group by fami_id, fami_detalle
having 20000 < (select top 1 sum(itf.item_cantidad*itf.item_precio)
		FROM Item_Factura
		join Factura on fact_tipo = item_tipo AND fact_sucursal = item_sucursal AND
		fact_numero = item_numero AND YEAR(fact_fecha) = 2012
		)
order by prodVendidos DESC


/*
12. Mostrar nombre de producto, cantidad de clientes distintos que lo compraron,
importe promedio pagado por el producto, cantidad de depósitos en lo cuales hay
stock del producto y stock actual del producto en todos los depósitos. Se deberán
mostrar aquellos productos que hayan tenido operaciones en el año 2012 y los datos
deberán ordenarse de mayor a menor por monto vendido del producto.
*/

select prod_detalle,

(select count(clie_codigo)
	from Cliente
		join Factura on clie_codigo = fact_cliente
		join Item_Factura on fact_tipo = item_tipo AND
					fact_sucursal = item_sucursal AND
					fact_numero = item_numero AND
					item_producto = prod_codigo
) as cli_distintos,

(sum(itf.item_precio)/sum(itf.item_cantidad)
)as importeProm,

(select count(depo_codigo)
from DEPOSITO
join STOCK on depo_codigo = stoc_deposito
where stoc_producto = prod_codigo
) as cantDepositos,

(select sum(stoc_cantidad)
from STOCK 
where stoc_producto = prod_codigo
) as stockTotalProd

from Producto
	join Item_Factura itf on prod_codigo = itf.item_producto
	join Factura f on itf.item_tipo = f.fact_tipo AND
				itf.item_sucursal = f.fact_sucursal AND
				itf.item_numero = f.fact_numero
	where YEAR(f.fact_fecha) = 2012

group by prod_codigo, prod_detalle

order by sum(itf.item_cantidad*itf.item_precio) DESC


--FORMA RUBEN

SELECT 
--nombre
	p.prod_detalle
	AS producto,
--cantidad clientes distintos que lo compraron
	(SELECT COUNT(DISTINCT f1.fact_cliente)
	 FROM Factura f1 JOIN Item_Factura i1 ON i1.item_numero=f1.fact_numero AND i1.item_sucursal=f1.fact_sucursal AND i1.item_tipo=f1.fact_tipo
	 WHERE i1.item_producto=p.prod_codigo)
	AS compradores,
--importe promedio del producto (interpreto suma de precio*cantidad en cada factura dividido la cantidad vendida en todas las facturas)
	(SELECT SUM(i1.item_precio*i1.item_cantidad)/SUM(i1.item_cantidad)
	 FROM Item_Factura i1 WHERE i1.item_producto=p.prod_codigo)
	AS importe_promedio,
--cantidad depositos con stock
	(SELECT COUNT(s1.stoc_deposito)
	 FROM STOCK s1
	 WHERE s1.stoc_producto=p.prod_codigo AND ISNULL(s1.stoc_cantidad,0)>0)
	AS Depositos_con_stock,
--stock en todos los depositos (interpreto sumatoria de todos los depositos)
	isnull((SELECT SUM(isnull(s1.stoc_cantidad,0))
			FROM STOCK s1 WHERE s1.stoc_producto=p.prod_codigo)
			,0)
	AS stock_total
--operaciones se interpreta como ventas
FROM Producto p JOIN Item_Factura i ON i.item_producto=p.prod_codigo
				JOIN Factura f ON i.item_numero=f.fact_numero AND i.item_sucursal=f.fact_sucursal AND i.item_tipo=f.fact_tipo
WHERE YEAR(f.fact_fecha)=2012
GROUP BY p.prod_codigo, p.prod_detalle
--se interpreta ordenar por monto vendido en 2012
ORDER BY SUM(i.item_cantidad*i.item_precio) DESC

/*
13. Realizar una consulta que retorne para cada producto que posea composición
nombre del producto, precio del producto, precio de la sumatoria de los precios por
la cantidad de los productos que lo componen. Solo se deberán mostrar los
productos que estén compuestos por más de 2 productos y deben ser ordenados de
mayor a menor por cantidad de productos que lo componen.
*/

select p.prod_detalle, p.prod_precio, a.prod_precio as precioTotal
from Producto a
join Composicion on prod_codigo = comp_producto
join Producto p on comp_componente = p.prod_codigo
where comp_cantidad > 2
group by  p.prod_detalle, p.prod_precio, a.prod_precio, comp_cantidad
order by comp_cantidad DESC

/*
14. Escriba una consulta que retorne una estadística de ventas por cliente. Los campos
que debe retornar son:
Código del cliente
Cantidad de veces que compro en el último año
Promedio por compra en el último año
Cantidad de productos diferentes que compro en el último año
Monto de la mayor compra que realizo en el último año
Se deberán retornar todos los clientes ordenados por la cantidad de veces que
compro en el último año.
No se deberán visualizar NULLs en ninguna columna
*/

SELECT 
	clie_codigo AS codigo,
	COUNT(DISTINCT CONCAT(fact_sucursal,fact_tipo,fact_numero)) AS cant_compras,
	(
		SELECT AVG(fact_total) --no meto el AVG directamente porque fact_total se repite por cada item de la factura gracias al JOIN
		FROM Factura
		WHERE YEAR(fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura) AND fact_cliente=clie_codigo
	) AS promedio_compra,
	COUNT(DISTINCT item_producto) AS prods_diferentes,
	MAX(fact_total) AS monto_maximo
FROM Cliente 
left join Factura on clie_codigo = fact_cliente
join Item_Factura on fact_tipo = item_tipo AND
					fact_sucursal = item_sucursal AND
					fact_numero = item_numero

WHERE YEAR(fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura)
GROUP BY clie_codigo


/*
15. Escriba una consulta que retorne los pares de productos que hayan sido vendidos
juntos (en la misma factura) más de 500 veces. El resultado debe mostrar el código
y descripción de cada uno de los productos y la cantidad de veces que fueron
vendidos juntos. El resultado debe estar ordenado por la cantidad de veces que se
vendieron juntos dichos productos. Los distintos pares no deben retornarse más de
una vez.
Ejemplo de lo que retornaría la consulta:
PROD1 DETALLE1 PROD2 DETALLE2 VECES
1731 MARLBORO KS 1 7 1 8 P H ILIPS MORRIS KS 5 0 7
1718 PHILIPS MORRIS KS 1 7 0 5 P H I L I P S MORRIS BOX 10 5 6 2
*/

SELECT p1.prod_codigo PROD1, p1.prod_detalle DETALLE1, p2.prod_codigo PROD2, p2.prod_detalle DETALLE2, COUNT(*) VECES
FROM 
	(Producto p1 JOIN Item_Factura i1 ON i1.item_producto=p1.prod_codigo) 
	JOIN (Producto p2 JOIN Item_Factura i2 ON i2.item_producto=p2.prod_codigo)
		ON i2.item_numero=i1.item_numero 
		AND i2.item_tipo=i1.item_tipo 
		AND i2.item_sucursal=i1.item_sucursal 
		AND p1.prod_codigo!=p2.prod_codigo
WHERE p1.prod_codigo > p2.prod_codigo --aca ta la magia para que no se repitan
GROUP BY p1.prod_codigo, p1.prod_detalle, p2.prod_codigo, p2.prod_detalle
HAVING COUNT(*) > 500
ORDER BY VECES

/*
16. Con el fin de lanzar una nueva campaña comercial para los clientes que menos
compran en la empresa, se pide una consulta SQL que retorne aquellos clientes
cuyas ventas son inferiores a 1/3 del promedio de ventas del/los producto/s que más
se vendieron en el 2012.
Además mostrar
1. Nombre del Cliente
2. Cantidad de unidades totales vendidas en el 2012 para ese cliente.
3. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1,
mostrar solamente el de menor código) para ese cliente.
Aclaraciones:
La composición es de 2 niveles, es decir, un producto compuesto solo se compone
de productos no compuestos.
Los clientes deben ser ordenados por código de provincia ascendente.
*/
--no SE ENTIENDE UNA GOMA LO DE PROMEDIO DE VENTAS (FACTURAS? UNIDADES POR FACTURA? ju nous)
--VOY A ASUMIR QUE EL PROMEDIO DE VENTAS ES LA CANTIDAD DE FACTURAS DONDE FIGURA EL PRODUCTO Y FUE
--y que se refiere a la cantidad de ventas del 2012

SELECT clie_codigo, 
	--total de unidades compradas en el 2012
	(
		SELECT SUM(CASE WHEN comp_producto IS NULL THEN item_cantidad ELSE item_cantidad*comp_cantidad END)
		FROM Factura 
			JOIN Item_Factura 
				ON fact_sucursal=item_sucursal 
				AND fact_numero=item_numero 
				AND fact_tipo=item_tipo
			LEFT JOIN Composicion 
				ON item_producto=comp_producto
		WHERE fact_cliente=clie_codigo AND YEAR(fact_fecha)=2012
	) as unidades_totales_compradas,
	--producto mas comprado en el año
	(
		SELECT TOP 1 item_producto
		FROM Item_Factura i 
			JOIN Factura 
				ON fact_sucursal=item_sucursal 
				AND fact_numero=item_numero 
				AND fact_tipo=item_tipo
			LEFT JOIN Composicion c 
				ON item_producto=comp_componente
		WHERE YEAR (fact_fecha)=2012 AND fact_cliente=clie_codigo
		GROUP BY item_producto, comp_componente,comp_producto,comp_cantidad
		ORDER BY SUM(item_cantidad)
					+
				(CASE WHEN comp_componente is not null THEN 
					(
						SELECT SUM(item_cantidad)*c.comp_cantidad 
						FROM Factura f2 JOIN Item_Factura ON fact_sucursal=item_sucursal AND fact_numero=item_numero AND fact_tipo=item_tipo
						WHERE YEAR(fact_fecha)=2012 AND item_producto=c.comp_producto AND f2.fact_cliente=clie_codigo
					) ELSE 0 END 
				) DESC,
			 item_producto ASC
	) as producto_mas_comprado
FROM Cliente c JOIN Factura f ON clie_codigo=fact_cliente
GROUP BY clie_codigo, clie_domicilio
HAVING COUNT(*) < 1.00/3*(
		SELECT TOP 1 COUNT(*)--todas las facturas de un determinado producto vendido el 2012
		FROM Factura 
			JOIN Item_Factura 
				ON fact_sucursal=item_sucursal 
				AND fact_numero=item_numero 
				AND fact_tipo=item_tipo
		WHERE YEAR(fact_fecha)=2012
		GROUP BY item_producto
		ORDER BY COUNT(*) DESC
	)
ORDER BY clie_domicilio ASC

/*
17. Escriba una consulta que retorne una estadística de ventas por año y mes para cada
producto.
La consulta debe retornar:
PERIODO: Año y mes de la estadística con el formato YYYYMM
PROD: Código de producto
DETALLE: Detalle del producto
CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo
VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del
periodo pero del año anterior
CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el
periodo
La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar
ordenada por periodo y código de producto.
*/

SELECT 
	(CONCAT(YEAR(fact_fecha),RIGHT(CONCAT('0',MONTH(fact_fecha)),2))) AS PERIODO, 
	(prod_codigo) AS PROD, 
	(prod_detalle) AS DETALLE,
	(SUM(item_cantidad)) AS CANTIDAD_VENDIDA, 
	(SELECT isnull(SUM(item_cantidad),0)
	 FROM Item_Factura i1 JOIN Factura f1 ON fact_sucursal=item_sucursal AND fact_numero=item_numero AND fact_tipo=item_tipo
	 WHERE i1.item_producto=p.prod_codigo AND YEAR(f1.fact_fecha)=YEAR(f.fact_fecha)-1 AND MONTH(f1.fact_fecha)=MONTH(f.fact_fecha))
		AS VENTAS_AÑO_ANT,
	(COUNT(*)) AS CANT_FACTURAS
FROM Producto p JOIN  
	 (Item_Factura JOIN Factura f ON fact_sucursal=item_sucursal AND fact_numero=item_numero AND fact_tipo=item_tipo)
	 ON prod_codigo=item_producto
GROUP BY prod_codigo, prod_detalle, YEAR(fact_fecha), MONTH(fact_fecha)
ORDER BY PERIODO,PROD

/*
18. Escriba una consulta que retorne una estadística de ventas para todos los rubros.
La consulta debe retornar:
DETALLE_RUBRO: Detalle del rubro
VENTAS: Suma de las ventas en pesos de productos vendidos de dicho rubro
PROD1: Código del producto más vendido de dicho rubro
PROD2: Código del segundo producto más vendido de dicho rubro
CLIENTE: Código del cliente que compro más productos del rubro en los últimos
30 días
La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar
ordenada por cantidad de productos diferentes vendidos del rubro
*/
--no se si hay que modificar los valores nulos a uno por default o no mostrar las filas con valores nulos
--me juego por la primera

SELECT
	isnull(rubr_detalle,'sin nombre') AS DETALLE_RUBRO,

	isnull(SUM(item_cantidad*item_precio),0) AS VENTAS,

	isnull((SELECT TOP 1 p1.prod_codigo 
	 FROM Producto p1 JOIN Item_Factura i1 ON p1.prod_codigo=i1.item_producto
	 WHERE p1.prod_rubro=rubr_id
	 GROUP BY p1.prod_codigo
	 ORDER BY SUM(i1.item_cantidad) DESC)
	 ,'-')
		AS PROD1,
	
	isnull(
	(SELECT TOP 1 p2.prod_codigo 
	 FROM Producto p2 JOIN Item_Factura i2 ON p2.prod_codigo=i2.item_producto
	 WHERE p2.prod_rubro=rubr_id AND p2.prod_codigo!=
					(SELECT TOP 1 p1.prod_codigo 
					 FROM Producto p1 JOIN Item_Factura i1 ON p1.prod_codigo=i1.item_producto
					 WHERE p1.prod_rubro=rubr_id
					 GROUP BY p1.prod_codigo
					 ORDER BY SUM(i1.item_cantidad) DESC) 
	 GROUP BY p2.prod_codigo
	 ORDER BY SUM(i2.item_cantidad) DESC)
	 ,'-')
		AS PROD2,

	isnull(
	(SELECT TOP 1 clie_codigo
	FROM Cliente c JOIN Factura fc ON c.clie_codigo=fc.fact_cliente
		 JOIN Item_Factura ic ON fc.fact_sucursal=ic.item_sucursal AND fc.fact_numero=ic.item_numero AND fc.fact_tipo=ic.item_tipo
		 JOIN Producto pc ON ic.item_producto=pc.prod_codigo
	WHERE pc.prod_rubro=rubr_id AND fc.fact_fecha>DATEADD(day,-30,(SELECT MAX(fact_fecha) FROM Factura))--podriamos usar getdate pero para obtener un resultado no nulo voy a usar la fecha de la ultima factura como parametro en vez de la actual
	GROUP BY c.clie_codigo
	ORDER BY SUM(ic.item_cantidad) DESC
	)
	,'nadie') AS CLIENTE

FROM Rubro 
	JOIN Producto 
		ON prod_rubro=rubr_id	   
	JOIN Item_Factura 
		ON prod_codigo=item_producto
	JOIN Factura 
		ON fact_sucursal=item_sucursal 
		AND fact_numero=item_numero 
		AND fact_tipo=item_tipo
GROUP BY rubr_id, rubr_detalle
ORDER BY COUNT(DISTINCT prod_codigo) DESC