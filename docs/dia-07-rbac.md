# Día 07 — RBAC de mínimo privilegio
**Fecha:** ????-??-?? · **Inicio:** ??:?? · **Fin:** ??:?? · **Minutos reales:** ??' (plan: 45') · **Estado:** ⬜

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
