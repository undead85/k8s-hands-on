# Día 06 — Exposición HTTP (Gateway API con Traefik)
**Fecha de inicio:** 2026-10-26 · **Inicio:** ??:?? · **Fin:** ??:?? · **Minutos reales:** Parte 0 ??' + A ??' + B ??' + C ??' (plan: A 75' · B +30' · C +25') · **Estado:** ⚠️ cerrado con deuda (cierre del mentor, 2026-10-29)
**Alcance de hoy:** A (criterios 1–4); B, C y bonus no realizados (lo fijó el mentor al cerrar: el alumno no lo declaró)

## 🎯 Objetivo medible
`curl -H "Host: lab.local" http://127.0.0.1/` da 200 con contenido de `web`; `/api` va a otro backend; un host desconocido da 404 generado por el controlador. Todo a través de un `Gateway` y `HTTPRoute` atendidos por Traefik, con los CRDs de Gateway API y el controlador fijados por versión. Bloque B: entiendo qué hace el controlador con un Pod no listo y con un Service sin endpoints. Bloque C: borro el namespace `lab` y recreo todo, con lo de hoy, siguiendo el README.

## 🧹 Parte 0 — estado seguro (≤ 5', obligatoria, evidencia en `evidence/dia-06/00-seguro.txt`)
| Hecho | # | Criterio | Dato |
|---|---|---|---|
| [ ] | S1 | Ningún valor de contraseña en archivos trackeados ni en el índice (`gitleaks dir`) y `grep -rlF` con los valores reales de `$MYSQL_PWD`, `$VIEJA`, `$NUEVA` y `$AZAR` | no leaks found |
| [ ] | S2 | Los manifiestos que aplico hoy son YAML válido (`kubectl apply --dry-run=client`; los de Gateway API y Traefik solo se validan así con sus CRDs ya instalados: anotarlo) | ?? |
| [ ] | S3 | Ninguna evidencia ni nota de hoy contiene secretos | ?? |
| [x] | S4 | Día 5 entregado: commit `b867879` y tag `dia-05` en el remoto | verificado por el mentor el 2026-10-26 |
| [ ] | S5 | Clúster al empezar: 3 nodos Ready, `lab` con `web` 3/3 y `db` Running, puertos 80 y 443 publicados en `127.0.0.1` | ?? |

## 🧩 Predicciones (escríbelas ANTES de ejecutar; no las edites después)
**Hora, fecha y zona en que las escribí:** ??:?? · ????-??-?? · ??
1. Pido `/` con `Host: otro.local`. El status y quién responde: TODO
2. Pido `/api/usuarios` y `/apix` con mi `path.type`. A qué backend va cada una: TODO
3. Rompo la readiness de 1 Pod de `web`. Si recibe tráfico por el Gateway: TODO
4. Escalo `api` a 0 réplicas. Qué devuelve `/api` y qué devuelve `/`: TODO

## 🔧 Decisiones de diseño (tuyas; documéntalas antes de aplicar)
- Versión de Traefik (chart y app) y versión de los CRDs de Gateway API, y por qué esas (compatibilidad entre sí y con mi servidor v1.37.0):
el chart usa la versión 42.1.3, compatible con el Gateway API v1.6.3, Traefik v3.7.16
- Instalo Traefik con un kubectl apply por qué así quedan las configuraciones en los manifiestos para revisarlos.
- Qué objetos crea (namespace, ServiceAccount, ClusterRole y qué recursos puede leer, en especial Secrets; CRDs propios; Service; puertos del nodo), leído antes de aplicar: crea los objetos en un nuevo namespace "traefik".
- Proveedores activos y desactivados (Gateway API sí; Ingress y CRDs propios: no) y por qué: No se usarán ingress en este proyecto.
- Dónde vive cada cosa y en qué orden se aplica (A todo en `manifests/` / B carpeta aparte / C Kustomize) y por qué: todo como manifests.
- Dónde vive el `Gateway` y qué `allowedRoutes` permite (`Same` / `Selector` / `All`) y por qué: el Gateway vive en el namespace traefik y permite enrutar mediante `Selector` el namespace 'lab'
- `path.type` de `/api` y por qué: TODO
- Imagen de `api` y por qué (qué responde, quién la mantiene, con qué usuario corre): TODO

## ✅ Criterios (una línea por criterio)
Estado: pendiente → ✅ solo si el dato está en el archivo / ⚠️ parcial / ❌ no cumplido / no realizado.

| # | Bloque | Criterio | Evidencia | Estado | Dato clave a registrar |
|---|---|---|---|---|---|
| 1 | A | CRDs y controlador listos; `GatewayClass` `Accepted`; `Gateway` `Programmed`; imagen en ejecución == tag y digest del manifiesto | `01-controlador.txt` | pendiente | versión Traefik: ?? · versión CRDs: ?? · nodo: ?? · imagen en ejecución: ?? |
| 2 | A | `/` con `Host: lab.local` da 200 desde `web`; qué Pod respondió; `HTTPRoute` con `Accepted` y `ResolvedRefs` | `02-web.txt` | pendiente | Pod: ?? |
| 3 | A | `/api` va a `api`; `/` sigue en `web`; `/api/usuarios` y `/apix` | `03-api.txt` | pendiente | resultado por ruta: ?? |
| 4 | A | Host desconocido da 404 del controlador, con la prueba | `04-404.txt` | pendiente | cuerpo exacto: ?? |
| 5 | B | Readiness roto en 1 Pod de `web`: bucle sin errores por el Gateway | `05-readiness.txt` | pendiente | provocar/revertir (UTC): ?? |
| 6 | B | `api` en 0 réplicas: error del controlador en `/api`, `/` en 200; condiciones de la `HTTPRoute` | `06-sin-endpoints.txt` | pendiente | status: ?? |
| 7 | C | Recreación del namespace con README + lo de hoy; 200 en `/` y `/api`; qué sobrevive al borrado | `07-recreacion.txt` | pendiente | comandos: ?? · tiempo hasta el 1.er 200: ?? |
| 8 | Bonus | HTTPS con certificado autofirmado en un listener del `Gateway`, llave fuera del repo | `08-tls.txt` | pendiente | ?? |
| 9 | Bonus | Deuda D5-2: comando único y tiempo hasta Ready | `09-comando-unico.txt` | pendiente | ?? |

## 🔍 Bitácora de depuración
| # | Intento o hipótesis | Comando | Resultado | ¿Descartado? |
|---|---|---|---|---|
| 1 | TODO | TODO | TODO | TODO |

## ❓ Preguntas de la ficha (1–3 líneas + dónde está la evidencia)
1. ¿Qué diferencia hay entre `GatewayClass`, `Gateway`, `HTTPRoute` y el controlador? ¿Qué pasa si aplicas una `HTTPRoute` antes de instalar los CRDs, y qué si aplicas un `Gateway` con una `gatewayClassName` que no existe?
TODO — evidencia: ??
2. ¿Por qué `127.0.0.1:80` llega al controlador en kind? Sigue el camino desde tu máquina hasta el Pod del controlador, e indica qué puerto del contenedor atiende el listener.
TODO — evidencia: ??
3. ¿El controlador manda el tráfico a la ClusterIP del Service o a las IPs de los Pods? ¿Qué te lo demuestra?
TODO — evidencia: ??
4. ingress-nginx está retirado y migré a Traefik con Gateway API: ¿qué costó hoy y qué costaría con 100 Ingress? ¿Cuándo usaría el proveedor de compatibilidad con ingress-nginx y cuándo no? ¿Qué riesgo hay en depender de nombres generados que cambian entre parches?
TODO — evidencia: ??

## 🧪 Verificación reproducible
```bash
# 1) Pasos para recrear todo, con lo de hoy y en orden (CRDs -> controlador -> namespace -> Secret -> manifests): TODO
# 2) Cómo compruebo que el controlador, la GatewayClass, el Gateway y los backends están listos: TODO
# 3) Cómo compruebo cada ruta (/, /api, host desconocido): TODO
```

## 💳 Deuda del día (lo que no pagues hoy, con el motivo)
*Declarada por el mentor al cerrar: el alumno no completó esta sección. Lo que no se pague y no esté aquí pasaría al README.*

| Deuda | Estado (pagada / no corregido) | Evidencia o motivo |
|---|---|---|
| D6-1 Predicciones: 1 y 2 sin escribir antes de ejecutar; 3 y 4 sin escribir | no corregido | No se reconstruyen a posteriori; la 3 y la 4 dependen del bloque B |
| D6-2 Criterio 1: lectura de la ClusterRole y de los objetos que crea Traefik, `diff` del re-render y comprobación del `appVersion` | no corregido | Sin tiempo al cerrar. Ver «Dato del render para el Día 7» |
| D6-3 Criterio 2: qué Pod de `web` respondió y desde dónde corre el `curl` | no corregido | Sin tiempo al cerrar |
| D6-4 Criterios 3 y 4: explicación con `path.type` y prueba escrita de que el 404 no viene de `web`; decisiones `path.type` e imagen de `api` en TODO | no corregido | Sin tiempo al cerrar |
| D6-5 Bloque B (criterios 5 y 6): sin evidencia del eje 📈 | no corregido | Cerrado antes de hacerlo |
| D6-6 Bloque C (criterio 7) y bonus 8 (TLS) y 9 (comando único): recreación con la infra sin probar; D5-2 sigue abierta | no corregido | Cerrado antes de hacerlo |
| D6-7 Parte 0: S2, S3 y S5 sin registro (S2 y S3 los comprobó el mentor el 29 oct); S1 solo cubre el valor vigente del Secret | parcial | Las contraseñas anteriores no se pueden comprobar: sus variables ya no existen en la sesión |
| D6-8 Nota: horas y minutos, bitácora, preguntas 1–4, 🧪, 📚, tres líneas y los estados de la tabla de criterios | no corregido | Sin tiempo al cerrar |

## 📦 Entrega
- [ ] Commit `chore:` o `fix:` de la Parte 0 (`00-seguro.txt` de hoy)
- [ ] Commit `feat:` del Día 6 (manifiestos, evidencias y esta nota)
- [ ] Commit `docs:` del README (paso nuevo y su orden, versiones de Traefik y de los CRDs de Gateway API)
- [ ] Tag `dia-06`, luego `git push` y `git push origin dia-06`
- [ ] Tres líneas para el mentor. Esperaba: ?? · Pasó: ?? · Dudas: ??

## 🔎 Revisión del mentor

*Revisión y cierre del mentor, 2026-10-29. La tabla de criterios, la Parte 0 y las predicciones quedaron como las dejó el alumno (`pendiente`, sin marcar y en blanco): el veredicto es el de esta sección. Horas en UTC.*

### Veredicto por criterio

| # | Veredicto | Qué muestra la evidencia y qué falta |
|---|---|---|
| Parte 0 | ⚠️ | S1 ✅ para el valor vigente del Secret: el `grep -rlF` salió con `exit=1` (12:59) y `gitleaks dir` no halló fugas (13:01); las contraseñas anteriores no se pudieron comprobar. `gitleaks git` (13 commits) corrió antes del commit `7694651`, así que ese commit no está cubierto. S2 y S3 ✅ por el mentor el 29 oct (los 15 YAML parsean; en lo nuevo solo hay referencias a Secrets, ningún valor). S4 ✅. S5 sin registro: `00-seguro.txt` solo contiene S1 |
| 1 | ✅ con reserva | Pod `traefik` `1/1 Running` en `lab-control-plane`, `GatewayClass` `Accepted: True` y `Gateway` `Programmed: True` (22:31). El `imageID` en ejecución es el digest `1336e85a…` del manifiesto (22:35). CRDs v1.6.3, canal estándar: 10 CRDs más una `ValidatingAdmissionPolicy` y su binding (`01`). Reserva: la nota no muestra que se leyó la ClusterRole antes de aplicar (la ficha pide qué puede leer, en especial Secrets) y no hay evidencia del `diff` del re-render ni del `appVersion` del chart |
| 2 | ⚠️ | `/` con `Host: lab.local` da 200 con la página de nginx 1.31.6 (23:46:46) y la `HTTPRoute` tiene `Accepted` y `ResolvedRefs` en `True` (23:46:54). Faltan dos datos que pide el criterio: qué Pod de `web` respondió y desde dónde corre el `curl` |
| 3 | ✅ con reserva | `/api` y `/api/usuarios` dan 200 desde `api` con Pods distintos (`…g8h8r` y `…xnh6q`) y `/` sigue en `web` (criterio 2). `/apix` da 404 **de nginx**: no coincide con `/api`, cae en la regla `/` y va a `web`. Reserva: el criterio pide explicar el resultado con tu `path.type` y la decisión 4 sigue en TODO |
| 4 | ✅ con reserva | Host desconocido y petición sin host útil dan `404 page not found` (19 bytes, `text/plain`, `X-Content-Type-Options: nosniff`, sin cabecera `Server`), distinto del 404 de nginx de `03` (HTML, `Server: nginx/1.31.6`). Reserva: la comparación no está escrita; la «prueba de que no viene de `web`» hay que decirla |
| 5–6 | no realizado | Sin predicciones 3 y 4 ni evidencia: el eje 📈 de hoy queda sin demostrar |
| 7 | no realizado | No se probó recrear con lo de hoy. Los pasos de infra del README son el orden que se aplicó el 28 oct, no una recreación desde cero |
| 8–9 | no realizado | La deuda D5-2 (comando único) sigue abierta |

**Ejes:** 🎯 ⚠️ · 🔐 ⚠️ · 📈 ⚠️ · 🧰 ⚠️

- 🎯 Los criterios 1 a 4 están en evidencia; los bloques B y C no se hicieron y la nota quedó sin completar.
- 🔐 La configuración es buena (versión y digest fijos y comprobados en ejecución, sin root, `seccomp: RuntimeDefault`, `drop: ALL`, `readOnlyRootFilesystem`, solo el proveedor de Gateway API, `allowedRoutes` con `Selector` solo para `lab`, puertos solo en loopback). Falta la lectura documentada de la ClusterRole y la prueba negativa de `allowedRoutes`.
- 📈 Bloque B sin hacer. Traefik corre con 1 réplica y `hostPort` (preset del mentor): es un único punto de entrada, en un solo nodo.
- 🧰 Recreación sin probar, README sin actualizar hasta este cierre, nota en estado de plantilla y comandos que no se pueden copiar de las evidencias.

### Qué salió bien

- La evidencia 01 compara el digest del manifiesto con el `imageID` que dice el `status` del Pod, que es lo que pedía la ficha y lo que la deuda 0a nunca logró.
- Corregiste `sha256:sha256` en `values.yaml` (22:38) y el manifiesto renderizado tiene la referencia correcta.
- `api` sigue las mismas prácticas que `web`: tag y digest, sin root, seccomp, rootfs de solo lectura, probes y `requests` = `limits`.
- En `03` y `04` quedan lado a lado dos 404 de origen distinto, que es la mejor prueba del criterio 4.
- El `grep` de la Parte 0 lee el Secret sin imprimir su valor.

### Hallazgos y correcciones

- **R1. Predicciones.** Siguen en blanco (la nota se guardó por última vez el 28 oct a las 22:49; la `HTTPRoute` se creó a las 23:38). Las predicciones 1 y 2 ya no pueden ser apuestas previas y las 3 y 4 nunca se escribieron porque el bloque B no se hizo. No se reconstruyen después.
- **R2. Parte 0.** Faltan S2, S3 y S5 en `00-seguro.txt`. El `bash -c 'gitleaks git | gitleaks dir'` se ve en el archivo como una tubería: para dos escaneos independientes usa `;`. Las contraseñas anteriores no se pudieron comprobar porque las variables ya no estaban en la sesión.
- **R3. Criterio 1.** Anota qué objetos crea Traefik (ServiceAccount, ClusterRole y ClusterRoleBinding, Service, Deployment, `GatewayClass`) y qué puede leer. La decisión «Instalo con un `kubectl apply`» no nombra la opción B (`helm template` y luego `apply`), ni marca como «preset del mentor, 28 oct» lo que fijó el mentor (1 réplica, `hostPort`, Service `ClusterIP`, `Gateway` aparte).
- **R4. Criterio 2.** `nginx` no se identifica en la respuesta. ¿Dónde deja nginx el rastro de cada petición y qué Pod lo tiene?
- **R5. Criterios 3 y 4.** Falta escribir por qué `/apix` va a `web`, qué `path.type` elegiste y por qué, y qué dos diferencias tiene el 404 de Traefik frente al de nginx.
- **R6. Evidencias.** `ev` imprime `$*` sin comillas (`-H Host: lab.local`, `bash -c grep …`), así que las líneas `$` no se pueden copiar: usa `printf '$'; printf ' %q' "$@"; echo`. En `01` la primera ejecución de los CRDs figura `unchanged` (la primera salida, con `created`, no quedó) y hay 56 minutos entre el `apply` de Traefik (21:35) y el del Gateway (22:31) que la bitácora no explica.
- **R7. Nota y commit.** El commit `7694651` (29 oct, 10:18 -0300) subió la nota casi en estado de plantilla; sigue sin subir (`main` va 1 commit adelante) y sin tag.
- **R8. Fin de línea (0b).** El índice está en LF gracias a `core.autocrlf`, pero en el disco `gateway.yaml`, `namespace.yaml`, `api.yaml` y `routes.yaml` tienen fin de línea mixto. Siguen sin existir `.gitattributes` y `.editorconfig`.

### Dato del render para el Día 7

La `ClusterRole` `traefik-traefik` (`infra/traefik/traefik.yaml`, bloque de `secrets` hacia la línea 53) da `get`, `list` y `watch` sobre `secrets` en todo el clúster. Con el proveedor de Gateway API y sin TLS en el controlador, es más de lo que el laboratorio usa hoy. Es un hallazgo para el Día 7, no un error de hoy.

### Preguntas abiertas (para pagar la deuda con evidencia)

1. ¿Qué podría leer un Pod de Traefik comprometido, por ejemplo en `lab`, y qué parte de ese permiso usa de verdad el laboratorio hoy?
2. ¿Por qué `/apix` lo responde nginx y no Traefik? ¿Qué regla lo atrapó y qué cambiaría con otro `path.type`?
3. ¿Qué dos diferencias concretas separan el 404 de Traefik del 404 de nginx?
4. ¿Qué Pod de `web` respondió en `02` y dónde queda el rastro de cada petición?
5. En `03`, `X-Forwarded-For` es `172.18.0.1`: ¿de quién es esa IP y qué te dice sobre el camino desde `127.0.0.1` hasta el Pod del controlador? (pregunta 2 de la ficha)
6. ¿Qué en tu evidencia y en la ClusterRole sugiere que Traefik envía el tráfico a IPs de Pods y no a la ClusterIP? (pregunta 3; se cierra con el bloque B)
7. La respuesta de `/api` es JSON y la de `/api/usuarios` es texto: ¿viene de tu ruta o de la imagen?

### Antes del push (nivel 1, ≤5')

1. `gitleaks git` otra vez: cubre el commit `7694651` y el de cierre. Los dos tienen que quedar en el historial escaneado.
2. El `grep -rlF` con el valor vigente del Secret sobre `README.md`, `evidence`, `docs`, `manifests` e `infra`, después de estas ediciones del mentor.
3. Crear el tag y subirlo: `git push origin dia-06`.

### Cierre (2026-10-29)

**Ejes:** 🎯 ⚠️ · 🔐 ⚠️ · 📈 ⚠️ · 🧰 ⚠️

Cerrado con deuda por el mentor. Al pedir el cierre, el alumno no había completado la nota (predicciones, decisiones, bitácora, preguntas) ni hecho los bloques B y C, así que se cerró por defecto, con todo declarado en «Deuda del día». Cambios del mentor: la cabecera (Estado y Alcance), esta sección, la tabla «Deuda del día», el `README.md` (Día 6, exposición HTTP y limitaciones) y el plan en el Project. Nada más de la nota se tocó. El alumno puede revertir cualquier fila pagándola con evidencia.

Tiempo: no se declaró. Entre la primera y la última evidencia del bloque A pasaron 2 h 14 min de reloj (21:34 a 23:48 UTC del 28 oct, con huecos), más la Parte 0 del 29 oct (12:59 a 13:01 UTC). El plan asumía 75' para el bloque A.

Calendario: el Día 6 se cierra el jue 29 oct, tres días hábiles después de lo previsto (lun 26). Con la regla de las veces anteriores (el siguiente día hábil después del cierre): Día 7 vie 30 oct, Día 8 lun 2 nov, Día 9 mar 3 nov, Día 10 mié 4 nov.

## 📚 Qué haría distinto en producción
TODO
