# Día 09 — NetworkPolicy: default-deny con permisos mínimos
**Fecha:** 2026-11-04 · **Inicio:** 17:45 · **Fin:** 19:11 · **Minutos reales:** 50' · **Estado:** 🟡 ejecutado, pendiente del cierre del mentor

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
