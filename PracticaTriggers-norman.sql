-- 1) pre
select * into EmpleadosInsertados from Empleado;
delete from EmpleadosInsertados;
alter table EmpleadosInsertados add usuario VARCHAR(255) NOT NULL, fecha DATE NOT NULL;
select * from EmpleadosInsertados;

-- 1) ejr
create trigger tr_ej1 on Empleado
for insert
as
  begin transaction
    insert into EmpleadosInsertados select *, SUSER_SNAME(), GETDATE()
      from inserted;
  commit
go

-- 2) pre
alter table DEPOSITO add baja INT NOT NULL DEFAULT 0;
select * from DEPOSITO;

-- 2) ejr
create trigger tr_ej2 on DEPOSITO
instead of delete
as
  begin transaction
    update DEPOSITO set baja = 1 from DEPOSITO dp
	  join deleted dl on  dl.depo_codigo = dp.depo_codigo
    commit
go

-- 3) pre
select * into EmpleadosEliminados from Empleado;
delete from EmpleadosInsertados;
alter table EmpleadosInsertados add fecha DATE NOT NULL;
select * from EmpleadosEliminados;

-- 3) ejr
create trigger tr_ej3 on Empleado
for delete
as
  begin transaction
    insert into Empleados select *, GETDATE() from deleted
    commit
go

-- 6) ejr
create trigger tr_ej6 on Producto
instead of delete
as
begin transaction
  if exists
  (
    select 1
	from STOCK s
	join Producto p on s.stoc_producto = p.prod_codigo
	join deleted d on d.prod_codigo = p.prod_codigo
	where s.stoc_cantidad > 0
	group by d.prod_codigo
  )
    raiseerror('No se puede borrar productos con stock', 16,1)
  else
    delete from Producto
		where Producto.prod_codigo in (select prod_codigo from deleted)
    commit
go
