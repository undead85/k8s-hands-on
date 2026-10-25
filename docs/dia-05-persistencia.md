# Día 05 — Persistencia (MySQL con PVC) y cierre del hito
**Fecha de inicio:** 2026-10-22 · **Inicio:** ??:?? · **Fin:** ??:?? · **Minutos reales:** Parte 0 ??' + deuda ??' + A ??' + B ??' + C ??' (plan: A 60' · B +30' · C +35') · **Estado:** TODO (✅ / ⚠️ parcial)
**Alcance de hoy:** TODO (A / A+B / A+C / A+B+C)

## 🎯 Objetivo medible
`db` conserva sus datos cuando muere su Pod (PVC con StorageClass `standard`): inserto 1 fila, hago `delete pod` y `SELECT COUNT(*)` = 1; luego `scale 0 -> 1` y sigue en 1. Bloque B: entiendo qué pasa con los datos al actualizar el manifiesto y al rotar el Secret. Bloque C: borro el namespace `lab` y lo recreo todo con un solo comando documentado.

## 🧹 Parte 0 — estado seguro (≤ 5', obligatoria, evidencia en `evidence/dia-05/00-seguro.txt`)
| Hecho | # | Criterio | Dato |
|---|---|---|---|
| [x] | S1 | Ningún valor de contraseña en archivos trackeados ni en el índice | `gitleaks dir`: 0 leaks found |
| [x] | S2 | Los manifiestos que aplico hoy son YAML válido; y dejé el `dry-run` de `web-deployment.yaml` en `evidence/dia-04/00-seguro.txt` | `kubectl apply --dry-run=client`: dry-run ok: web (Día 4) y manifests/ (Día 5 |
| [x] | S3 | Ninguna evidencia ni nota de hoy contiene el valor del Secret | revisado: ok, grep -rlF sobre evidence, docs y manifests: limpio |
| [x] | S4 | Día 4 entregado: commit `fabe119` y tag `dia-04` en el remoto | verificado por el mentor el 2026-10-22 |

## 💳 Declaración de deuda de nivel 2 (hoy vence el plazo; una sola tabla para todos los días)
Cada fila: `pagada` (con enlace a la evidencia) o `no corregido` (con el motivo). Lo que no se pague ni se declare pasa al README como limitación conocida.

| Deuda | Origen | Estado (pagada / no corregido) | Evidencia o motivo |
|---|---|---|---|
| 0a Digest en ejecución == digest del manifiesto | Día 1–2 | pagada | evidence/dia-01/01-deploy-ready.txt |
| 0b Regla de fin de línea en el repo (`.gitattributes`, `.editorconfig`, hook) | Día 1–2 | no corregido | sin tiempo; hoy priorizo persistencia y el cierre del hito |
| 0c Prueba del selector (pregunta 4 del Día 2) | Día 2 | no corregido | sin tiempo |
| D3-2 Archivo montado cambia sin reinicio (≤ 2 min) | Día 3 | no corregido | sin tiempo |
| D3-3 Secret: largo esperado vs. real | Día 3 |  no corregido | sin tiempo |
| D3-4 Login: log "ready for connections", consulta de prueba y contraseña fuera de la línea de comandos (se paga con los criterios 2 y 3) | Día 3 | pagado | se paga sola |
| D3-5 `gitleaks` sobre el historial | Día 3 | pagado | evidence/dia-05/00-seguro.txt |
| D3-6 Preguntas 1–4 y autoauditoría de la nota del Día 3 | Día 3 | no corregido | sin tiempo |
| D4-1 `describe pod` actual y valores 500m/128Mi justificados | Día 4 | no corregido | sin tiempo |
| D4-2 Liveness con `RESTARTS` ≥ 2 | Día 4 | no corregido | sin tiempo |
| D4-3 Reservas del criterio 2 (zona horaria, instantes, quién respondió) | Día 4 | no corregido | sin tiempo |
| D4-4 Nota del Día 4 (hora de predicciones, tres líneas, 🧪 y 📚, preguntas con evidencia) | Día 4 | no corregido | sin tiempo |

## 🧩 Predicciones (escríbelas ANTES de ejecutar; no las edites después)
**Hora en que las escribí:** 17:28
1. Borro el Pod de `db` con el PVC montado. La fila y el nodo del Pod nuevo: apuesto a que no se pierde la fila porque al borrar el pod el volume persiste y se monta al nuevo pod.
2. Aplico un cambio al template de `db`. El orden entre el Pod viejo y el nuevo, y el log del nuevo: no lo sé porque aun no tengo claro el cambio al template.
3. Cambio el Secret y reinicio `db` con el volumen ya inicializado. La contraseña que acepta el servidor: apuesto a la antigua porque el volume persiste.
4. (Bonus) Borro el PVC. Lo que pasa con el PV y con la fila: apuesto a que se elimina el PV porque tiene la politica de retencion delete.

## 🔧 Decisiones de diseño (tuyas; documéntalas antes de aplicar)
- Opción elegida (A Deployment + PVC / B StatefulSet) y por qué: Opción A para probar una BD con una sola réplica
- Estrategia de actualización de `db` y por qué: se prueba con estrategia rollingUpdate y también con Recreate.
- Tamaño y modo de acceso del PVC y por qué: 20Mi sirven para una pequeña prueba (1 db, 1 tabla, 1 registro).
- Cómo consulto la base sin que la contraseña salga en mi línea de comandos ni en la salida: a la BD se le pasa una variable de entorno local, esta última es seteada con un get al Secret decodificado.
- (Bloque C) Mi comando único de recreación y cómo maneja el Secret sin guardarlo: son 3 comandos (namespace, secret y todo lo demas). Se puede generar un script.

## ✅ Criterios (una línea por criterio)
Estado: pendiente → ✅ solo si el dato está en el archivo / ⚠️ parcial / ❌ no cumplido / no realizado.

| # | Bloque | Criterio | Evidencia | Estado | Dato clave a registrar |
|---|---|---|---|---|---|
| 1 | A | PVC `Bound` con StorageClass `standard`; PV con claim, `reclaimPolicy` y nodo | `01-pvc.txt` | ✅ | tamaño: 20Mi |
| 2 | A | `db` monta el PVC; log "ready for connections" y consulta de prueba, sin contraseña a la vista | `02-arranque.txt` | ✅ | busca la línea 'ready for connections'  |
| 3 | A | 1 fila; `delete pod`; `COUNT(*)` = 1; nodo y hora antes/después | `03-delete-pod.txt` | ✅ | nodo antes/después: lab-worker2 · COUNT: 1 |
| 4 | A | `scale 0 -> 1`: PVC `Bound` con 0 réplicas y `COUNT(*)` = 1 al volver | `04-scale.txt` | ✅ | PVC con 0 réplicas: sigue Bound |
| 5 | B | Cambio de template sin dos instancias usando el mismo volumen | `05-rollout.txt` | ✅ | se registra los eventos con la estrategia Recreate y luego con la estrategia RollingUpdate |
| 6 | B | Rotación con datos: qué contraseña acepta el servidor tras cambiar el Secret | `06-rotacion.txt` | ✅ | acepta: la antigua ya que persiste en el volume |
| 7 | C | `README.md` + recreación del namespace con un solo comando; `web` 3/3 y `db` Ready; Secret fuera del repo | `07-recreacion.txt` | parcial cumplido por tiempo | tiempo hasta Ready: varios segundos |
| 8 | Bonus | `reclaimPolicy`: qué pasa con PV y datos al borrar el PVC | `08-reclaim.txt` | no realizado | por falta de tiempo |


## ❓ Preguntas de la ficha (1–3 líneas + dónde está la evidencia)
1. ¿Qué diferencia hay entre el ciclo de vida de un Pod y el de un PVC o un PV? ¿Qué objeto "posee" el dato y qué lo borra?
El pod es controlado por el deployment mientras que el pv es controlado por el PVC.
2. Con un volumen que solo admite un escritor y una sola réplica, ¿qué riesgo tiene actualizar `db` con tu estrategia? ¿Qué cambiaría con la otra opción de diseño?
Con rollingUpdate puede haber mas de un pod intentando acceder al volume. Mientras que con Recreate se elimina primero el pod y luego levanta el nuevo.
3. ¿Por qué cambiar `MYSQL_ROOT_PASSWORD` no cambia la contraseña de un MySQL que ya tiene datos? ¿Cómo harías una rotación real, en qué orden y sin perder el acceso?
Mysql setea la clave de root al inicializar el volume, para que tome la nueva contraseña que ya vive en el secreto, falta editar dentro de mysql con un ALTER USER.
4. ¿En qué nodo vive el dato y qué le implica eso al scheduler? ¿Qué pasaría si ese nodo se pierde?
El dato vive en el nodo donde fue creado el pvc y el pod, por lo tanto el scheduler siempre intentará crear el pod en ese mismo nodo. Si el nodo se pierde tambien se pierde el dato.

```

## 📦 Entrega
- [ ] Commit `chore:` o `fix:` de la Parte 0 (dry-run de S2 en la evidencia del Día 4 y `00-seguro.txt` de hoy)
- [ ] Commit `docs:` de la declaración de deuda
- [ ] Commit `feat:` del Día 5 (manifiestos, evidencias y esta nota)
- [ ] Commit `docs:` del README (si hiciste el bloque C)
- [ ] Tag `dia-05`, luego `git push` y `git push origin dia-05`
- [ ] Tres líneas para el mentor. Esperaba: ?? · Pasó: ?? · Dudas: ??

## 🔎 Revisión del mentor
**Revisado:** 2026-10-25 · **Veredicto: ⚠️ cerrar con deuda** — A ✅ (con reservas de evidencia) · B ⚠️ (el 5 contradice tu manifiesto; el 6 ✅ con reserva) · C ⚠️ (README ✅, comando único ❌, Ready sin medir) · Bonus: no realizado (declarado).

> ⚠️ Antes de leer esto en GitHub: en la línea 73 de esta nota queda una ``` suelta (el cierre del bloque 🧪 que quitaste). Mientras no la borres, todo lo que sigue se ve como código.

### Veredicto por criterio (horas en UTC)
| # | Tu estado | Mi veredicto | Evidencia que lo sostiene |
|---|---|---|---|
| 1 | ✅ | ✅ | `01-pvc`: `Bound`, `standard`, 20Mi, RWO; PV con claim `lab/db-pvc`, `Reclaim Policy: Delete` y afinidad a `lab-worker2`. Tu «Dato clave» trae solo el tamaño: agrega acceso, política y nodo. |
| 2 | ✅ | ✅ | `02`: «ready for connections» a las 15:19:38 y `show databases` a las 15:44:45. En «Dato clave» va la línea del log (o su hora), no «busca la línea…». |
| 3 | ✅ | ✅ con reserva | `03`: Pod `qn928` (51 min) → `ws5hc` (23 s), ambos en `lab-worker2`, `1/1` a las 16:11:19; `COUNT(*)` = 1 a las 16:12:13. La fila (`creado` 16:09:08) se ve antes del `delete`, no después: está probado el conteo, no la identidad de la fila. |
| 4 | ✅ | ✅ con reserva | `04`: `scale 0` 16:16:09, PVC `Bound` 16:16:35, `scale 1` 16:17:07, `COUNT(*)` = 1 a las 16:17:27. Falta un `get pods` o `get deploy` que muestre las 0 réplicas en ese momento. |
| 5 | ✅ | ⚠️ | `05`: con `Recreate`, viejo `Completed` 16:43:53 y nuevo `Running` 16:43:54 (sin solape). Con `RollingUpdate`, nuevo `Running` 16:46:39 y viejo `Completed` recién a las 16:46:43: ≈4 s con dos Pods sobre el mismo PVC. El criterio dice «nunca dos» y tu `db-deployment.yaml` termina en `RollingUpdate`. |
| 6 | ✅ | ✅ con reserva | `06`: tras el reinicio entra `$VIEJA` (17:29:27, y sigue la base `k8s`) y `$NUEVA` da `ERROR 1045` (17:30:43). `$AZAR` también falla (17:22:11) y sirve de control. El log del Pod nuevo (17:28:11–17:28:22) no muestra inicialización. Tu predicción 3 acertó. Reserva: R4. |
| 7 | «parcial cumplido por tiempo» | ⚠️ | `07`: README ✅. Secret por stdin, sin valor en el archivo ✅. Estado final (19:00:26–19:00:37): `web` 3 × `1/1 Running`, `db` `1/1 Running`, PVC `Bound`. Pero son 3 comandos (18:59:07, 18:59:18, 19:00:06), no uno; el tiempo es «unos 20 s» leído de `AGE`, no medido hasta Ready; y `db` no tiene probe, así que `1/1` no prueba que MySQL acepte conexiones. «Parcial cumplido por tiempo» no es un estado válido: es ⚠️. |
| 8 | no realizado | no realizado | Declarado. Ya tienes `Reclaim Policy: Delete` en `01`; falta la prueba. |

### Ejes
- 🎯 **Objetivo:** persistencia (A) y rotación con datos (6) demostradas con tus propias evidencias, y encontraste por tu cuenta lo más útil del 6: el log del reinicio no inicializa nada. C quedó a medias.
- 🔐 **Seguridad:** ningún valor de contraseña en las evidencias que revisé (las líneas `$` traen referencias a variables) y el Secret de `07` viaja por stdin. Reservas: `--env=MYSQL_PWD=$VAR` deja el valor en los argumentos locales de `kubectl` y en el spec del Pod efímero (pregunta abierta desde el Día 3, ya en el README); y las líneas 726–727 y 732–733 de tu `history` (`env`, `env | grep MYSQL`) imprimen `MYSQL_PWD` en pantalla. No quedó en archivos.
- 📈 **Escalabilidad / fallos:** el dato sobrevive a `delete pod` y a `scale 0 → 1`. Pero `db` tiene `RollingUpdate` con volumen RWO, una réplica y sin probes (dos solapes vistos: 16:46:39–16:46:43 y 17:28:12), el PVC pide 20Mi y el dato vive en un solo nodo.
- 🧰 **Reproducibilidad:** el README existe y es verificable; la recreación sigue siendo de 3 pasos y los tiempos de `07` no llegan hasta Ready. Las consultas SQL no quedan en las evidencias (R1).

### Lo que está bien
- `07` conserva los intentos fallidos (17:43 con `namespaces "lab" not found`; 18:40 con `db` en `CreateContainerConfigError`). Eso explica por qué el orden importa.
- En `06`: control negativo con `$AZAR` y `resourceVersion` del Secret antes y después.
- El `history` en `02` para mostrar que la contraseña no está en el historial es buena idea.
- La tabla de deuda está completa y honesta (9 filas `no corregido`). La pregunta 3 está bien razonada.

### Correcciones a tu nota
- Borra la ``` suelta de la línea 73.
- Estados válidos: ✅ / ⚠️ / ❌ / no realizado (criterio 7).
- «Dato clave» pendiente: criterio 1 (acceso, política, nodo), 2 (hora del log), 3 y 5 (orden con horas), 7 (comando y tiempo).
- Encabezado: Fin, minutos, Estado y Alcance. Entre la primera evidencia de criterios (15:14) y la última (19:00) pasaron 3 h 46 min de reloj: cuenta tiempo activo por bloque. Fecha: inicio 2026-10-22 (Parte 0), cierre 2026-10-25.
- Predicciones: «17:28» sin fecha ni zona. Agrégalas. La 2 es un «no lo sé»: compárala con lo que viste en `05`.
- Quitaste 🔍 Bitácora y 🧪 Verificación reproducible. La ficha las pide, y tuviste varios intentos que contar (orden del `apply`, `ev` con `time`, rotación).
- Preguntas 1–4: ninguna cita archivo y hora (la ficha lo exige). Ver «Preguntas abiertas».

### Reservas
- **R1.** El `<<< "consulta"` es una redirección de tu shell, no parte de `$*`: `ev` no la imprime. En `03`, `04` y `06` se ven resultados sin la consulta, y en `06` de las 17:21:48 no se ve ninguna salida.
- **R2.** Las líneas `$` de `02`–`06` muestran `--env=MYSQL_PWD=$MYSQL_PWD` sin expandir. Con el `ev` que te di, tu shell expande la variable antes de que `ev` imprima `$*`.
- **R3.** `05` no se capturó con `ev`: sin comandos, sin `# fecha`, con «strategy: …» escrito a mano. No consta qué cambio de template provocó cada rollout. Las horas son UTC (se deduce de la edad del Pod en `06`).
- **R4.** En `06` no está el comando que cambió el Secret: solo `resourceVersion` 908523 → 909893 (17:26:57). Hay una tercera, 910567 (17:33:12), después de la prueba, sin explicación.
- **R5.** El `dry-run` de S2 es del 22 oct, antes de que existieran `db-pvc.yaml` y la versión final de `db-deployment.yaml` (la salida lista 7 objetos, sin PVC). Y `web configured (dry run)` sigue sin explicación.

### Preguntas abiertas (responde en la nota; no te doy la solución)
1. **Estrategia (criterio 5).** Tu evidencia `05` muestra ≈4 s con dos Pods sobre el mismo PVC. ¿Con qué estrategia queda el `db-deployment.yaml` que vas a commitear? ¿Qué debería decir tu 🔧 «Estrategia» si decides lo que demuestra tu evidencia? Pista (Nivel 1): `kubectl explain deployment.spec.strategy.type`, y mira qué hace cada valor con un volumen RWO.
2. **20Mi.** Dices que sirven. ¿Cuánto ocupa `/var/lib/mysql` en un MySQL recién inicializado (`du -sh`, sin credenciales)? Si «sirve» con 20Mi, ¿qué te dice eso del provisioner de kind? ¿Qué pasaría con la misma petición en uno que sí hace cumplir la capacidad? ¿Dónde justificaste RWO?
3. **R2.** ¿Qué hiciste para que la variable quedara sin expandir en el archivo (cambiaste `ev`, usaste comillas, editaste a mano)? Cualquiera es válido si queda dicho en la bitácora; el archivo no puede decir algo distinto de lo que se ejecutó. Y de paso: ¿qué comando te dice que `MYSQL_PWD` existe sin mostrar su valor?
4. **Pregunta 1 de la ficha.** Dices que el PV «es controlado por el PVC». Mira `01`: ¿quién aprovisionó el PV y qué política decide su destino cuando se borra el PVC? En `07` borraste el namespace: ¿qué dato de `get pvc` de las 19:00:37 te dice que `db` arrancó con un volumen nuevo?
5. **Preguntas 2–4.** Agrega archivo y hora. Para la 2: ¿un StatefulSet crea el Pod nuevo antes de borrar el viejo, o al revés? Para la 3: ¿qué cambias primero, el Secret o la contraseña dentro de MySQL, y con qué credencial entras en cada paso? Para la 4: si `lab-worker2` no está disponible, ¿en qué estado queda el Pod nuevo y qué evento lo dice?
6. **📚 Producción.** Con `replicas: 2` en un StatefulSet de MySQL, ¿las dos réplicas comparten datos? ¿Qué falta para que dos instancias sean una base replicada? ¿Qué harías en producción por disponibilidad y respaldo?

### Deuda: revisión de tu tabla
| Fila | Mi veredicto |
|---|---|
| 0a | ❌ La evidencia no lo respalda. `IMAGES` de `get deploy -o wide` es lo que declaraste en el Deployment, no lo que corre. ¿Qué campo de `status` del **Pod** guarda el digest real? Págala (≈2') o cámbiala a `no corregido`; si la cambias, el README suma una fila en «Limitaciones». |
| D3-4 | ⚠️ Pagada en parte: log y consulta sí (`02`, `03`); «contraseña fuera de la línea de comandos» no, por R2 y el patrón `--env`. Enlaza `02-arranque.txt` y `03-delete-pod.txt` en vez de «se paga sola» y deja esa parte en Limitaciones. |
| D3-5 | ✅ `gitleaks git`, 11 commits, sin fugas (`00-seguro`, 22 oct 20:20). |
| Las otras 9 | Acepto `no corregido`. D3-3 cuesta ≈2'. Nota viva de 0b: `db-deployment.yaml` y `db-pvc.yaml` están en CRLF en el disco (el resto en LF); tu Git los normaliza al hacer `add`. |

Filas nuevas que debes declarar o pagar (costos: estimaciones mías):
| Deuda | Qué | Costo aprox. |
|---|---|---|
| D5-1 | Criterio 5: alinear la estrategia de `db` con lo que demostraste (y el manifiesto con la evidencia) | ≈5' |
| D5-2 | Criterio 7: comando único documentado y tiempo medido hasta Ready (incluye cómo sabes que `db` aceptó conexiones) | ≈35' (10' investigar · 10' probar · 15' implementar) |
| D5-3 | Criterio 8 (bonus): `reclaimPolicy` | ≈15' |
| D5-4 | Reservas R1–R5, bitácora, 🧪 y preguntas con evidencia | ≈20' |

### Antes del tag (Nivel 1, obligatorio, ≤5')
- [ ] `grep -rlF -f <(printf '%s\n' "$MYSQL_PWD") README.md evidence docs manifests` → vacío. Repítelo con `$VIEJA`, `$NUEVA` y `$AZAR` si siguen en tu sesión.
- [ ] `gitleaks dir` sobre los archivos nuevos (README, evidencias 02–07, esta nota). Tu `00-seguro.txt` es del 22 oct.
- [ ] Borrar la ``` suelta de la línea 73.

## 📚 Qué haría distinto en producción
la estrategia sería usar un StatefulSet para poder escalar las réplicas.
