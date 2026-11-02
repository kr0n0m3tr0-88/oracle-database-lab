-- scripts/lab5/06-reto-v006.sql — reto de la Parte G: las cinco preguntas para un índice en CLIENTE.TELEFONO (Q5)
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
-- Crea el índice solo para medirlo y lo borra al final: el índice de verdad llega con V006 (rama aparte).
SET LINESIZE 200 PAGESIZE 50 FEEDBACK OFF
COLUMN columnas FORMAT A40
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON
BEGIN
  FOR i IN (SELECT index_name FROM dba_indexes WHERE owner = 'TIENDASUR' AND index_name = 'IX_CLI_TELEFONO') LOOP
    EXECUTE IMMEDIATE 'DROP INDEX tiendasur.ix_cli_telefono';
  END LOOP;
END;
/
PROMPT == Pregunta 1 · NECESIDAD: Q5, identificar a quien llama (10 por segundo), con los índices de V005 ==
EXEC lab_tools.medir.consulta('Q5 hoy', 'SELECT * FROM tiendasur.cliente WHERE email = ''661452937'' OR telefono = ''661452937''')
PROMPT == Pregunta 2 · VIABILIDAD: selectividad de una igualdad sobre TELEFONO ==
SELECT num_distinct AS claves, ROUND(100 / num_distinct, 4) AS pct_por_valor
  FROM dba_tab_col_statistics WHERE owner = 'TIENDASUR' AND table_name = 'CLIENTE' AND column_name = 'TELEFONO';
PROMPT == Pregunta 3 · ESCRITURA: 1000 altas de cliente sin el índice ==
EXEC lab_tools.medir.dml('altas sin ix_cli_telefono', q'[BEGIN FOR i IN 1 .. 1000 LOOP INSERT INTO tiendasur.cliente VALUES (200000 + i, 'X' || LPAD(i, 7, '0') || 'Z', 'alta' || i || '@tiendasur.es', 'Nombre', 'Prueba Alta', TO_CHAR(700000000 + i), 'ES', 'Murcia', SYSDATE); END LOOP; END;]', 1000)
PROMPT == Pregunta 4 · REDUNDANCIA: ¿algún índice de CLIENTE empieza ya por TELEFONO? ==
SELECT index_name, LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_position) AS columnas
  FROM dba_ind_columns WHERE index_owner = 'TIENDASUR' AND table_name = 'CLIENTE' GROUP BY index_name ORDER BY 1;
PROMPT == Pregunta 5 · CICLO DE VIDA: se crea INVISIBLE, se comprueba que no cambia nada y después se hace visible ==
CREATE INDEX tiendasur.ix_cli_telefono ON tiendasur.cliente (telefono) INVISIBLE;
EXEC lab_tools.medir.consulta('Q5 indice invisible', 'SELECT * FROM tiendasur.cliente WHERE email = ''661452937'' OR telefono = ''661452937''')
ALTER INDEX tiendasur.ix_cli_telefono VISIBLE;
EXEC lab_tools.medir.consulta('Q5 con ix_cli_telefono', 'SELECT * FROM tiendasur.cliente WHERE email = ''661452937'' OR telefono = ''661452937''')
EXEC lab_tools.medir.dml('altas con ix_cli_telefono', q'[BEGIN FOR i IN 1 .. 1000 LOOP INSERT INTO tiendasur.cliente VALUES (200000 + i, 'X' || LPAD(i, 7, '0') || 'Z', 'alta' || i || '@tiendasur.es', 'Nombre', 'Prueba Alta', TO_CHAR(700000000 + i), 'ES', 'Murcia', SYSDATE); END LOOP; END;]', 1000)
SELECT i.index_name, i.blevel + 1 AS altura, i.leaf_blocks AS hojas, ROUND(s.bytes / 1048576, 1) AS mb
  FROM dba_indexes i JOIN dba_segments s ON s.owner = i.owner AND s.segment_name = i.index_name
 WHERE i.owner = 'TIENDASUR' AND i.index_name = 'IX_CLI_TELEFONO';
PROMPT == Limpieza: el índice de prueba se borra; si se aprueba, lo crea V006 ==
DROP INDEX tiendasur.ix_cli_telefono;
SELECT COUNT(*) AS indices_cliente FROM dba_indexes WHERE owner = 'TIENDASUR' AND table_name = 'CLIENTE';
EXIT
