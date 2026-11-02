# Runbook: pérdida de un datafile de negocio (FREEPDB1)

Para quien esté de guardia en `oralab-26ai`. Probado en el simulacro D del Lab 5 (`scripts/lab5/14d-perdida-datafile.sh`): RTO 13 s, RPO 0.

## Síntoma

Las consultas a las tablas de un tablespace fallan con:

- `ORA-01116: error in opening database file N`
- `ORA-01110: data file N: '/opt/oracle/oradata/FREE/FREEPDB1/....dbf'`
- `ORA-27041: unable to open file` (con `Linux-x86_64 Error: 2: No such file or directory`)

Si en el alert log aparece `ORA-63999: data file suffered media failure`, un proceso de fondo (en el simulacro fue CKPT) detectó el fallo y Oracle cerró la PDB entera para protegerla: ya no falla una tabla, falla toda FREEPDB1.

## Comprobaciones antes de tocar nada

1. ¿Qué archivo es? El número N y la ruta salen en ORA-01110. Si es SYSTEM o el undo de la raíz, **para aquí y escala**: ese caso se recupera con la CDB montada y no es este procedimiento.
2. ¿La base está en ARCHIVELOG? `SELECT log_mode FROM v$database;` tiene que decir `ARCHIVELOG`. Si no, solo queda restaurar la última copia en frío completa y se pierde todo lo posterior: escala.
3. ¿Hay copia del archivo? En `rman target /`: `LIST BACKUP OF DATAFILE N;` Tiene que salir al menos una copia completada.
4. ¿En qué estado está la PDB? `SELECT name, open_mode FROM v$pdbs;` Si dice `MOUNTED`, Oracle ya la cerró (camino B). Si lleva unos segundos cerrándose, espera a que quede `MOUNTED` antes de restaurar: un RESTORE a mitad de un cierre falla.

## Reparación

Todo como SYSDBA dentro del contenedor (`docker exec -it oralab-26ai bash`, luego `sqlplus / as sysdba` o `rman target /`). Sustituye N por el número del archivo.

**Camino A: FREEPDB1 sigue en READ WRITE** (solo está caído ese tablespace)

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE N OFFLINE;
-- en RMAN:  RESTORE DATAFILE N;  RECOVER DATAFILE N;
ALTER DATABASE DATAFILE N ONLINE;
```

**Camino B: FREEPDB1 está MOUNTED** (hubo ORA-63999)

```sql
-- en RMAN, con la PDB montada:  RESTORE DATAFILE N;  RECOVER DATAFILE N;
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE N ONLINE;
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
```

En los dos casos la CDB y las demás PDB siguen dando servicio. RECOVER aplica el redo archivado y el redo en línea posteriores a la copia, así que no se pierde nada confirmado.

## Cómo comprobar que ha funcionado

- `SELECT name, open_mode FROM v$pdbs;` → FREEPDB1 en `READ WRITE`.
- `SELECT file#, status FROM v$datafile WHERE file# = N;` → `ONLINE`.
- La consulta que fallaba devuelve datos. En el simulacro, la fila de control (estudiante 104, cambiada después de la copia) seguía con su valor nuevo: prueba de que el RPO fue 0.
- Revisa el alert log: no debe haber ORA- nuevos después del `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN`.

## A quién avisar

1. Al empezar: al responsable de la aplicación afectada (qué tablespace y qué esquema, por ejemplo TBS_ACADEMIA → Academia) y, si hubo ORA-63999, a todos los de FREEPDB1, porque estuvo cerrada entera.
2. Al terminar: hora del fallo, hora de vuelta al servicio (RTO) y si se perdió algo (RPO).
3. Después: abre una incidencia para averiguar por qué desapareció el archivo (disco, borrado manual...) y lanza una copia RMAN nueva de ese tablespace.
