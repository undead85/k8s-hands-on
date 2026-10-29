# Día 07 — RBAC de mínimo privilegio
**Fecha:** ????-??-?? · **Inicio:** ??:?? · **Fin:** ??:?? · **Minutos reales:** ??' (plan: 45') · **Estado:** ✅ cerrado (cierre del mentor, 2026-10-29)

## 🎯 Objetivo
`deployer` puede hacer `patch` de Deployments en `lab` y nada más; los Pods de `web` no montan token.


## ✅ Criterios (una línea de por qué por cada uno)
| # | Criterio | Hecho | Qué pasó y por qué (1 línea) | Evidencia |
|---|---|---|---|---|
| 1 | SA, Role y RoleBinding existen | [yes] | se creó un SA que solo puede hacer patch sobre el recurso Deployment en el namespace lab.  | `01-rbac.txt` |
| 2 | Matriz `can-i` 4/4 | [yes] | usando auth can-i se logró comprobar que el SA solo puede hacer patch sobre Deployments en el ns lab | `02-matriz.txt` |
| 3 | `web` sin token | [yes] | los pods ya no tienen montado un token que les permita usar la API de k8s | `03-token.txt` |

## 🔧 Los blancos
- BLANCO 1 (`apiGroups`): apps — porque es el grupo al que pertenece el resource Deployment
- BLANCO 2 (`verbs`): patch — porque es el unico verbo que se solicita configurar.
- BLANCO 3 (`automountServiceAccountToken`): false — porque asi se evita que se creen los pods con el kube-api-access

## ❓ Preguntas (1 línea cada una)
1. Tu usuario es admin del clúster, ¿por qué `can-i ... --as=...deployer` da `no` en varios casos? ¿A quién evalúa `--as`? 
el comando permite evaluar como otro usuario en este caso el SA deployer
2. ¿Qué pasa con el token de `web` si no pones `automountServiceAccountToken: false`? ¿Qué podría hacer alguien que entre al Pod?
podría consumir la API de k8s y obtener información.

## Opcional
- Se agrega el permiso de lectura para que funcione un rollout restart

## ⏭️ Pendiente (una línea; si no hay nada, escribe «nada»)
nada

## 🔎 Revisión del mentor (2026-10-29)
| Parte | Veredicto |
|---|---|
| 1. SA, Role y RoleBinding | ✅ |
| 2. Matriz `can-i` | ✅ 4/4 en la última corrida (15:22 UTC). Hubo 5 corridas: 0/4 por un error de parseo del script (mío), 4/4, y 3/4 dos veces por `verbs: ["get, patch"]` (una sola cadena en vez de dos verbos) |
| 3. `web` sin token | ✅ `false` en la plantilla y solo `config-volume` en los 3 Pods |
| O1. `rollout restart` como `deployer` | ✅ `04-opcional-restart.txt`: con `get` y `patch` funciona; solo con `patch` falla en el `get` |
| O2. `ClusterRole` de Traefik | no realizado (opcional, sin deuda) |

Ejes: 🎯 ✅ · 🔐 ⚠️ · 📈 no aplica hoy · 🧰 ⚠️.

**Qué salió bien**
- Los criterios 1 a 3 quedaron en ✅ unos 10' después de la predicción.
- Encontraste el `["get, patch"]` leyendo el Role que Kubernetes guardó (`jsonpath`), no lo que creías haber escrito.
- Dejaste el log de las 5 corridas en vez de borrarlo.
- Todos los Pods de `web` quedaron sin volumen `kube-api-access-*`, y el Role es mínimo: solo `deployments`, solo `get` y `patch`, solo en `lab`.

**Hallazgos**
1. 🔐 **Nivel 1 tarde.** `pre` no corrió antes del primer commit (`2d581c1`): `00-seguro.txt` tenía un solo bloque (11:08 hora local). Su último comando, el `curl`, terminó con `exit=23` por un error mío del script (desactivaba la conversión de `/dev/null` en Git Bash), corregido en `34f6bdd`. El `pre` de las 12:33 salió limpio: 5 patrones, sin coincidencias, `curl` = 200. El commit de ejecución se subió sin ese chequeo; el posterior sí lo tiene.
2. 🧰 **La nota no refleja el estado final.** Quedan sin corregir: la cabecera (`????`, `??`); «solo patch» en los criterios 1 y 2 y en el BLANCO 2, cuando el Role commiteado concede `get` y `patch` (ver `01-rbac.txt`); la decisión de agregar `get` sin su porqué; «Pendiente: nada», pese a las 5 corridas de la matriz; y la pregunta 1, que responde a quién evalúa `--as` pero no por qué un admin ve `no` (porque se evalúan los permisos de la ServiceAccount, no los tuyos).

## 🏁 Cierre (2026-10-29)
- **Tiempo medido** (el alumno no declaró minutos; hora local, desde las evidencias): primer `pre` 11:08; predicción 11:40; criterios 1 a 3 en ✅ a las 11:49; O1 y corrección del Role entre 11:49 y 12:33. El núcleo tomó ≈ 41' de reloj, con 32' entre el `pre` y la predicción.
- **Estado:** ✅ cerrado. Sin deuda declarada (formato A). Lo señalado en el hallazgo 2 queda como pendiente de la nota; no cuenta como deuda.
- **Entrega:** commits `2d581c1` (ejecución, con el tag `dia-07`) y `34f6bdd` (script, evidencia y nota). El tag no se mueve; el cierre del mentor va en un commit nuevo.
- **Calendario:** Día 7 cerrado el jue 29 oct, un día antes de lo agendado. Día 8: lun 2 nov (se puede hacer antes).
