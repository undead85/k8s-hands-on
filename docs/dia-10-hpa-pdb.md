# Día 10 — HPA y PDB: autoescalado de web y presupuesto de interrupciones
**Fecha:** 2026-11-05 · **Inicio:** 10:34 · **Fin:** 11:55 · **Minutos reales:** 50' declarados; reloj 10:34 a 11:55 (81'), con el commit a las 11:55 (plan: 45') · **Estado:** ✅ cerrado (cierre del mentor, 2026-11-05)

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

## 🔎 Revisión del mentor (2026-11-05)
Horas de la evidencia en UTC (hora local = UTC−3).

| Parte | Veredicto |
|---|---|
| 1. metrics-server | ✅ `02-metrics.txt` (14:40): `metrics-server` 1/1, APIService `Available=True`, `kubectl top nodes` con los 3 nodos y el flag `--kubelet-insecure-tls` en el Pod. El manifiesto es el oficial v0.9.1 con esa única línea cambiada: quitándola, el sha256 coincide con el del original que consta en su cabecera |
| 2. HPA | ✅ `03-hpa-carga.txt`: al crear el HPA (≈14:29), `web` bajó de 3 a 2 a los 50 s (ventana de 60 s). Con la carga encendida (14:30:18) llegó a 3 Ready a los 36 s y a 5 a los 49 s, con CPU 3% con 2 Pods. 36 s frente al límite de 180 s |
| 3. PDB y drain | ✅ `04-drain.txt`: `drain` de `lab-worker2` (3 de los 5 Pods de `web`) bajo carga, exit 0 en ≈7 s, 3 evicciones de `web`, 0 bloqueos y mínimo de 2 disponibles (= `minAvailable`). `uncordon` a las 14:31:20 y los 3 nodos Ready a las 14:40 |
| Predicción | 4/4, guardada a las 14:09 (antes de `medir`, 14:16, y del HPA, ≈14:29) |
| O1 a O3 | no realizados (opcionales, sin deuda) |

Ejes: 🎯 ✅ · 🔐 ✅ (selector `app: web` correcto, `minAvailable: 2`, carga por Traefik con las 6 NetworkPolicy en pie; límites abajo) · 📈 ⚠️ (el HPA reaccionó en 36 s, pero las 2 réplicas quedaron en un solo nodo y el tiempo se pasó del plan) · 🧰 ⚠️ (sin `pre` final).

**Qué salió bien**
- Elegiste el objetivo de CPU con la medición (1% = 5m; reposo 1m y 11m por Pod con carga) y no copiaste el 50% del plan, que eran 250m por Pod y nunca habría subido. Con 1% suben las dos cargas posibles (27m y 33m en total); con 2% dependía del redondeo.
- La predicción quedó guardada antes de todo y acertó 4/4, incluido «llega a 5»: el HPA pidió 6 y el máximo lo dejó en 5, como en la cuenta.
- La evidencia trae hora y comando, una línea `RESULTADO` por prueba, y el drain terminó con `uncordon`.
- El `pre` de las 13:34 listó las 6 NetworkPolicy, con `web-to-db` de 15 h: el hallazgo 3 del Día 9 queda resuelto.
- Pregunta 1: pasaste de «falla» a la mecánica real (acordona, reintenta cada 5 s, espera). Una precisión: la razón es que sacar un Pod dejaría 1 disponible y el PDB exige 2, y el `timeout=180s` es el de `prueba`; sin `--timeout`, `kubectl drain` espera indefinidamente.
- Pregunta 2: el `apply` vuelve a poner 3 y el HPA lo corrige. Se ve en `03-hpa-carga.txt`: al crear el HPA, `web` estaba en 3 y bajó a 2 a los 50 s.

**Hallazgos**
1. 🧰 **El `pre` final no corrió, y la nota subió con `??` en el commit con el tag (esto último, resuelto).** El único `pre` está en `00-seguro.txt` a las 13:34 (10:34 locales), antes de metrics-server y del HPA: el dry-run (S2) quedó ⏳ por los `___` y no se repitió, y el grep de fugas con tus valores reales (S1b) no cubre `01` a `05` ni la nota final. El commit `1a55a45` (11:55) llevaba la cabecera con `????` y todo en `??`; `722db4c` (12:17) lo corrigió y se subió. Revisé a mano los manifiestos, la evidencia y la nota y no hay valores sensibles, pero eso no reemplaza el `pre`. Se corre ahora (`bash scripts/dia-10.sh pre`: con el clúster de hoy debe dar todo ✅, dry-run incluido) y se sube con el cierre. Sin deuda.
2. 🔐 **El PDB nunca dijo que no.** `bloqueos_pdb=0`: con `web` en 5, el PDB permitía 3 evicciones (5 − 2) y el nodo tenía justo 3 Pods de `web`, así que el drain cupo exacto. El criterio 3 se cumple, pero el bloqueo de la pregunta 1 se razonó y no se vio. Además, el muestreo fue de 3 puntos en ≈7 s (cada consulta tardó más que el segundo de espera), así que el mínimo de 2 sale de pocos datos. Qué lo cerraría (opcional): `kubectl drain <worker-sin-db> --ignore-daemonsets --delete-emptydir-data --timeout=20s` con `web` en 2 réplicas y sin carga, y `uncordon` al final.
3. 🔐📈 **Lo que el PDB no cubre.** El mismo drain sacó a `metrics-server` (1 réplica, sin PDB) y a un Pod de `api` (sin PDB): hubo un lapso sin Pod de `metrics-server`. Y los 2 Pods de `web` que quedaron (`7rpbs` y `lrzrd`) figuran ambos en `lab-worker` en el listado de las 14:31: Kubernetes no rebalancea tras el `uncordon`. Sin `topologySpreadConstraints` (O3), un solo nodo caído deja `web` sin servicio, y un PDB no protege de fallos, solo de interrupciones voluntarias.

**Riesgos que se habían declarado sin probar, resueltos en el primer uso real:** `wget --header 'Host: lab.local'` de BusyBox en la imagen de `web` funcionó (CPU 3% con 2 Pods); metrics-server v0.9.1 corre en Kubernetes v1.37.0 (con `--kubelet-insecure-tls`); 6 bucles de carga bastaron para un rango válido, aunque estrecho (1% a 2%); el drain sí sacó a `metrics-server` y a `api`; `web-to-db` estaba restaurada; `prueba` duró ≈2 min y no los 6 a 9 que estimó el mentor.

**Límites del diseño (del mentor, no tuyos):** `medir` calcula el rango con los Pods que haya (3) y `prueba` arranca con 2, donde cada Pod gasta más: con un rango de 1% a 2%, su pista «hacia la mitad» no servía y hizo falta la cuenta aparte. El muestreo del drain es grueso. Y `prueba` no ejercita el caso bloqueado.

## 🏁 Cierre (2026-11-05)
- **Tiempo medido** (hora local, desde las evidencias): primer `pre` 10:34; archivo de predicción 11:09 (35'); BLANCO 1 11:14; `medir` 11:16 a 11:18; manifiesto de HPA y PDB 11:29; `prueba` 11:29 a 11:31 (≈2'); `check` 11:40; commit con tag 11:55; ajustes de la nota 12:17. Declarados 50'; de reloj 81' hasta el commit (10:34 a 11:55). Probar 55' (plan 20'); Implementar 26' (plan 25'). Son 35' entre el primer `pre` y la predicción: la cuarta vez (Día 7: 32', Día 8: 29', Día 9: 29'), aun con la ficha más corta. La pregunta de qué ocupa ese tiempo sigue sin respuesta.
- **Estado:** ✅ cerrado. Sin deuda declarada (formato A). Abiertas, sin deuda: el `pre` final (hallazgo 1), el caso bloqueado del PDB, O1 a O3 del Día 10, la pregunta del `kubectl diff` (Día 8: `db` y `lab-routes` salen `configured`), el O2 del Día 9, las deudas del Día 6 (D6-1 a D6-8) y el O2 del Día 7 (la `ClusterRole` de Traefik que lee Secrets en todo el clúster).
- **Entrega:** commits `1a55a45` (ejecución, con el tag `dia-10`, ya en el remoto) y `722db4c` (ajustes de la nota). El tag no se mueve; el cierre del mentor, el README final y el `pre` final van en un commit nuevo. Los 10 tags `dia-01` a `dia-10` están en el remoto (verificado con `git ls-remote`).
- **Calendario:** Día 10 cerrado el jue 5 nov, en su fecha. Con él termina el plan de 10 días.
