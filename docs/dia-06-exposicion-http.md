# Día 06 — Exposición HTTP (Gateway API con Traefik)
**Fecha de inicio:** 2026-10-26 · **Inicio:** ??:?? · **Fin:** ??:?? · **Minutos reales:** Parte 0 ??' + A ??' + B ??' + C ??' (plan: A 75' · B +30' · C +25') · **Estado:** TODO (✅ / ⚠️ parcial)
**Alcance de hoy:** TODO (A / A+B / A+C / A+B+C)

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
| Deuda | Estado (pagada / no corregido) | Evidencia o motivo |
|---|---|---|
| TODO | TODO | TODO |

## 📦 Entrega
- [ ] Commit `chore:` o `fix:` de la Parte 0 (`00-seguro.txt` de hoy)
- [ ] Commit `feat:` del Día 6 (manifiestos, evidencias y esta nota)
- [ ] Commit `docs:` del README (paso nuevo y su orden, versiones de Traefik y de los CRDs de Gateway API)
- [ ] Tag `dia-06`, luego `git push` y `git push origin dia-06`
- [ ] Tres líneas para el mentor. Esperaba: ?? · Pasó: ?? · Dudas: ??

## 🔎 Revisión del mentor
La completa el mentor tras «revisa día 6».

## 📚 Qué haría distinto en producción
TODO
