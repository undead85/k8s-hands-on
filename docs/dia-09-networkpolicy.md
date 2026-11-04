# Día 09 — NetworkPolicy: default-deny con permisos mínimos
**Fecha:** 2026-11-04 · **Inicio:** 17:45 · **Fin:** 19:11 · **Minutos reales:** 50' declarados; reloj 17:45 a 19:11, con el commit a las 19:00 (plan: 45') · **Estado:** ✅ cerrado (cierre del mentor, 2026-11-04)

## 🎯 Objetivo
`lab` bloquea todo el tráfico entre Pods salvo lo necesario: Traefik → `web` y `api`, `web` → `db`:3306 y el DNS.

## ✅ Criterios (una línea de por qué por cada uno)
| # | Criterio | Hecho | Qué pasó y por qué (1 línea) | Evidencia |
|---|---|---|---|---|
| 1 | Las 6 NetworkPolicy existen y `default-deny` cubre Ingress y Egress | yes | las reglas permiten trafico especifico, todo lo demas se deniega | `02-netpol.txt` |
| 2 | Matriz de 6 pruebas: 3 funcionan y 3 fallan por timeout | yes | funciona segun las reglas definidas; el bloque de 18:35 corrió antes de aplicar y no cuenta, el de 18:40 dio yes en 1–3 y timeout (4 s) en 4–6 | `03-matriz.txt` |
| 3 | `web`, `api` y `db` siguen Ready | yes | los pods siguen vivos | `04-vivo.txt` |

**Predicción:** aciertos 6/6. ¿Guardada antes de aplicar? yes (guardada 18:14:51; la primera política se creó hacia las 18:37)

## 🔧 Los blancos
- BLANCO 1 (`namespaceSelector` de `web-ingress`): traefik — porque permite el acceso de traefik
- BLANCO 2 (puerto de `web-ingress`): 8080 — porque es el puerto que escucha del Pod web
- BLANCO 3 (`ingress` de `api-ingress`): similar al web-ingress — porque tambien permite a traefik y usa el mismo puerto 8080
- BLANCO 4 (`podSelector` de `db-ingress`): web — porque permite acceso desde web
- BLANCO 5 (`policyTypes` de `default-deny`): egress — porque deniega todo el trafico egress que no permita otra política; las políticas se suman y el resultado no depende del orden en que se crean (el orden del archivo solo evita cortar el tráfico mientras se aplica).

## ❓ Preguntas (1 línea cada una)
1. Si `web-ingress` abriera el puerto 80 en vez del 8080, ¿qué pasaría con la prueba 1? ¿Por qué? 
fallaría: la política mira el puerto del Pod (8080), no el del Service (80); si solo abriera el 80, el tráfico de Traefik al 8080 se descartaría y el curl no recibiría respuesta.

2. ¿Por qué hace falta `allow-dns` si `default-deny` ya bloquea todo? ¿Qué se rompería sin ella?
allow-dns permite el Egress de los pods hacia CoreDNS (puerto 53); sin ella default-deny corta esa salida, los nombres (db.lab.svc.cluster.local, api, web) no se resuelven y las conexiones por nombre fallan, aunque la política de la conexión sí la permita.

## Opcional (solo lo que hayas hecho)
O1 - borré `web-to-db` y repetí la prueba 3 a mano (`evidence/dia-09/O1-sin-web-to-db.txt`): `web` → `db`:3306 falló (exit 1). La salida de `web` queda cerrada por `default-deny` aunque `db-ingress` acepte la entrada: un camino necesita los dos lados.

## ⏭️ Pendiente (una línea; si no hay nada, escribe «nada»)
O2 no realizado, por falta de tiempo (opcional, sin deuda).

## 🔎 Revisión del mentor (2026-11-04)
| Parte | Veredicto |
|---|---|
| 1. Las 6 políticas y `default-deny` | ✅ `02-netpol.txt` (21:40 UTC): las 6 existen y `default-deny` da `tipos=Ingress Egress selector={} ingress= egress=`. En el `pre` de las 21:59 UTC las 6 salen `unchanged` en el dry-run: el clúster coincide con el archivo |
| 2. Matriz de 6 pruebas | ✅ `03-matriz.txt`, bloque de las 21:40 UTC: pruebas 1 a 3 `yes` en ≤1 s; pruebas 4 a 6 `no` a los 4 s (`nc` sale con 1 y `wget` dice `download timed out`). El bloque de las 21:35 UTC corrió antes de aplicar y no cuenta |
| 3. Stack vivo | ✅ `04-vivo.txt`: `web` 3/3, `api` 2/2 y `db` 1/1 a los ≈2'45" de aplicar, sin reinicios nuevos |
| O1. Quitar `web-to-db` | ✅ realizado: `web` → `db`:3306 falla sin la política (`O1-sin-web-to-db.txt`); sin hora ni duración, y sin la restauración (hallazgo 3) |
| O2. Cliente MySQL del Día 5 | no realizado (opcional, sin deuda) |

Ejes: 🎯 ✅ · 🔐 ✅ (sin `ipBlock` ni `from` vacío, puertos del Pod, `namespaceSelector` y `podSelector` juntos; límite de la prueba 5 abajo) · 📈 ✅ (el stack siguió Ready con las políticas) · 🧰 ⚠️.

**Qué salió bien**
- La predicción quedó guardada a las 18:14 (hora local), antes de aplicar (≈18:37), y acertó 6/6. El Día 8 había quedado vacía.
- Los 5 blancos salieron bien: puerto del Pod (8080) en `web-ingress` y `api-ingress`, `namespaceSelector` y `podSelector` en el mismo elemento (Y), `db-ingress` solo desde `web` y `default-deny` con los dos sentidos.
- Corriste `antes` (18:17): las 6 pruebas dieron `yes` sin políticas. Eso demuestra que los timeouts de después los causan las políticas y no la prueba.
- `pre` a las 21:59 UTC (18:59 local), antes del commit de las 19:00: gitleaks sin hallazgos (21 commits), 5 patrones sin coincidencias y dry-run de `manifests/` con exit 0.
- Hiciste el O1 sin que fuera obligatorio y dejaste la lección en la nota: un camino necesita los dos lados.

**Hallazgos**
1. 🧰 **La nota subió a medias en el commit con el tag (resuelto).** El commit `4a71caa` (19:00) llevaba la cabecera con `????`, Opcional y Pendiente en `??`, y tres frases con la idea torcida: la razón de la pregunta 1 describía la política real y no la hipótesis, el BLANCO 5 hablaba de «reglas previas» como si el orden importara y la pregunta 2 no precisaba qué falla (el Egress hacia CoreDNS). El mentor lo corrigió el 4 nov (19:12), a pedido del alumno y respetando sus respuestas; el commit `2c32343` (19:37) lo subió. El tag `dia-09` no se mueve.
2. 📈 **29' hasta la predicción por tercera vez, y 74' en total.** El primer `pre` fue a las 17:45 y el archivo de predicción a las 18:14 (29'; en el Día 7 fueron 32' y en el Día 8, 29'). Probar tomó 52' (plan 20') e Implementar 22' (plan 25'). Declaraste 50'; el reloj marca 74' hasta el commit, con el núcleo en ✅ a los 55' (18:40). La pregunta de qué ocupa esos ~30' quedó sin responder. Si es la lectura de la ficha, el problema es del mentor: la del Día 10 se acorta.
3. 🧰 **La evidencia del O1 no prueba un timeout ni la restauración.** `O1-sin-web-to-db.txt` trae el comando y `exit code 1`, sin hora ni duración (con `nc -w 3`, un bloqueo por política tarda ≈4 s; un fallo inmediato sería otra cosa), y termina sin el `apply` que devuelve `web-to-db`. La conclusión es razonable, porque lo único que cambió fue borrar esa política, pero **no consta que la política esté de vuelta**. Se comprueba con `kubectl -n lab get networkpolicy` (deben ser 6). Es opcional y sin deuda; el estado vivo sí importa.

**Límite de la prueba 5 (del diseño del mentor, no tuyo):** `web` → `api` lo bloquean dos políticas a la vez (la salida de `web` y la entrada de `api`). Por eso `api-ingress` solo queda probada en positivo (prueba 2). Está anotado en el README.

## 🏁 Cierre (2026-11-04)
- **Tiempo medido** (hora local, desde las evidencias): primer `pre` 17:45 (el `curl` de `lab.local` dio exit 52, respuesta vacía; el segundo `pre`, 17:53, dio 200); archivo de predicción 18:14; `antes` 18:17; manifiesto completo 18:35; primer `check` 18:35 (sin políticas aplicadas: 3/6); `apply` ≈18:37; segundo `check` 18:40 (3 criterios ✅); `pre` 18:59; commit con tag 19:00; O1 19:11; ajustes de la nota 19:37. Declarados 50'; de reloj 74' hasta el commit (17:45 a 19:00).
- **Estado:** ✅ cerrado. Sin deuda declarada (formato A). Dos cosas abiertas, sin deuda: confirmar que `web-to-db` está restaurada (hallazgo 3) y la pregunta del Día 8 sobre por qué `db` y `lab-routes` salen `configured` en el dry-run (se repite en `00-seguro.txt`, 21:59 UTC; las 6 NetworkPolicy salen `unchanged`).
- **Entrega:** commits `4a71caa` (ejecución, con el tag `dia-09`, ya en el remoto) y `2c32343` (ajustes de la nota y evidencia del O1). El tag no se mueve; el cierre del mentor va en un commit nuevo.
- **Calendario:** Día 9 cerrado el mié 4 nov, un día después de su fecha (mar 3). Por la regla del plan, el Día 10 pasa al jue 5 nov.
