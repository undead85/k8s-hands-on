# Día 08 — Hardening de Pods y Pod Security Admission
**Fecha:** ????-??-?? · **Inicio:** ??:?? · **Fin:** ??:?? · **Minutos reales:** 50' (plan: 45') · **Estado:** 🔄 en curso

## 🎯 Objetivo
`lab` impone el nivel más alto de Pod Security que `db` tolera hoy, avisa de lo que falta para `restricted`, y los Pods de `web` cumplen `restricted` con la raíz de solo lectura.

## ✅ Criterios (una línea de por qué por cada uno)
| # | Criterio | Hecho | Qué pasó y por qué (1 línea) | Evidencia |
|---|---|---|---|---|
| 1 | `web` con `securityContext` completo, 3 Pods Ready y sirviendo | yes | ahora el contenedor puede escribir solo en un volumen distinto al del filesystem | `01-securitycontext.txt` |
| 2 | Etiquetas de PSA en `lab` y `web` sin advertencias de `restricted` | yes | al usar enforce=baseline no hay advertencias | `02-psa.txt` |
| 3 | Un Pod privilegiado es rechazado | yes | el pod no pasa las politicas restricted y no logra ser creado| `03-privilegiado.txt` |

## 🔧 Los blancos
- BLANCO 1 (`enforce`): restricted — porque es el nivel mas seguro
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
Predicción no hecha, hice la predicción pero olvidé guardar los cambios antes de ejecutar el check y ahora ya se el resultado.
