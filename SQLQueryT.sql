--productos compuestos
where ITEM_PRODUCTO in (select comp_producto from Composicion) and --alguna otra condicion que tome elemtno de pre-where con elemento pre-select-prewhere)

--productos mas vendidos
WHERE prod_codigo IN (SELECT TOP N p.prod_codigo FROM Producto p
				join Item_Factura itf on prod_codigo = itf.item_producto
				group by p.prod_codigo
				order by SUM(itf.item_cantidad) DESC)

--cantidad de compras cliente
COUNT(DISTINCT CONCAT(fact_sucursal,fact_tipo,fact_numero))
/*select sum(1) from Factura where fact_cliente = clie_codigo*/

--monto total factura joineando con item_factura
sum(item_cantidad*item_precio)

--fecha maxima
(SELECT MAX(YEAR(fact_fecha)) FROM Factura)










--COMPOSICION
select a.prod_detalle, a.prod_precio,p.prod_detalle, p.prod_precio, comp_cantidad
from Producto a
join Composicion on prod_codigo = comp_producto
join Producto p on comp_componente = p.prod_codigo
group by a.prod_codigo, a.prod_detalle, a.prod_precio,p.prod_detalle, p.prod_precio, comp_cantidad
