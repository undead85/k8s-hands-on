# Día 03 — ConfigMap y Secret
**Fecha:** 2026-10-14 · **Tiempo:** 60' (plan: 60')

## 🎯 Objetivo medible
`web` lee su config de un ConfigMap (como archivo y como variable de entorno) y MySQL arranca con una contraseña nueva guardada en un Secret que nunca entra al repo. Medir qué se actualiza solo y qué no. `gitleaks` con 0 hallazgos y con prueba de control.

## 🧩 Predicciones (escríbelas ANTES de ejecutar; no las edites después)
1. Propagación del ConfigMap: el archivo no cambia el valor dentro del contenedor hasta después de un restart· `APP_MODE` == production
2. `curl` a `/healthz` con el archivo ya cambiado responde: 200 porque el archivo de configuración de nginx sobreescribe la respuesta de las peticiones al endpoint `/healthz`
3. (Bonus) Tras rotar la contraseña y reiniciar `db` entro con la nueva porque al reiniciar el pod obtiene la nueva contraseña y se inicializa con esa.

## ✅ Criterios (una línea por criterio)
Estado: pendiente → ✅ cumplido / ⚠️ parcial / ❌ no cumplido.

kubectl create secret generic mysql-secret --from-literal=password='' -n lab

| # | Criterio | Evidencia | Estado | Dato clave a registrar |
|---|---|---|---|---|
| 1 | `web` ×3 Ready con el ConfigMap; `nginx -t` OK; `curl web/healthz` = 200 | `01-configmap.txt` | cumplido | HTTP: 200 · `nginx -t`: ok |
| 2 | El archivo cambia en ≤ 2 min con los mismos Pods y `RESTARTS` 0; `APP_MODE` solo cambia con `rollout restart` | `02-propagacion.txt` | cumplido | `curl` antes: OK - Healthy · después: OK - This was a configMap change · `APP_MODE` antes / tras restart:  production / production-change |
| 3 | Secret sin exponer el valor; largo decodificado exacto; `db` 1/1 Running | `03-secret.txt` | cumplido | largo esperado: 20 · largo real: 20 |
| 4 | Login a MySQL con la contraseña del Secret; sin rastro en historial, `ps` ni `evidence/` | `04-login.txt` | cumplido | log "ready for connections": ok · consulta de prueba OK |
| 5 | `gitleaks` 0 hallazgos (historial + árbol); control con secreto falso ≥ 1 y vuelve a 0; evidencia sin el falso | `05-gitleaks.txt` | pendiente | base: ?? · con falso: ?? · tras borrar: ?? |
| 6 | (Bonus, fuera del reloj) Rotación del Secret + `rollout restart` de `db` | `06-rotacion.txt` | pendiente | entré con: ?? |

## 🔍 Bitácora de depuración
Si todo salió a la primera, reemplaza esta sección completa por «sin incidentes».

| # | Síntoma observado | Hipótesis | Comando | Resultado | ¿Descartada? |
|---|---|---|---|---|---|
| 1 | ?? | ?? | ?? | ?? | ?? |

### 🛠️ Causa raíz y solución definitiva
- Causa raíz (1 frase + archivo de evidencia): TODO
- Cambio aplicado:
```diff
- 
+ 
```

## ❓ Preguntas de la ficha (1–3 líneas + dónde está la evidencia)
1. ¿Por qué el archivo montado cambia solo y la variable de entorno no? Incluye qué muestra el `ls -la` dentro del Pod. → TODO
2. Con el archivo ya cambiado, ¿qué hace nginx? Dos formas de que tome la config nueva y cuándo usar cada una. → TODO
3. Un Secret es solo base64: ¿qué protege realmente y qué no? Dos controles para producción. → TODO
4. (Opcional) ¿Qué estado tiene un Pod nuevo de `db` si el Secret no existe? → TODO (o `n/a`)

## 🔐 Autoauditoría de seguridad (marca solo lo que verificaste)
- [ ] Ningún archivo trackeado contiene la contraseña (ni en claro ni en base64)
- [ ] `evidence/` no contiene la contraseña ni el secreto falso
- [ ] No usé `get secret -o yaml` en ninguna evidencia
- [ ] La contraseña es nueva (≥ 20 caracteres) y distinta de la de `kubernetes/mysql-deployment.yaml`
- [ ] Imagen de MySQL con tag fijo verificado (sin `latest`): ??
- [ ] Imágenes de los Pods de prueba con tag fijo y no root (o deuda anotada)
- [ ] `db` corre como root: decisión consciente para el Día 8 (sí / no): ??

Comando de creación del Secret (sin el valor): `TODO`
Por qué es la excepción declarativa: TODO

## 🧪 Verificación reproducible
Comandos mínimos para repetir los criterios 1, 3 y 5 desde cero (sin alias, sin valores secretos):
```bash
# criterio 1
# criterio 3
# criterio 5
```

## 📦 Entrega
- [ ] Commit `chore:` regla de EOL (renormalización en un commit propio)
- [ ] Commit `docs:` deuda del Día 2
- [ ] Commit `feat:` Día 3 (manifiestos, evidencias y esta nota)
- [ ] Tag `dia-03`, luego `git push` y `git push origin dia-03`
- [ ] Tres líneas para el mentor. Esperaba: ?? · Pasó: ?? · Dudas: ??

## 🔎 Revisión del mentor
La completa el mentor tras «revisa día 3».

## 📚 Qué haría distinto en producción
- TODO
- TODO
