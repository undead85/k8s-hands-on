# Día 08 — Hardening de Pods y Pod Security Admission
**Fecha:** 2026-11-02 · **Inicio:** 11:38 · **Fin:** 13:03 · **Minutos reales:** 50' declarados; reloj 11:38 a 13:03 (plan: 45') · **Estado:** ✅ ejecutado (cierre del mentor pendiente)

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
