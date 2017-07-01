/* realizar una consulta SQL que retorne: 
año, 
cantidad de productos compuestos vendidos en el año, 
cantidad de facturas realizadas en el año,
monto total facturado en el año,
monto total facturado en el año anterior.

solamente considerar aquellos años donde la cant de unidades vendidas de todos los arts sea mayor a 10
el resultado tiene que mostrar primero aquellos años donde la cant vend de todos los arts este entre 50 y 100 unidades*/

select year(f.fact_fecha) anio,
 (select sum(item_cantidad) from Item_Factura
	join Factura on fact_tipo=item_tipo AND fact_sucursal=item_sucursal AND fact_numero=item_numero
	WHERE item_producto in (select comp_producto from Composicion) AND YEAR(f.fact_fecha) = YEAR(fact_fecha)
	) prodCompVendAño,
(select count (*) from Factura where  YEAR(fact_fecha) = YEAR(f.fact_fecha)) cant_fac_anio,

 (select isnull(sum(item_cantidad*item_precio),0) from Item_Factura
	join Factura on fact_tipo = item_tipo AND fact_sucursal = item_sucursal AND fact_numero=item_numero AND YEAR(fact_fecha) = YEAR(f.fact_fecha)
 ) monto_total_anio,

 (select isnull(sum(item_cantidad*item_precio),0) from Item_Factura
	join Factura on fact_tipo = item_tipo AND fact_sucursal = item_sucursal AND fact_numero=item_numero AND YEAR(fact_fecha) = YEAR(f.fact_fecha) -1
 ) monto_total_anio_ant
	
from Factura f
join Item_Factura itf on fact_tipo=itf.item_tipo AND fact_sucursal=itf.item_sucursal AND fact_numero=itf.item_numero
where 10 < (select top 1 isnull(sum(item_cantidad),0) from Item_Factura 
				left join Factura on fact_tipo=item_tipo AND fact_sucursal=item_sucursal AND fact_numero=item_numero
				group by item_cantidad
				order by sum(item_cantidad) ASC)
group by YEAR(f.fact_fecha)
order by (select top 1 CASE WHEN ISNULL(SUM(ITEM_CANTIDAD),0) between 50 and 100 THEN 1 else 0 END from Item_Factura 
				left join Factura on fact_tipo=item_tipo AND fact_sucursal=item_sucursal AND fact_numero=item_numero AND YEAR(fact_fecha) = YEAR(f.fact_fecha)
				group by item_producto
				having ISNULL(SUM(ITEM_CANTIDAD),0) between 50 and 100) desc
			