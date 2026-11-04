# Día 09 — NetworkPolicy: default-deny con permisos mínimos
**Fecha:** ????-??-?? · **Inicio:** ??:?? · **Fin:** ??:?? · **Minutos reales:** ??' (plan: 45') · **Estado:** 🔄 en curso

## 🎯 Objetivo
`lab` bloquea todo el tráfico entre Pods salvo lo necesario: Traefik → `web` y `api`, `web` → `db`:3306 y el DNS.

## ✅ Criterios (una línea de por qué por cada uno)
| # | Criterio | Hecho | Qué pasó y por qué (1 línea) | Evidencia |
|---|---|---|---|---|
| 1 | Las 6 NetworkPolicy existen y `default-deny` cubre Ingress y Egress | yes | las reglas permiten trafico especifico, todo lo demas se deniega | `02-netpol.txt` |
| 2 | Matriz de 6 pruebas: 3 funcionan y 3 fallan por timeout | yes | funciona segun las reglas definidas | `03-matriz.txt` |
| 3 | `web`, `api` y `db` siguen Ready | yes | los pods siguen vivos | `04-vivo.txt` |

**Predicción:** aciertos 6/6. ¿Guardada antes de aplicar? yes

## 🔧 Los blancos
- BLANCO 1 (`namespaceSelector` de `web-ingress`): traefik — porque permite el acceso de traefik
- BLANCO 2 (puerto de `web-ingress`): 8080 — porque es el puerto que escucha del Pod web
- BLANCO 3 (`ingress` de `api-ingress`): similar al web-ingress — porque tambien permite a traefik y usa el mismo puerto 8080
- BLANCO 4 (`podSelector` de `db-ingress`): web — porque permite acceso desde web
- BLANCO 5 (`policyTypes` de `default-deny`): egress — porque deniega todo el trafico egress que no cumpla las reglas previas.

## ❓ Preguntas (1 línea cada una)
1. Si `web-ingress` abriera el puerto 80 en vez del 8080, ¿qué pasaría con la prueba 1? ¿Por qué? 
fallaría porque la politica indica el puerto 8080 solamente

2. ¿Por qué hace falta `allow-dns` si `default-deny` ya bloquea todo? ¿Qué se rompería sin ella?
allow-dns permite la comunicación de los pods con el coreDNS de k8s, sin eso los pods no saben como acceder a otros pods.

## Opcional (solo lo que hayas hecho)
??

## ⏭️ Pendiente (una línea; si no hay nada, escribe «nada»)
??
