# Autopsia de la instancia FREE (Lab 4)

Fecha: 2026-11-01. Evidencia: `docs/bitacora/lab4/evidencia/spool/*_15-autopsia-instancia.spool.log`
(script `scripts/lab4/15-autopsia-instancia.sql`, ejecutado con C##OPS_RO, solo lectura).

Base revisada: FREE (DBID 1509902213), Oracle AI Database 26ai Free 23.26.3.0.0, contenedor
`oralab-26ai` recreado en la Parte C (host 299d6830019c), instancia arrancada a las 22:36 UTC
(reinicio de la Parte E).

## Hallazgos

| # | Sección | Evidencia (valor exacto) | Riesgo | Acción | Prioridad |
|---|---------|--------------------------|--------|--------|-----------|
| 1 | 1 y 4 | `LOG_MODE = ARCHIVELOG`, `FORCE_LOGGING = YES`, pero `db_recovery_file_dest` vacío y `db_recovery_file_dest_size = 0`. Hay 2 redo archivados (259 MB) en `$ORACLE_HOME/dbs`, que es un enlace a `dbconfig/FREE/dbs` dentro del volumen | Los archivados crecen sin límite y nadie los borra. Si se llena el disco, el archivador se bloquea y la base deja de aceptar cambios. Además no hay ninguna copia RMAN, así que los archivados todavía no sirven para recuperar nada | Configurar una FRA con tamaño máximo, hacer copias con RMAN y una política de retención que borre lo ya copiado (Lab 5) | Alta |
| 2 | 4 | 2 control files (`control01.ctl` y `control02.ctl`) en la misma carpeta `/opt/oracle/oradata/FREE`, y 3 grupos de redo con 1 miembro cada uno (600 MB) en esa misma carpeta | Punto único de fallo: si se estropea el volumen se pierden a la vez los dos control files y todo el redo online. Si se corrompe un miembro de redo no hay otra copia | Multiplexar el redo (2 miembros por grupo) y separar las copias del control file en otro volumen (Lab 5) | Alta |
| 3 | 4 (y Parte J) | `diagnostic_dest = /opt/oracle`, fuera del volumen. El alert log solo tiene lo ocurrido desde que se recreó el contenedor a las 22:30, más el historial de cuando se construyó la imagen (2026-07-05) | Cada vez que se actualice la imagen se pierde el historial de errores y de arranques justo cuando más falta hace | Llevar el ADR a una ruta persistente o enviar el alert log a un sistema central de logs | Media |
| 4 | 5 | SYSTEM, SYSAUX, USERS y UNDOTBS1 son BIGFILE con autoextensión sin techo útil: `MB_MAXIMO` 959744 en SYSTEM y 33554432 en UNDOTBS1. Los TBS de negocio sí tienen techo de 1024 MB desde la Parte C | Una transacción enorme o una tabla de auditoría que crezca puede llenar el disco del equipo sin que salte ningún aviso de Oracle. Free además corta en 12 GB de datos de usuario (ORA-12954) | Vigilar a diario la sección 5 y el espacio libre del volumen, y poner MAXSIZE razonable en USERS | Media |
| 5 | 6 | ADMIN_CLINICA, ADMIN_FINTECH, ADMIN_LOGISTICA y ADMIN_RETAIL salen con `ALTURA_MAX` vacía: no tienen estadísticas. Solo ADMIN_ACADEMIA las tiene (las recogió V002) | En cuanto esas tablas tengan datos, el optimizador elegirá planes sin saber cuántas filas hay | `DBMS_STATS.GATHER_SCHEMA_STATS` después de cada carga de datos y comprobar que el job automático de estadísticas está activo | Media |
| 6 | 6 | ADMIN_ACADEMIA: 9 índices, 7 únicos, altura máxima 2 y `CF_CERCANO_A_FILAS = 2` | Esos dos índices son caros para consultas por rango porque las filas están desordenadas respecto al índice | Analizarlos con el factor de agrupamiento en el Lab 5 antes de decidir nada | Baja |
| 7 | 2 | `maximum PGA allocated = 504 MB` frente a `aggregate PGA target parameter = 512 MB` | Casi tocamos el objetivo, aunque en buena parte por los experimentos de la Parte G. Con más usuarios habría más ordenaciones en TEMP | Vigilar `v$pgastat` (over allocation count, que hoy es 0) y el histograma de áreas de trabajo. No cambiar nada todavía | Baja |
| 8 | 9 | `db_create_file_dest = /opt/oracle/oradata` | Ninguno: es el cambio que hice en el reto de la Parte C para que un CREATE TABLESPACE sin ruta no salga del volumen. Lo dejo anotado porque un cambio de configuración sin documentar es deriva | Ninguna, ya está en su propio commit | Sin prioridad |
| 9 | 9 | Parámetro oculto `_instance_recovery_bloom_filter_size = 1048576` en el SPFILE | Los parámetros ocultos solo se tocan con indicación de soporte. Lo puso la imagen, no nosotros | Documentarlo y no tocarlo | Baja |
| 10 | 10 | 6 errores ORA- en 24 h: ORA-00800 (4 veces), ORA-65025 (1) y ORA-959 (1) | ORA-00800 es ruido conocido del contenedor (no le deja subir la prioridad de VKTM y LGWR). ORA-65025 lo provoqué en la Parte I al borrar la PDB abierta. ORA-959 sale del `DROP TABLESPACE IF EXISTS tbs_lab4` de la Parte L: el IF EXISTS lo oculta al cliente pero el alert log lo apunta igual | Excluir ORA-00800 de las alertas. Ninguno de los tres hay que investigarlo | Baja |

Lo que está bien y no necesita acción:

- Sección 7: ninguna cuenta nuestra tiene el rol DBA. La única cuenta común de la casa es C##OPS_RO y en FREEPDB1 hay 9 cuentas locales, las de negocio (sin contraseña desde V003), ALUMNO, PDBADMIN y las de ORDS.
- Sección 5: los TBS de negocio van muy por debajo de su techo (TBS_ACADEMIA, el más lleno, 23 MB de 1024, un 2,3 %).
- Sección 3: 90 procesos de segundo plano, entre ellos ARC0 a ARC3, que existen porque la base está en ARCHIVELOG.
- Sección 8: el listener anuncia `free`, `freeXDB` y `freepdb1`, nada que no esperemos.

## Resumen para dirección

La base funciona bien y los datos ya están guardados en el almacenamiento que sobrevive a los cambios de servidor: lo probamos borrando y recreando el contenedor sin perder nada.
El punto débil es la recuperación: no hay copias de seguridad automáticas y los ficheros que permitirían recuperar hasta el último minuto se acumulan sin control y en un único sitio.
Propongo dedicar el siguiente laboratorio a eso (área de recuperación, copias con RMAN y duplicar los ficheros críticos). El resto son ajustes menores.
