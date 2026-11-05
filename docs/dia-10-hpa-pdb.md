# Día 10 — HPA y PDB: autoescalado de web y presupuesto de interrupciones
**Fecha:** 2026-11-05 · **Inicio:** 10:34 · **Fin:** 11:55 · **Minutos reales:** 50' · **Estado:** 🟡 ejecutado, pendiente del cierre del mentor

## 🎯 Objetivo
`web` sube de réplicas cuando recibe carga y un `kubectl drain` nunca lo deja con menos Pods disponibles que el mínimo del PDB.

## ✅ Criterios (una línea de por qué por cada uno)
| # | Criterio | Hecho | Qué pasó y por qué (1 línea) | Evidencia |
|---|---|---|---|---|
| 1 | `kubectl top nodes` funciona (metrics-server) | yes | metrics-server 1/1, APIService disponible y los 3 nodos en `kubectl top nodes`; hizo falta `--kubelet-insecure-tls` por los certificados autofirmados de kind | `02-metrics.txt` |
| 2 | El HPA sube `web` a 3 o más réplicas Ready en 180 s o menos | yes | con objetivo 1% el HPA subió `web` de 2 a 3 Ready a los 36 s y a 5 a los 49 s (CPU 3% con 2 Pods) | `03-hpa-carga.txt` |
| 3 | Con el PDB, el drain de un worker deja siempre al menos el mínimo disponible | yes | drenó `lab-worker2` con la carga encendida: 3 evicciones de `web`, 0 bloqueos y mínimo de 2 disponibles (= `minAvailable`); el PDB nunca tuvo que decir que no | `04-drain.txt` |

**Predicción:** aciertos 4/4. ¿Guardada antes de aplicar el HPA? yes (guardada a las 11:09, antes de `medir`; el HPA se aplicó hacia las 11:29)
**Objetivo de CPU elegido:** 1% de 500m (medido: reposo 1m, con carga 11m por Pod, `01-medicion.txt`)

## 🔧 Los blancos
- BLANCO 1 (flag de metrics-server): --kubelet-insecure-tls — porque los kubelet de kind usan certificados autofirmados y metrics-server no los acepta sin ese flag (solo para laboratorio)
- BLANCO 2 (`minReplicas`): 2 — porque es el mínimo del plan: sin carga `web` vuelve a 2 réplicas (en `prueba` bajó de 3 a 2 a los 50 s)
- BLANCO 3 (`averageUtilization`): 1 — porque la medición (reposo 1m, con carga 11m por Pod, 1% = 5m) deja un rango de 1% a 2%, y con 1% el HPA sube tanto con 27m como con 33m de carga total (con 2% dependía del redondeo)
- BLANCO 4 (`minAvailable` del PDB): 2 — porque así un drain nunca deja menos de 2 Pods de `web`; con `web` en 2 réplicas bloquearía el drain de un worker que tenga uno, por eso el drain se probó bajo carga con 5
- BLANCO 5 (etiqueta del PDB): web — porque el selector tiene que coincidir con la etiqueta `app: web` de los Pods; si no, el PDB selecciona 0 Pods y no protege nada

## ❓ Preguntas (1 línea cada una)
1. Con `web` en 2 réplicas y sin carga, ¿qué hace un `kubectl drain` del worker donde corre uno de sus Pods? ¿Por qué?
el drain acordona el nodo, como alcanza su minAvailable=2, se queda esperando y vuelve a intentar cada 5s hasta el timeout=180s
2. Con el HPA activo, ¿qué pasa con las réplicas cada vez que aplicas `manifests/web-deployment.yaml`, que dice `replicas: 3`?
el apply configura las replicas en 3 pero luego el HPA lo ajusta según sus metricas definidas.

## Opcional (solo lo que hayas hecho)
no hice ninguna por falta de tiempo

## ⏭️ Pendiente (una línea; si no hay nada, escribe «nada»)
las 3 opcionales.
