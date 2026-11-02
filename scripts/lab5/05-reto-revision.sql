-- scripts/lab5/05-reto-revision.sql — reto de la Parte F: la consulta del panel de atención al cliente, rota y reescrita
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
-- Crea dos índices temporales (teléfono y apellidos), mide y los borra al final: el banco queda con sus 7 índices.
SET LINESIZE 200 PAGESIZE 50 FEEDBACK OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON
BEGIN
  FOR i IN (SELECT index_name FROM dba_indexes WHERE owner = 'TIENDASUR' AND index_name IN ('IX_CLI_TELEFONO', 'IX_CLI_APELLIDOS')) LOOP
    EXECUTE IMMEDIATE 'DROP INDEX tiendasur.' || i.index_name;
  END LOOP;
END;
/
PROMPT == 1. Tal como viene en el Pull Request, sin índices en teléfono ni apellidos ==
EXEC lab_tools.medir.consulta('PR sin indices', 'SELECT * FROM tiendasur.cliente WHERE SUBSTR(telefono, 1, 3) = ''600'' OR UPPER(apellidos) = ''GIL''')
PROMPT == 2. Con índices en las dos columnas la consulta rota sigue sin poder usarlos (regla 1 dos veces) ==
CREATE INDEX tiendasur.ix_cli_telefono ON tiendasur.cliente (telefono);
CREATE INDEX tiendasur.ix_cli_apellidos ON tiendasur.cliente (apellidos);
EXEC lab_tools.medir.consulta('PR con indices', 'SELECT * FROM tiendasur.cliente WHERE SUBSTR(telefono, 1, 3) = ''600'' OR UPPER(apellidos) = ''GIL''')
PROMPT == 3. Reescrita: prefijo con LIKE y apellidos tal como se guardan (las dos ramas del OR son sargables) ==
EXEC lab_tools.medir.consulta('reescrita OR', 'SELECT * FROM tiendasur.cliente WHERE telefono LIKE ''600%'' OR apellidos = ''Gil''')
EXEC lab_tools.medir.consulta('reescrita UNION', 'SELECT * FROM tiendasur.cliente WHERE telefono LIKE ''600%'' UNION SELECT * FROM tiendasur.cliente WHERE apellidos = ''Gil''')
PROMPT == 4. Mismo resultado: filas de cada versión ==
SELECT (SELECT COUNT(*) FROM tiendasur.cliente WHERE SUBSTR(telefono, 1, 3) = '600' OR UPPER(apellidos) = 'GIL') AS rota,
       (SELECT COUNT(*) FROM tiendasur.cliente WHERE telefono LIKE '600%' OR apellidos = 'Gil') AS reescrita
  FROM dual;
PROMPT == 5. Limpieza de los índices temporales ==
DROP INDEX tiendasur.ix_cli_telefono;
DROP INDEX tiendasur.ix_cli_apellidos;
SELECT COUNT(*) AS indices_tiendasur FROM dba_indexes WHERE owner = 'TIENDASUR';
EXIT
