# k8s-hands-on

Laboratorio práctico de Kubernetes de 2 semanas (10 sesiones acumulativas) sobre un clúster local con [kind](https://kind.sigs.k8s.io/). 

Qué queda desplegado (namespace `lab`, y `traefik` para la exposición HTTP):

- **`web`**: 3 réplicas de `nginxinc/nginx-unprivileged` (puerto 8080, usuario sin privilegios), con probes `startup`/`readiness`/`liveness` en rutas separadas y `requests` = `limits` (QoS Guaranteed). Services `web` (ClusterIP :80) y `web-headless`.
- **`db`**: MySQL de 1 réplica (Deployment) con un PVC (`db-pvc`, StorageClass `standard`) montado en `/var/lib/mysql`. Service `db` (:3306).
- **Configuración**: ConfigMap `web-config` (`default.conf` de nginx) y Secret `mysql-secret` (clave `password`), este último **fuera del repo**.
- **`api`**: 2 réplicas de `traefik/whoami:1.12.0` (por digest, puerto 8080, sin root, `requests` = `limits`), un backend de prueba que devuelve la petición que recibe. Service `api` (ClusterIP :80).
- **Exposición HTTP** (Día 6): Traefik 3.7.16 (chart 42.1.3) en el namespace `traefik`, desde un manifiesto renderizado con `helm template` (`infra/traefik/traefik.yaml`); CRDs de Gateway API v1.6.3, canal estándar (`infra/gateway-api/`); un `Gateway` `lab-gateway` y una `HTTPRoute` `lab-routes` (host `lab.local`: `/` va a `web` y `/api` a `api`). No hay Ingress ni ingress-nginx.
- Las imágenes van fijadas por digest (`@sha256:…`).

> Estado de este README: escrito el 2026-10-25 y actualizado el 2026-10-29 (Día 6) con lo que ya está en el repo y en `evidence/`. Si algo no aparece en la evidencia, aquí no se afirma.

## Requisitos y versiones usadas

| Herramienta | Versión observada | Dónde consta |
|---|---|---|
| kind | v0.33.0 (go1.26.7 windows/amd64) | `evidence/dia-01/00-entorno.txt` |
| kubectl (cliente) | v1.37.1 | `evidence/dia-01/00-entorno.txt` |
| Kubernetes (servidor / nodos) | v1.37.0 | `evidence/dia-01/00-entorno.txt` |
| Trivy | 0.75.0 | `evidence/dia-01/00-entorno.txt` |
| gitleaks (hook) | v8.30.1 | `.pre-commit-config.yaml` |
| pre-commit-hooks | v6.0.0 | `.pre-commit-config.yaml` |
| conventional-precommit-linter | v1.11.0 | `.pre-commit-config.yaml` |
| Traefik | v3.7.16 (chart `traefik-42.1.3`) | `infra/traefik/traefik.yaml`, `evidence/dia-06/01-controlador.txt` |
| CRDs de Gateway API | v1.6.3, canal estándar | `infra/gateway-api/standard-install-v1.6.3.yaml` |
| Helm | no consta | se usó para renderizar `traefik.yaml`; su versión no quedó en la evidencia |

- Entorno de trabajo: Windows + Git Bash; los nodos de kind corren sobre un kernel WSL2 (`evidence/dia-01/00-entorno.txt`).
- `kind/kind-config.yaml` **no fija la imagen de los nodos** (`kindest/node`), así que la versión de Kubernetes depende de la versión de kind que uses. Con otra versión de kind, el servidor puede no ser v1.37.0.
- En Git Bash, los argumentos con rutas absolutas se reescriben (conversión de rutas de MSYS): `kubectl run … -- /bin/sh` se escribe `-- //bin/sh` (ver `evidence/dia-02/02-conectivity.txt`).

## Estructura del repo

```text
.
├── kind/kind-config.yaml        # clúster: 1 control-plane + 2 workers
├── infra/                       # componentes de terceros versionados (Día 6)
│   ├── gateway-api/standard-install-v1.6.3.yaml  # CRDs de Gateway API (canal estándar)
│   └── traefik/
│       ├── namespace.yaml       # namespace traefik
│       ├── values.yaml          # valores usados con helm template
│       ├── traefik.yaml         # manifiesto renderizado (chart 42.1.3, Traefik 3.7.16)
│       └── gateway.yaml         # Gateway lab-gateway (solo acepta rutas del namespace lab)
├── manifests/
│   ├── namespace.yaml           # namespace lab
│   ├── web-configmap.yaml       # default.conf de nginx
│   ├── web-deployment.yaml      # web x3, probes, requests = limits
│   ├── web-service.yaml         # Services web y web-headless
│   ├── db-pvc.yaml              # PVC db-pvc (standard, RWO)
│   ├── db-deployment.yaml       # MySQL con el PVC montado
│   ├── db-service.yaml          # Service db
│   ├── api.yaml                 # Deployment y Service api (whoami x2)
│   └── routes.yaml              # HTTPRoute lab-routes (lab.local)
├── docs/dia-NN-*.md             # nota de cada día: objetivo, criterios, decisiones, preguntas
├── evidence/dia-NN/*.txt        # salida real de los comandos, con hora y comando
├── .pre-commit-config.yaml      # gitleaks, end-of-file-fixer, commits convencionales
└── .gitignore                   # secrets/  *.env  .env*  kubeconfig*
```

El Secret no tiene manifiesto en `manifests/` a propósito.

## Levantar el clúster

El nombre del clúster es `lab` (los nodos se llaman `lab-control-plane`, `lab-worker`, `lab-worker2` y el contexto es `kind-lab`):

```bash
kind create cluster --name lab --config kind/kind-config.yaml
kubectl config use-context kind-lab
kubectl get nodes
```

`kind-config.yaml` publica los puertos 80 y 443 del control-plane en `127.0.0.1` y le pone la etiqueta `ingress-ready=true`. Traefik usa esos puertos con `hostPort` en ese nodo (ver [Exposición HTTP](#exposición-http-día-6)).

## Recrear el laboratorio

> ⚠️ **Hoy no es un comando único.** Son 3 pasos para el laboratorio, más 4 para la exposición HTTP (ver [Exposición HTTP](#exposición-http-día-6)), y el orden importa. El criterio 7 del Día 5 pide un solo comando y está en estado parcial; el criterio 7 del Día 6 (recrear con la exposición HTTP) no se realizó (ver [Limitaciones conocidas](#limitaciones-conocidas)).

**1. Crear el namespace primero.** `kubectl apply -f manifests/` procesa los archivos en orden alfabético y `db-*.yaml` va antes que `namespace.yaml`; sin el namespace, falla con `namespaces "lab" not found` (`evidence/dia-05/07-recreacion.txt`, 17:43 UTC).

```bash
kubectl apply -f manifests/namespace.yaml
```

**2. Crear el Secret sin escribir su valor en ningún archivo del repo.** La contraseña vive en una variable de tu sesión (`MYSQL_PWD`); el YAML solo contiene la referencia a la variable y viaja por stdin, no por la línea de comandos:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: lab
type: Opaque
stringData:
  password: "$MYSQL_PWD"
EOF
```

En la prueba de las 17:46 UTC, sin crear el Secret, el Pod de `db` quedó en `CreateContainerConfigError` (`evidence/dia-05/07-recreacion.txt`, 18:40 UTC): el contenedor toma `MYSQL_ROOT_PASSWORD` de `mysql-secret`, y si ese Secret no existe no puede arrancar.

**3. Aplicar el resto:**

```bash
kubectl apply -f manifests/
kubectl get pods -n lab
kubectl get pvc -n lab
```

Resultado observado (`evidence/dia-05/07-recreacion.txt`, 19:00 UTC del 2026-10-25), unos 20 s después del `apply`:

| Objeto | Estado observado |
|---|---|
| Pods `web` | 3 Pods, cada uno `1/1 Running` |
| Pod `db` | `1/1 Running` |
| PVC `db-pvc` | `Bound`, 20Mi, RWO, `standard` |

Tiempos medidos con `time`: `apply` del namespace 0,9 s y `apply -f manifests/` 2,0 s. El "unos 20 s hasta `Running`" sale de la columna `AGE`, no de una espera medida de principio a fin.

### Cómo comprobar que `db` está de verdad listo

`db` **no tiene `readinessProbe`**, así que `READY 1/1` solo significa que el contenedor arrancó, no que MySQL acepte conexiones. Para saberlo, mira el log:

```bash
kubectl logs -n lab deploy/db | grep -i "ready for connections"
```

### Qué pasa con los datos

- Al borrar el namespace se borra el PVC y, con la política `Delete` del PV, también el dato: `db` arranca vacío en cada recreación.
- Borrar solo el Pod, o escalar `db` a 0 y volver a 1, conserva los datos (`evidence/dia-05/03-delete-pod.txt`, `04-scale.txt`).
- El PV de `standard` es local a un nodo: en `evidence/dia-05/01-pvc.txt` queda ligado a `lab-worker2` (`Node Affinity`, `Reclaim Policy: Delete`). Si ese nodo se pierde, el dato también.

## Exposición HTTP (Día 6)

> ⚠️ **No probado desde cero.** El criterio 7 del Día 6 (recrear todo siguiendo este README) no se realizó. El orden sale de las dependencias y de lo que se aplicó el 2026-10-28 en `evidence/dia-06/01-controlador.txt` (21:34 a 22:35 UTC); no consta una recreación con el clúster vacío.

Orden (cada paso necesita el anterior):

1. **CRDs de Gateway API**, de la versión que corresponde a Traefik 3.7.16: `kubectl apply -f infra/gateway-api/standard-install-v1.6.3.yaml` (10 CRDs más una `ValidatingAdmissionPolicy` y su binding).
2. **Namespace del controlador:** `kubectl apply -f infra/traefik/namespace.yaml`.
3. **Controlador:** `kubectl apply -f infra/traefik/traefik.yaml` (ServiceAccount, ClusterRole y ClusterRoleBinding, Service, Deployment y `GatewayClass`). Comprueba con `kubectl -n traefik get pods` que el Pod esté `1/1`.
4. **Gateway:** `kubectl apply -f infra/traefik/gateway.yaml`.
5. **El laboratorio** de la sección anterior (namespace, Secret y `kubectl apply -f manifests/`). `api.yaml` y `routes.yaml` están en `manifests/`, y `routes.yaml` falla si los pasos 1 y 4 no se hicieron antes.

`infra/traefik/traefik.yaml` es un render de Helm: el chart es `traefik-42.1.3` (etiqueta `helm.sh/chart` del propio manifiesto) y los valores están en `infra/traefik/values.yaml`. La línea exacta de `helm template` no quedó registrada en la evidencia.

Pruebas (sin tocar `/etc/hosts`; el host va en la cabecera):

```bash
curl -si -H "Host: lab.local" http://127.0.0.1/        # 200, página de nginx (web)
curl -si -H "Host: lab.local" http://127.0.0.1/api     # 200, responde un Pod de api
curl -si -H "Host: lab.local" http://127.0.0.1/apix    # 404 generado por nginx (la ruta cae en web)
curl -si -H "Host: otro.local" http://127.0.0.1/       # 404 "404 page not found", generado por Traefik
```

Resultados observados el 2026-10-28, 23:46 a 23:48 UTC (`evidence/dia-06/02-web.txt`, `03-api.txt`, `04-404.txt`).

Qué sobrevive si se borra solo el namespace `lab`: Traefik, el `Gateway` y los CRDs viven en `traefik` o a nivel de clúster, así que no se borran; la `HTTPRoute` vive en `lab` y sí. Esto sale de dónde está cada objeto; no se probó.

## Seguridad y convenciones

- Ningún valor de contraseña va en archivos del repo, en `evidence/` ni en las notas. Lo vigilan `.gitignore` y el hook de `gitleaks`; antes de cada commit se revisa con `grep -rlF` sobre `README.md`, `evidence`, `docs`, `manifests` e `infra`.
- Commits convencionales (`feat:`, `docs:`, `fix:`, `chore:`), validados por el hook `commit-msg`.
- Cada día cierra con un tag `dia-NN`. Las evidencias son salida real de comandos, con hora y comando, y el criterio de aceptación no se edita después de ver el resultado.
- Para instalar los hooks: `pre-commit install --hook-type pre-commit --hook-type commit-msg`.

## Progreso

| Día | Tema | Estado | Tag | Nota |
|---|---|---|---|---|
| 1 | Deployment | ✅ | `dia-01` | [docs/dia-01-deployment.md](docs/dia-01-deployment.md) |
| 2 | Service y DNS | ✅ con deuda | `dia-02` | [docs/dia-02-service.md](docs/dia-02-service.md) |
| 3 | ConfigMap y Secret | ⚠️ con deuda | `dia-03` | [docs/dia-03-configmap-secret.md](docs/dia-03-configmap-secret.md) |
| 4 | Probes y recursos | ⚠️ con deuda | `dia-04` | [docs/dia-04-probes-recursos.md](docs/dia-04-probes-recursos.md) |
| 5 | Persistencia (MySQL con PVC) y cierre del hito | ⚠️ con deuda | `dia-05` | [docs/dia-05-persistencia.md](docs/dia-05-persistencia.md) |
| 6 | Exposición HTTP (Traefik con Gateway API) | ⚠️ con deuda | `dia-06` | [docs/dia-06-exposicion-http.md](docs/dia-06-exposicion-http.md) |
| 7–10 | Segunda semana | por hacer | — | — |

## Limitaciones conocidas

Es lo que sigue sin corregir o sin demostrar hoy. Las filas "no corregido" salen de la tabla de deuda de [docs/dia-05-persistencia.md](docs/dia-05-persistencia.md); el resto son observaciones sobre los manifiestos y las evidencias actuales. Las deudas del Día 6 (D6-1 a D6-8) están declaradas en la sección «Deuda del día» de [docs/dia-06-exposicion-http.md](docs/dia-06-exposicion-http.md).

**Declaradas como "no corregido" (motivo en la tabla de deuda: "sin tiempo", o cierre del Día 5 sin pagarlas)**

| Deuda | Qué falta |
|---|---|
| 0a | Digest en ejecución == digest del manifiesto: la evidencia del Día 1 muestra la imagen declarada en el Deployment, no el `imageID` del Pod |
| 0b | Regla de fin de línea en el repo (`.gitattributes`, `.editorconfig`, hook) |
| 0c | Prueba del selector (pregunta 4 del Día 2) |
| D3-2 | Mostrar que un archivo montado desde el ConfigMap cambia sin reiniciar el Pod |
| D3-3 | Secret: largo esperado frente al real |
| D3-4 | Parcial: contraseña fuera de la línea de comandos (ver `--env=MYSQL_PWD=$VARIABLE` más abajo) |
| D3-6 | Preguntas 1–4 y autoauditoría de la nota del Día 3 |
| D4-1 | `describe pod` actual y justificación de 500m/128Mi |
| D4-2 | Liveness con `RESTARTS` ≥ 2 |
| D4-3 | Reservas del criterio 2 del Día 4 (zona horaria, instantes, quién respondió) |
| D4-4 | Nota del Día 4: hora de predicciones, tres líneas, 🧪 y 📚, preguntas con evidencia |
| D5-1 | Estrategia de `db` alineada con la evidencia: hoy `RollingUpdate` con volumen RWO (≈4 s con dos Pods en `05-rollout.txt`) |
| D5-2 | Recreación con un solo comando y tiempo medido hasta Ready (incluye comprobar que `db` acepta conexiones) |
| D5-3 | Bonus: `reclaimPolicy` (qué pasa con el PV y los datos al borrar el PVC) |
| D5-4 | Reservas de evidencia del Día 5 (consultas SQL no registradas, `05` sin `ev`, cambio del Secret sin comando en `06`), bitácora, 🧪, minutos, tres líneas y preguntas con evidencia |

**Observadas en los manifiestos y evidencias**

- **Recreación en varios pasos** (3 del laboratorio y 4 de la exposición HTTP), no en un comando (D5-2; Día 5, criterio 7 parcial). La recreación con la exposición HTTP no se probó desde cero (Día 6, criterio 7). No hay carpeta `scripts/` ni `kustomization.yaml`.
- **`db` sin probes**: no hay forma automática de saber si MySQL ya acepta conexiones.
- **`db` con `RollingUpdate`** (D5-1), 1 réplica y un volumen RWO: en la prueba de `evidence/dia-05/05-rollout.txt` el Pod nuevo pasó a `Running` a las 16:46:39 y el viejo empezó a `Terminating` a las 16:46:40 y llegó a `Completed` a las 16:46:43, los dos en `lab-worker2` y con el mismo PVC. Con `Recreate` (16:43:49 a 16:43:54) no hubo solapamiento. Dos MySQL sobre el mismo directorio de datos es un riesgo real. Las horas de ese archivo no indican zona; por la edad del Pod en evidence/dia-05/06-rotacion.txt son UTC.
- **Anotación de prueba** `test: "rollout with a rolloutUpdate strategy"` en el template de `db`: se quedó de la prueba de rollout y fuerza un Pod nuevo si se edita.
- **PVC de 20Mi**: tamaño poco realista para MySQL; el aprovisionador local-path de kind no hace cumplir la capacidad, por eso funciona.
- **Contraseña en la línea de comandos de los clientes de prueba**: las evidencias `02`, `03`, `04` y `06` del Día 5 usan `--env=MYSQL_PWD=$VARIABLE` en `kubectl run`. El valor no aparece en los archivos del repo, pero sí en los argumentos locales de kubectl y en el spec del Pod efímero (pregunta abierta desde el Día 3).
- **Secret por interpolación**: el heredoc del paso 2 mete la variable dentro de un YAML entre comillas; una contraseña con `"` o `\` rompería el YAML.
- **Un solo nodo guarda el dato** (`lab-worker2`, ver arriba). No hay réplica ni respaldo.
- **Imagen de los nodos de kind sin fijar** (ver Requisitos).
- **Solo HTTP, sin TLS**: el `Gateway` tiene un único listener (`web`, puerto 8000 del contenedor); el bonus de HTTPS del Día 6 no se hizo.
- **Permisos amplios de Traefik**: la `ClusterRole` `traefik-traefik` da `get`, `list` y `watch` sobre `secrets` en todo el clúster. Hoy el laboratorio no usa TLS en el controlador. Se retoma en el Día 7.
- **Traefik con 1 réplica y `hostPort`** en `lab-control-plane`: un solo punto de entrada, y no escala con más réplicas porque el puerto del nodo es uno.
- **Tres versiones a mano**: el tag y el digest de la imagen (`values.yaml`), el chart y los CRDs de Gateway API se actualizan por separado. Según la guía de migración de Traefik, la versión de Gateway API que soporta cambia entre parches de la 3.7, así que subir uno sin los otros puede desfasarlos.
- **`api` es `traefik/whoami`**: devuelve las cabeceras de la petición. Sirve para probar, no es una aplicación.
- **ingress-nginx retirado** (marzo de 2026): no se usa; el laboratorio no tiene recursos Ingress.
