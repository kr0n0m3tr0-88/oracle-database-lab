-- database/migrations/V006__indice_telefono_cliente.sql
-- Q5 de la Actividad 3.2: identificar a quien llama (email = :dato OR telefono = :dato), 10 veces por segundo.
-- Sin índice en TELEFONO, el OR obliga a leer CLIENTE entera (1486 lecturas lógicas); con él, 6.
-- Medido con scripts/lab5/06-reto-v006.sql. Idempotente: si el índice ya existe, no hace nada.
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;
DECLARE
  v_hay NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_hay FROM dba_indexes WHERE owner = 'TIENDASUR' AND index_name = 'IX_CLI_TELEFONO';
  IF v_hay = 0 THEN
    EXECUTE IMMEDIATE 'CREATE INDEX tiendasur.ix_cli_telefono ON tiendasur.cliente (telefono)';
  END IF;
END;
/
SET LINESIZE 120 PAGESIZE 50
COLUMN index_name FORMAT A20
SELECT index_name, visibility, status FROM dba_indexes
 WHERE owner = 'TIENDASUR' AND table_name = 'CLIENTE' ORDER BY index_name;
EXIT
