# Día 04 — Probes y recursos
**Fecha:** 2026-10-20 · **Minutos reales:** 120' (plan: 60') · **Estado:** TODO (✅ / ⚠️ parcial)

## 🎯 Objetivo medible
`web` declara cuándo está listo (readiness), cuándo hay que reiniciarlo (liveness) y cómo arrancar (startup), con requests y limits justificados. Se demuestra provocando fallos en 1 Pod: la readiness lo saca del EndpointSlice sin errores para el cliente, y la liveness lo reinicia (`RESTARTS` ≥ 2).

## 🧹 Parte 0 — estado seguro (≤ 5', obligatoria, evidencia en `evidence/dia-04/00-seguro.txt`)
Verificado por el mentor el 2026-10-20: S1, S3 y S4 ✅; S2 ❌.

| Hecho | # | Criterio | Dato |
|---|---|---|---|
| [x] | S1 | Ningún valor de contraseña en archivos trackeados ni en el índice | verificado |
| [ ] | S2 | `manifests/web-deployment.yaml` es YAML válido y sin variables de entorno ajenas a la ficha | `kubectl apply --dry-run=client`: ?? |
| [x] | S3 | `docs/.write-test` ya no está en el repo | verificado |
| [x] | S4 | Tag `dia-03` subido al remoto | verificado |

## 💳 Deuda de nivel 2 (plazo: cierre del hito; se paga o se escribe `no corregido` y el motivo)
| Deuda | Origen | Estado (pagada / no corregido / en curso) | Evidencia o motivo |
|---|---|---|---|
| 0a Digest en ejecución == digest del manifiesto | Día 1–2 | ?? | ?? |
| 0b Regla de EOL en el repo (`.gitattributes`, `.editorconfig`, hook) | Día 1–2 | ?? | ?? |
| 0c Día 2: pregunta 4 probada y evidencias 04 y 05 con antes/después (se paga con el criterio 2 de hoy) | Día 2 | ?? | ?? |
| D3-2 Archivo montado cambia sin reinicio (≤ 2 min) | Día 3 | ?? | ?? |
| D3-3 Secret: largo esperado vs. real explícito | Día 3 | ?? | ?? |
| D3-4 Login: log "ready for connections", consulta de prueba y contraseña fuera de la línea de comandos | Día 3 | ?? | ?? |
| D3-5 `gitleaks` sobre el historial | Día 3 | ?? | ?? |
| D3-6 Preguntas 1–4 y autoauditoría de la nota del Día 3 | Día 3 | ?? | ?? |

## 🧩 Predicciones (escríbelas ANTES de ejecutar; no las edites después)
**Hora en que las escribí:** ??:??
1. Readiness fallando en 1 Pod: `READY` muestra False · el EndpointSlice registra False · el cliente en bucle recibe una IP de un POD con Status READY.
2. Liveness fallando: el contador que cambia luego del reinicio es Restarts y el kubelet es el responsable de realizar las pruebas y si el contador interno llega al valor de failureThreshold, reinicia el contenedor.
3. QoS class de `web` con mis valores: actualmente sin valores la clase es BestEffort · si `requests` fuera igual a `limits`: en este caso sería Guaranteed

## ✅ Criterios (una línea por criterio)
Estado: pendiente → ✅ solo si el dato está en el archivo / ⚠️ parcial / ❌ no cumplido.

| # | Criterio | Evidencia | Estado | Dato clave a registrar |
|---|---|---|---|---|
| 1 | 3 probes y requests/limits visibles en `describe pod`; con los request y limits iguales se asegura que el pod tenga los recuersos garantizados frente a una situación de estres de recursos del nodo | `01-probes.txt` | ✅ | QoS: Guaranteed · requests: cpu=500,memory=128Mi · limits: cpu=500,memory=128Mi |
| 2 | Readiness roto en 1 Pod: `0/1`, su IP sale del EndpointSlice, el bucle de `curl` (con timestamps) no ve errores; antes/después con `-o wide`; al recuperar vuelve | `02-readiness.txt` | ✅ | Pod / IP: web-6dc4957d78-hlslt / 10.244.2.15 · peticiones: +50 · errores: 0 |
| 3 | Liveness roto en 1 Pod: `RESTARTS` ≥ 1 y eventos de falla y reinicio | `03-liveness.txt` | ✅ | `RESTARTS`: 1 · eventos clave:  Liveness probe failed: HTTP probe failed with statuscode: 503 |
| 4 | (Bonus) Arranque lento sin reinicios gracias a `startupProbe` | `04-startup.txt` | no realizado | no tuve tiempo para completarlo |
| 5 | (Bonus) Requests exagerados dejan una réplica en `Pending` y los eventos dicen por qué; revertido de forma declarativa | `05-pending.txt` | no realizado | no tuve tiempo para completarlo |

## 🔧 Diseño de la prueba de fallo (decisión tuya)
- Ruta o archivo que usa la readiness y por qué: El readiness usa el path /readiness donde fallará solo si existe /tmp/romper_readiness en el container
- Cómo provoco y cómo revierto el fallo en 1 Pod, sin editar el Deployment ni borrar el Pod: Para que falle debo crear el archivo /tmp/romper_readiness, si lo elimino se revierte el fallo.

## 🔍 Bitácora de depuración
Fue dificil encontrar una solución que permitiera probar por separado. Probé distintas alternativas manteniendo los 3 Probe apuntando a /healthz y no logré que cumpliera todas las condiciones. Hasta que generé en el ConfigMap un endpoint para cada Probe.


## ❓ Preguntas de la ficha (1–3 líneas + dónde está la evidencia)
1. ¿En qué se diferencian `Running`, `Ready` y un contenedor realmente sano? ¿Qué probe decide cada cosa?
- Running indica que el pod logró crearse con sus contenedores usando los recursos del Nodo, mientras que Ready indica si puede o no recibir tráfico.
El startupProbe verifica la inicialización del container. Sirva para contenedores con inicios pesados.
El livenessProbe verifica si hay un deadlock o un estado interno invalido cuya solución sea reiniciar la aplicación / container.
El estado Ready es controlado por el readinessProbe. Puede ser usado para dejar de recibir trafico de forma temporal.
2. ¿Qué riesgo tiene que readiness y liveness usen exactamente la misma comprobación? 
- Ya que tienen distintos objetivos el que usen la misma comprobación dificulta detectar problemas de reinicio persistente. En el caso que se quiera dejar de recibir trafico de forma temporal para que la aplicación termine sus procesos internos, el liveness tambien fallará lo que hará un reinicio forzado pudiendo matar procesamientos críticos.
3. En un rollout, ¿qué garantiza `maxUnavailable: 0` y qué garantiza una readiness correcta? ¿Qué pasaría con cada una si faltara la otra?
- maxUnavailable en cero garantiza que los pod originales continuen recibiendo trafico hasta que los nuevos pod estén disponibles (READY) mediante el readinessProbe. El readness garantiza que el nuevo pod realmente está listo para recibir tráfico. Si faltara una o la otra producirá un rollout inseguro, debido a que primero eliminará algunos pods con la consecuencia de degradar el servicio, y luego el nuevo pod comenzará a recibir tráfico y puede ser que aun no esté completamente inicializado.
4. Con tus valores, ¿qué le pasa al contenedor si supera el limit de memoria y qué si supera el de CPU?
Si supera el limite de memoria se produce un error terminal y el contenedor se reinicia. En este caso el limite de CPU no se puede superar por lo que el contenedor estará mas lento.


## 📦 Entrega
- [ ] Commit `chore:` o `fix:` de la Parte 0 (manifiesto válido), aparte del resto
- [ ] Commit `docs:` de la deuda que pagues
- [ ] Commit `feat:` del Día 4 (manifiesto, evidencias y esta nota)
- [ ] Tag `dia-04`, luego `git push` y `git push origin dia-04`
- [ ] Tres líneas para el mentor. Esperaba: ?? · Pasó: ?? · Dudas: ??

## 🔎 Revisión del mentor
**Revisado:** 2026-10-22 · **Cierre:** ⚠️ con deuda (elegido por el alumno por falta de tiempo: 120' declarados contra 60' de plan, repartidos entre el 21 y el 22 oct)

| # | Veredicto | Motivo |
|---|---|---|
| Parte 0 | ✅ | S1, S3 y S4 ✅. S2: ambos manifiestos parsean en `8baa7f2` y no hay valores de contraseña en lo commiteado; la nota aún dice `[ ]` y `00-seguro.txt` no tiene el `dry-run` |
| 1 | ⚠️ | Se ven las 3 probes, requests/limits y QoS Guaranteed, pero el `describe` es de una versión anterior (las 3 probes apuntan a `/healthz`) y el manifiesto commiteado usa `/readiness` y `/liveness`. Los valores 500m/128Mi no están justificados (solo la igualdad requests = limits) |
| 2 | ✅ | `0/1`, `Ready: false` en el endpoint, antes/después con `-o wide`, bucle con timestamps (254 respuestas 200, 0 errores) y recuperación a `1/1`. Reservas abajo |
| 3 | ⚠️ | El mecanismo se demuestra (falla de liveness, `Killing`, reinicio), pero `RESTARTS` = 1 y el criterio pide ≥ 2. La tabla de la nota dice ✅ con el dato 1, y el texto del criterio se cambió después de mi revisión de `≥ 2` a `≥ 0`. El criterio de la ficha sigue siendo `≥ 2` y el veredicto no cambia |
| 4 y 5 | — | Bonus no realizados (declarado por el alumno); no penalizan |
| Predicciones | ⚠️ | P1 acertó. P2 acertó el mecanismo, pero no previó que quedaría un solo reinicio. P3 respondió primero sobre el caso sin valores. Sin hora de escritura no se pueden verificar como previas, y falta la comparación esperaba/pasó |
| Preguntas 1–4 | ✅ / ⚠️ | Correctas en lo conceptual; ninguna cita el archivo de evidencia que la respalda |

**Ejes:** 🎯 ⚠️ · 🔐 ⚠️ · 📈 ⚠️ · 🧰 ⚠️

**Lo logrado:** falla por Pod, declarativa y sin reinicio (rutas separadas por probe + archivo bandera en `/tmp`); readiness y liveness independientes, lo que responde la pregunta 2 con experiencia propia; readiness demostrado con 0 errores durante el fallo; se mantienen digest, no-root y `maxUnavailable: 0`; nada sensible en el commit.

**Corrección del mentor:** la ficha decía que con readiness roto "la IP sale del EndpointSlice". Es impreciso: el endpoint sigue listado con `ready: false`. Tu predicción 1 y tu evidencia 02 estaban bien. Corrige esa frase en la fila del criterio 2 de tu tabla.

**Reservas del criterio 2 (no bloquean el ✅):** las horas están en zonas distintas (`ev` en -03:00, el bucle en UTC); no consta el instante del `touch` ni del `rm`; el bucle no muestra qué Pod respondió (el Pod `0/1` también responde 200 en `/`); no se indica desde dónde corre el bucle.

**Preguntas abiertas (no son deuda; se retoman en los Días 7 y 10):**
- 🔐 La palanca de falla (`/tmp/romper_*`) vive en el ConfigMap de producción: con permiso de `exec`, cualquiera puede sacar un Pod de servicio. ¿Dónde debería vivir esa lógica de prueba?
- 📈 Con 500m por réplica, ¿cuánto consume `web` realmente y qué implica para un HPA al 50%? Con una `startupProbe`, ¿para qué queda el `initialDelaySeconds: 10` de la liveness?

**Deuda registrada (qué falta · por qué · cuándo):**
- **Nivel 1, antes de empezar el Día 5 (≤ 2'):** dejar en `evidence/dia-04/00-seguro.txt` la salida de `kubectl apply --dry-run=client -f manifests/web-deployment.yaml` y marcar S2 `[x]`.
- **Nivel 2, plazo = cierre del hito (Día 5, vie 23 oct):** se paga o se escribe `no corregido` con el motivo.

| Deuda | Qué falta |
|---|---|
| D4-1 (criterio 1) | `describe pod` de un Pod actual (probes en `/readiness` y `/liveness`) y justificación de 500m/128Mi con consumo medido |
| D4-2 (criterio 3) | `RESTARTS` ≥ 2. Pregunta guía: ¿por qué el Pod se recupera solo tras el primer reinicio? |
| D4-3 (criterio 2) | Una sola zona horaria, instante del fallo y de la reversión, desde dónde corre el bucle y cómo se muestra qué Pod recibió tráfico |
| D4-4 (nota) | Hora de las predicciones, "tres líneas", fecha y estado de la cabecera, secciones 🧪 Verificación reproducible y 📚 Producción (faltan respecto de la plantilla), cada pregunta con su evidencia, y la tabla de deuda de nivel 2 (hoy en `??`) |
| Heredadas | 0a, 0b, 0c y D3-2 a D3-6 siguen abiertas. Pista: la evidencia 02 paga el formato antes/después de 0c, pero la prueba del selector (pregunta 4 del Día 2) no |

**Motivo del cierre con deuda:** falta de tiempo del alumno.

**Higiene:** `main` está un commit por delante de `origin/main`; faltan el tag `dia-04` y su push.
