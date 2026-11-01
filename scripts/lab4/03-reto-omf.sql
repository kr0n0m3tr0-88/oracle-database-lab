-- scripts/lab4/03-reto-omf.sql — reto de la Parte C: que un datafile nuevo no vuelva a quedar fuera del volumen
-- Activa OMF (Oracle Managed Files): un CREATE TABLESPACE sin ruta crea el archivo bajo db_create_file_dest.
-- Se ejecuta en CDB$ROOT; FREEPDB1 hereda el valor porque no tiene uno propio.
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 160 PAGESIZE 50 FEEDBACK ON
COLUMN name FORMAT A20
COLUMN value FORMAT A30
COLUMN tablespace_name FORMAT A8
COLUMN file_name FORMAT A90
PROMPT == 1. Antes: sin destino OMF ==
SELECT name, NVL(value, '(vacío: sin OMF)') AS value FROM v$parameter WHERE name = 'db_create_file_dest';
PROMPT == 2. Destino OMF dentro del volumen: parámetro dinámico, SCOPE = BOTH (ya y tras reiniciar) ==
ALTER SYSTEM SET db_create_file_dest = '/opt/oracle/oradata' SCOPE = BOTH;
PROMPT == 3. En FREEPDB1: CREATE TABLESPACE sin cláusula DATAFILE ==
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT name, value FROM v$parameter WHERE name = 'db_create_file_dest';
CREATE TABLESPACE tbs_x;
SELECT tablespace_name, file_name, ROUND(bytes / 1048576) AS mb, autoextensible
  FROM dba_data_files WHERE tablespace_name = 'TBS_X';
PROMPT == 4. Limpieza: la prueba no se queda en la base ==
DROP TABLESPACE tbs_x INCLUDING CONTENTS AND DATAFILES;
EXIT
