# Día 08 — Hardening de Pods y Pod Security Admission
**Fecha:** 2026-11-02 · **Inicio:** 11:38 · **Fin:** 13:03 · **Minutos reales:** 50' declarados; reloj 11:38 a 13:03 (plan: 45') · **Estado:** ✅ cerrado (cierre del mentor, 2026-11-02)

## 🎯 Objetivo
`lab` impone el nivel más alto de Pod Security que `db` tolera hoy, avisa de lo que falta para `restricted`, y los Pods de `web` cumplen `restricted` con la raíz de solo lectura.

## ✅ Criterios (una línea de por qué por cada uno)
| # | Criterio | Hecho | Qué pasó y por qué (1 línea) | Evidencia |
|---|---|---|---|---|
| 1 | `web` con `securityContext` completo, 3 Pods Ready y sirviendo | yes | ahora el contenedor puede escribir solo en un volumen distinto al del filesystem | `01-securitycontext.txt` |
| 2 | Etiquetas de PSA en `lab` y `web` sin advertencias de `restricted` | yes | enforce=baseline, warn y audit=restricted: web no genera avisos de restricted (db sí, a propósito) | `02-psa.txt` |
| 3 | Un Pod privilegiado es rechazado | yes | el Pod con privileged: true viola el nivel baseline y el servidor lo rechaza (dry-run, no se crea) | `03-privilegiado.txt` |

**Predicción:** no hecha. La escribí pero no guardé el archivo antes de ejecutar `check` (quedó vacío) y ya conocía el resultado.

## 🔧 Los blancos
- BLANCO 1 (`enforce`): baseline — porque es el nivel más alto que `db` tolera hoy (corre como root y sin securityContext); con restricted no se podría recrear su Pod. restricted queda en warn y audit
- BLANCO 2 (`seccompProfile.type`): RuntimeDefault — porque bloquea las llamadas mas peligrosas al kernel linux
- BLANCO 3 (`allowPrivilegeEscalation`): false — porque no permite escalar permisos que es inseguro.
- BLANCO 4 (`readOnlyRootFilesystem`): true — porque asegura que el filesystem sea inmutable
- BLANCO 5 (`capabilities.drop`): ALL — porque elimina todas las capacidades por defecto, si se necesita una especifica se agrega posteriormente.

## ❓ Preguntas (1 línea cada una)
1. Si hubieras puesto `enforce` en `restricted`, ¿qué le pasaría a `db` la próxima vez que se recree su Pod? ¿Y al Pod de `db` que ya corre?
los nuevos pods fallaran, el que ya corre se permite que siga corriendo.
2. ¿Qué pasaría con el `readiness` del Día 4 (el archivo `/tmp/romper_readiness`) si `/tmp` no fuera escribible?
Al no poder crear el archivo no se podría hacer la simulación de un readiness fallido.

## Opcional (solo lo que hayas hecho)
Ninguno. El script dejó `04-opcional-warnings.txt` (avisos de `db`), pero no escribí las 3 líneas de O2.

## ⏭️ Pendiente (una línea; si no hay nada, escribe «nada»)
Nada del núcleo. Revisar con `kubectl diff` por qué `db` y `lab-routes` salen `configured` en el dry-run (hallazgo 3 del mentor, sin verificar).

## 🔎 Revisión del mentor (2026-11-02)
| Parte | Veredicto |
|---|---|
| 1. `web` endurecido | ✅ Última corrida (15:57 UTC): rollout completo, plantilla completa, 3 Pods con raíz de solo lectura y `curl` = 200 |
| 2. PSA en `lab` | ✅ `enforce=baseline`, `warn` y `audit` en `restricted`; `web` y `api` sin avisos de `restricted`, `db` con aviso (esperado) |
| 3. Pod privilegiado | ✅ Rechazado por `baseline:latest` (`03-privilegiado.txt`, segunda respuesta) |
| O1. Romper `/tmp` a propósito | no realizado (opcional, sin deuda) |
| O2. `db` frente a `restricted` | parcial: el script dejó los avisos de `db` en `04-opcional-warnings.txt`; las 3 líneas no se escribieron (opcional, sin deuda) |

Ejes: 🎯 ✅ · 🔐 ✅ (`db` queda fuera de `restricted` a propósito y a la vista) · 📈 ✅ (3/3 y 200 al final del rollout; no se midió durante él) · 🧰 ⚠️.

**Qué salió bien**
- Corregiste `enforce` de `restricted` a `baseline` y dejaste el porqué escrito: `db` no tolera `restricted`. Tu respuesta a la pregunta 1 (los Pods nuevos fallan, el que corre sigue) es correcta.
- Dejaste en la evidencia las dos corridas de `check`, la ❌ de las 15:28 y la ✅ de las 15:57, en vez de borrar la primera.
- `pre` corrió a las 15:59 UTC, antes del commit de las 16:03: gitleaks sin hallazgos (18 commits) y 5 patrones sin coincidencias.
- No inventaste la predicción después de ver el resultado: la dejaste anotada como no hecha.

**Hallazgos**
1. 🧰 **La nota no reflejaba el estado final (resuelto).** El BLANCO 1 decía `restricted` y el criterio 3 hablaba de `restricted`, contra `baseline` en `namespace.yaml` y en la última evidencia; además la cabecera tenía `????` y faltaba la sección Pendiente. El mentor lo corrigió el 2 nov a las 13:07 (hora local), a pedido del alumno, sin tocar sus respuestas. El commit `6cd0992` subió la versión anterior; la corrección quedó en el commit `2c3e4ed` (13:11).
2. 🎯 **Predicción vacía y 29' hasta ella.** `00-prediccion.txt` se creó a las 12:07 (29' después del primer `pre` de las 11:38) y se subió con 0 bytes. En el Día 7 fueron 32' hasta la predicción: ahí se va el tiempo. Para el Día 9: predicción justo después de `pre`, antes de abrir los manifiestos, y guardar el archivo antes de `check`.
3. 🧰 **Error del mentor: la sonda del criterio 2 era ciega.** Con `enforce` ya en `restricted`, el dry-run de la etiqueta no compara nada y devolvió `db=0 api=0` (primer `check`, 12:28). Se cambió a `kubectl apply --dry-run=server` de cada manifiesto, que funciona con cualquier `enforce`; ya está en el script del commit `6cd0992`.

## 🏁 Cierre (2026-11-02)
- **Tiempo medido** (hora local, desde las evidencias): primer `pre` 11:38; archivo de predicción 12:07 (vacío); primer `check` 12:28 (criterios 1 y 3 ✅, 2 ❌ por `enforce=restricted`); segundo `check` 12:57 (3 ✅); `pre` 12:59; commit 13:03. Declarados 50'; de reloj 85' (11:38 a 13:03), con 29' entre las dos corridas de `check`.
- **Estado:** ✅ cerrado. Sin deuda declarada (formato A). Queda una pregunta abierta, sin verificar y sin deuda: por qué `db` y `lab-routes` salen `configured` (y no `unchanged`) en `kubectl apply --dry-run=server -f manifests/` (`00-seguro.txt`); se mira con `kubectl diff`.
- **Entrega:** commit `6cd0992` (ejecución, con el tag `dia-08`, ya en el remoto) y `2c3e4ed` (ajustes de la nota). El tag no se mueve; el cierre del mentor va en un commit nuevo.
- **Calendario:** Día 8 cerrado el lun 2 nov, en su fecha. Día 9: mar 3 nov.
