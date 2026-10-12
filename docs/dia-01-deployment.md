# Día 01 — Deployment confiable
**Fecha:** 2026-10-12 · **Tiempo:** <<tu cifra final>> (planificado: 30') · **Estado:** ✅ criterios 1–6 cumplidos; hallazgos abiertos (ver abajo)

## 🎯 Objetivo medible
`web` ×3 en el namespace `lab`, con tag fijo y sin root; auto-reparación en menos de 30 s; rollout que nunca baje de 3 Pods disponibles; `rollout undo` devuelve la imagen original.

## 🧩 Problema
El punto de partida era `nginx:1.14.2` (Debian 9.8): corre como root (UID 0) y Trivy 0.75.0 (base del 2026-10-12) reporta **113 vulnerabilidades HIGH/CRITICAL**. Un fallo explotable en nginx daría al atacante root dentro del contenedor, y una imagen tan antigua ya no recibe parches. Había que reemplazarla por una imagen mantenida, sin root y fijada de forma inmutable, y demostrar que el Deployment se repara y se actualiza sin perder capacidad.

## 🔍 Bitácora de depuración
| # | Hipótesis | Comando | Resultado | ¿Confirmada? |
|---|-----------|---------|-----------|--------------|
| 1 | La imagen sin root no escucha en el puerto 80 que declara el manifiesto | Dentro del Pod: `grep -rn "listen" /etc/nginx/` · `netstat -tulpn \| grep nginx` | nginx escucha en 8080 | ✅ manifiesto corregido a 8080 |
| 2 | Un digest sin tag no permite saber qué versión corre | `kubectl rollout history` + `jsonpath` de la imagen | solo aparece `sha256:…`; hay que buscarlo fuera del clúster | ✅ deuda técnica → Día 2 |
| 3 | Los archivos del repo tienen distinto fin de línea (CRLF vs LF) | `file manifests/*.yaml .gitignore .pre-commit-config.yaml` | manifiestos y `kind-config.yaml` en CRLF; el resto en LF | ✅ ver Solución |
| 4 | El clúster ya no coincidía con el repo tras las pruebas con `set image` y `rollout undo` | `kubectl apply -f manifests/` | `deployment.apps/web configured` (corría `nginx`, no la imagen del manifiesto) | ✅ reconciliado |

## 📊 Resultados
| Criterio | Resultado | Evidencia |
|---|---|---|
| 1 | 3/3 READY, 3 UP-TO-DATE, 3 AVAILABLE | `01-deploy-ready.txt` |
| 2 | 2,4 s (12:03:52,0 → 12:03:54,5). Sin `readinessProbe`, "Ready" = contenedor iniciado, no garantiza que nginx ya sirva | `02-autoreparacion.txt` |
| 3 | `available` mínimo 3; `total` máximo 4 (muestreo de 1–2 s) | `03-rollout-availability.txt` |
| 4 | Imagen restaurada al digest del manifiesto; la revisión 15 reaparece como 17 | `04-undo-historia.txt` |
| 5 | UID 101 (nginxinc) vs 0 (nginx:1.14.2); el UID lo define la imagen, no el YAML | `05-uid.txt` |
| 6 | 113 vs 0 HIGH+CRITICAL | `06-trivy.txt` |

## 🛠️ Causa raíz
- **Puerto:** el manifiesto declaraba `containerPort: 80`, pero `nginx-unprivileged` está configurada para escuchar en 8080 (los puertos <1024 son privilegiados). `containerPort` es solo informativo: no abre ni cierra puertos, por eso nada falló.
- **Cuarto Pod en el rollout:** `maxUnavailable: 0` obliga a crear Pods nuevos antes de retirar los viejos, y `maxSurge` (por defecto 25%, redondeado a 1 réplica extra con 3 réplicas) lo permite: 3 + 1 = 4.
- **Versión ilegible:** fijar por digest da inmutabilidad, pero el digest no contiene la versión.
- **Fin de línea:** sin `.gitattributes`, el repo depende de la configuración de cada máquina (editor y `core.autocrlf`).
- **Deriva:** `set image` y `rollout undo` son imperativos. Cambian el estado vivo pero no la anotación `last-applied-configuration`, así que el clúster y el YAML del repo dejaron de coincidir.

## ✅ Solución definitiva
- **Puerto:** `containerPort: 8080`, verificado dentro del Pod.
- **Reconciliación:** `kubectl apply -f manifests/`. Para volver atrás: restaurar la versión anterior del YAML (`git revert` o `git checkout <commit> -- manifests/`) y volver a aplicar, no `rollout undo`.
- **Fin de línea:** LF como estándar con `.gitattributes` (`* text=auto eol=lf`), `.editorconfig` y el hook `mixed-line-ending`. ⏳ Marcar ✅ cuando esté commiteado.
- **Versión legible:** ⏳ **deuda técnica → Día 2.** Se pospone para cerrar el día sin ampliar el tiempo; el Día 2 vuelve a editar estos manifiestos y la corrección quedará como diff `dia-01 → dia-02`.

## 🔎 Revisión del mentor
🔐 Sin root y 0 vulnerabilidades; los artefactos de escaneo no entran al repo. · 📈 2 de 3 réplicas quedaron en el mismo nodo (`lab-worker`): si cae, se pierde ≈67% de la capacidad hasta la reprogramación → Día 10. · 🧰 `rollout undo` sobre un recurso gestionado con `apply` genera deriva; el UID depende de la imagen y no está garantizado por el YAML.

## 📚 Qué haría distinto en producción
1. **Garantizar el no-root en el YAML:** `securityContext.runAsNonRoot: true` y `allowPrivilegeEscalation: false`. Con eso el kubelet se niega a arrancar un contenedor que corra como root aunque alguien cambie la imagen. A nivel de namespace, Pod Security Admission en `restricted` rechaza el Pod en la admisión (Día 8).
2. **Rollback declarativo:** `git revert` + `kubectl apply`, o GitOps (Argo CD o Flux), en lugar de `rollout undo`.
3. **Versión legible e inmutable:** referenciar la imagen como `repo:tag@sha256:…` y comprobar que el tag corresponde al digest. El runtime usa el digest e ignora el tag, así que un tag equivocado engañaría a quien lea el manifiesto.
4. **Repartir réplicas entre nodos:** `topologySpreadConstraints` o anti-affinity, más un PodDisruptionBudget.
5. **Medir "listo" de verdad:** una `readinessProbe` para que Ready signifique que nginx sirve tráfico (Día 4).
