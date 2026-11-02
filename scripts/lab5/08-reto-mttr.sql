-- scripts/lab5/08-reto-mttr.sql — reto de la Parte I: el MTTR estimado bajo carga (paso 1 de 13-lgwr-dbwn.sql, sin checkpoint)
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
-- El UPDATE no cambia ningún valor (estado = estado), pero genera redo y deja bloques sucios en la caché.
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 150 PAGESIZE 50 FEEDBACK OFF
COLUMN momento FORMAT A26
SELECT 'antes' AS momento, estimated_mttr, actual_redo_blks, target_redo_blks FROM v$instance_recovery;
ALTER SESSION SET CONTAINER = FREEPDB1;
UPDATE admin_academia.aca_estudiantes SET estado = estado;
COMMIT;
ALTER SESSION SET CONTAINER = CDB$ROOT;
SELECT 'justo despues' AS momento, estimated_mttr, actual_redo_blks, target_redo_blks FROM v$instance_recovery;
EXEC DBMS_SESSION.SLEEP(10)
SELECT 'despues de 10 s' AS momento, estimated_mttr, actual_redo_blks, target_redo_blks FROM v$instance_recovery;
EXIT
