# Día 10 — HPA y PDB: autoescalado de web y presupuesto de interrupciones
**Fecha:** ????-??-?? · **Inicio:** ??:?? · **Fin:** ??:?? · **Minutos reales:** ??' (plan: 45') · **Estado:** 🔄 en curso

## 🎯 Objetivo
`web` sube de réplicas cuando recibe carga y un `kubectl drain` nunca lo deja con menos Pods disponibles que el mínimo del PDB.

## ✅ Criterios (una línea de por qué por cada uno)
| # | Criterio | Hecho | Qué pasó y por qué (1 línea) | Evidencia |
|---|---|---|---|---|
| 1 | `kubectl top nodes` funciona (metrics-server) | yes | ?? | `02-metrics.txt` |
| 2 | El HPA sube `web` a 3 o más réplicas Ready en 180 s o menos | yes | ?? | `03-hpa-carga.txt` |
| 3 | Con el PDB, el drain de un worker deja siempre al menos el mínimo disponible | yes | ?? | `04-drain.txt` |

**Predicción:** aciertos 4/4. ¿Guardada antes de aplicar el HPA? yes
**Objetivo de CPU elegido:** 1% de 500m (medido: reposo 1m, con carga 11m por Pod, `01-medicion.txt`)

## 🔧 Los blancos
- BLANCO 1 (flag de metrics-server): --kubelet-insecure-tls — porque ??
- BLANCO 2 (`minReplicas`): 2 — porque ??
- BLANCO 3 (`averageUtilization`): 1 — porque ??
- BLANCO 4 (`minAvailable` del PDB): 2 — porque ??
- BLANCO 5 (etiqueta del PDB): web — porque ??

## ❓ Preguntas (1 línea cada una)
1. Con `web` en 2 réplicas y sin carga, ¿qué hace un `kubectl drain` del worker donde corre uno de sus Pods? ¿Por qué?
el drain falla debido a minAvailable=2
2. Con el HPA activo, ¿qué pasa con las réplicas cada vez que aplicas `manifests/web-deployment.yaml`, que dice `replicas: 3`?
el apply configura las replicas en 3 pero luego el HPA lo ajusta según sus metricas definidas.

## Opcional (solo lo que hayas hecho)
no hice ninguna por falta de tiempo

## ⏭️ Pendiente (una línea; si no hay nada, escribe «nada»)
las 3 opcionales.
