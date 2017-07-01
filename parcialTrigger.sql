
 
CREATE TRIGGER fact_prod_00 ON ITEM_FACTURA AFTER INSERT, UPDATE
AS
BEGIN
 
    DECLARE @i_producto char(8)
    DECLARE @diferencia decimal(12,2)
    DECLARE @diferencia_comp decimal(12,2)
    DECLARE @stock_disponible decimal(12,2)
    DECLARE @comp_prod char(8)
    DECLARE @stock_comp decimal(12,2)
 
 
    DECLARE FACTURACION CURSOR for
    select i.item_cantidad - isnull(d.item_cantidad,0), i.item_producto,
    comp_componente, ISNULL(comp_cantidad,0) * (i.item_cantidad - isnull(d.item_cantidad,0))
    FROM INSERTED i LEFT JOIN DELETED d on i.item_tipo = d.item_tipo and i.item_numero = d.item_numero and i.item_sucursal = d.item_sucursal
    LEFT JOIN Composicion on comp_producto = i.item_producto
    and i.item_producto = d.item_producto
 
    OPEN FACTURACION
   
    FETCH NEXT from FACTURACION into @diferencia,@i_producto,@comp_prod,@diferencia_comp
   
    WHILE @@FETCH_STATUS = 0  
    BEGIN
        select @stock_disponible = stoc_cantidad from STOCK
        where stoc_deposito = '00' and stoc_producto = @i_producto
 
        select @stock_comp = stoc_cantidad from STOCK
        where stoc_deposito = '00' and stoc_producto = @comp_prod
       
 
 
        if (@stock_disponible < @diferencia or @stock_comp < @diferencia_comp)
        BEGIN
            rollback transaction
            RAISERROR('No hay suficiente stock en el deposito "00" para agregar ese articulo',16,1)
        END
        else
        commit
       
        FETCH NEXT from FACTURACION into @diferencia,@i_producto,@comp_prod,@diferencia_comp
    END
   
    CLOSE FACTURACION
 
END
 
GO