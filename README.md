# k8s-hands-on

Laboratorio práctico de Kubernetes de 2 semanas (10 sesiones acumulativas) sobre un clúster local con [kind](https://kind.sigs.k8s.io/). 

Qué queda desplegado (namespace `lab`, y `traefik` para la exposición HTTP):

- **`web`**: 3 réplicas en el manifiesto (el HPA del Día 10 las gobierna entre 2 y 5) de `nginxinc/nginx-unprivileged` (puerto 8080, usuario sin privilegios), con probes `startup`/`readiness`/`liveness` en rutas separadas y `requests` = `limits` (QoS Guaranteed). Services `web` (ClusterIP :80) y `web-headless`.
- **`db`**: MySQL de 1 réplica (Deployment) con un PVC (`db-pvc`, StorageClass `standard`) montado en `/var/lib/mysql`. Service `db` (:3306).
- **Configuración**: ConfigMap `web-config` (`default.conf` de nginx) y Secret `mysql-secret` (clave `password`), este último **fuera del repo**.
- **`api`**: 2 réplicas de `traefik/whoami:1.12.0` (por digest, puerto 8080, sin root, `requests` = `limits`), un backend de prueba que devuelve la petición que recibe. Service `api` (ClusterIP :80).
- **Exposición HTTP** (Día 6): Traefik 3.7.16 (chart 42.1.3) en el namespace `traefik`, desde un manifiesto renderizado con `helm template` (`infra/traefik/traefik.yaml`); CRDs de Gateway API v1.6.3, canal estándar (`infra/gateway-api/`); un `Gateway` `lab-gateway` y una `HTTPRoute` `lab-routes` (host `lab.local`: `/` va a `web` y `/api` a `api`). No hay Ingress ni ingress-nginx.
- **RBAC** (Día 7): ServiceAccount `deployer` con un `Role` mínimo (`get` y `patch` sobre `deployments`, solo en `lab`), y los Pods de `web` sin token de la API (`automountServiceAccountToken: false`).
- **Hardening y Pod Security** (Día 8): `web` con `securityContext` completo (no-root, sin escalada de privilegios, `drop: ["ALL"]`, seccomp `RuntimeDefault`, raíz de solo lectura con un `emptyDir` en `/tmp`); `lab` impone Pod Security `baseline` y avisa y audita con `restricted`.
- **NetworkPolicy** (Día 9): `default-deny` (Ingress y Egress) en `lab` y cinco políticas de permiso mínimo: DNS para todos los Pods, Traefik → `web` y `api` por el puerto 8080, y `web` → `db` por el 3306 (salida de `web` y entrada de `db`).
- **Autoescalado y PDB** (Día 10): metrics-server v0.9.1 en `kube-system` (con `--kubelet-insecure-tls`, solo para laboratorio), un HPA `web` (mínimo 2, máximo 5, CPU 1% de los 500m solicitados, ventana de bajada de 60 s) y un PDB `web` con `minAvailable: 2`.
- Las imágenes van fijadas por digest (`@sha256:…`), salvo la de metrics-server (Día 10), que solo lleva el tag `v0.9.1`.

> Estado de este README: escrito el 2026-10-25 y actualizado el 2026-10-29 (Días 6 y 7) y el 2026-11-02 (Día 8) y el 2026-11-04 (Día 9) y el 2026-11-05 (Día 10, cierre del plan) con lo que ya está en el repo y en `evidence/`. Si algo no aparece en la evidencia, aquí no se afirma.

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
| metrics-server | v0.9.1 (`registry.k8s.io/metrics-server/metrics-server:v0.9.1`, por tag) | `infra/metrics-server/components-v0.9.1.yaml`, `evidence/dia-10/02-metrics.txt` |
| Helm | no consta | se usó para renderizar `traefik.yaml`; su versión no quedó en la evidencia |

- Entorno de trabajo: Windows + Git Bash; los nodos de kind corren sobre un kernel WSL2 (`evidence/dia-01/00-entorno.txt`).
- `kind/kind-config.yaml` **no fija la imagen de los nodos** (`kindest/node`), así que la versión de Kubernetes depende de la versión de kind que uses. Con otra versión de kind, el servidor puede no ser v1.37.0.
- En Git Bash, los argumentos con rutas absolutas se reescriben (conversión de rutas de MSYS): `kubectl run … -- /bin/sh` se escribe `-- //bin/sh` (ver `evidence/dia-02/02-conectivity.txt`).

## Estructura del repo

```text
.
├── kind/kind-config.yaml        # clúster: 1 control-plane + 2 workers
├── infra/                       # componentes de terceros versionados (Días 6 y 10)
│   ├── gateway-api/standard-install-v1.6.3.yaml  # CRDs de Gateway API (canal estándar)
│   ├── metrics-server/components-v0.9.1.yaml     # metrics-server v0.9.1 + --kubelet-insecure-tls (Día 10)
│   └── traefik/
│       ├── namespace.yaml       # namespace traefik
│       ├── values.yaml          # valores usados con helm template
│       ├── traefik.yaml         # manifiesto renderizado (chart 42.1.3, Traefik 3.7.16)
│       └── gateway.yaml         # Gateway lab-gateway (solo acepta rutas del namespace lab)
├── manifests/
│   ├── namespace.yaml           # namespace lab y etiquetas de Pod Security (Día 8)
│   ├── web-configmap.yaml       # default.conf de nginx
│   ├── web-deployment.yaml      # web x3, probes, requests = limits, securityContext (Día 8)
│   ├── web-service.yaml         # Services web y web-headless
│   ├── db-pvc.yaml              # PVC db-pvc (standard, RWO)
│   ├── db-deployment.yaml       # MySQL con el PVC montado
│   ├── db-service.yaml          # Service db
│   ├── api.yaml                 # Deployment y Service api (whoami x2)
│   ├── routes.yaml              # HTTPRoute lab-routes (lab.local)
│   ├── rbac.yaml                # ServiceAccount deployer, Role y RoleBinding (Día 7)
│   ├── netpol.yaml              # 6 NetworkPolicy de lab: default-deny y permisos mínimos (Día 9)
│   └── hpa-pdb.yaml             # HPA y PDB de web (Día 10)
├── scripts/                     # dia-NN.sh: Parte 0 y evidencia (desde el Día 7)
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

> ⚠️ **Hoy no es un comando único.** Son 3 pasos para el laboratorio, más 4 para la exposición HTTP (ver [Exposición HTTP](#exposición-http-día-6)) y 2 para el autoescalado (ver [Autoescalado y PDB](#autoescalado-y-pdb-día-10)), y el orden importa. El criterio 7 del Día 5 pide un solo comando y está en estado parcial; el criterio 7 del Día 6 (recrear con la exposición HTTP) no se realizó (ver [Limitaciones conocidas](#limitaciones-conocidas)).

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

## RBAC (Día 7)

`manifests/rbac.yaml` crea la ServiceAccount `deployer`, un `Role` y un `RoleBinding` en `lab`. El Role permite `get` y `patch` sobre `deployments` (grupo `apps`) y nada más. `web` no monta el token de la API (`automountServiceAccountToken: false` en `web-deployment.yaml`).

Comprobación (esperado: `yes`, `no`, `no`, `no`):

```bash
WHO=system:serviceaccount:lab:deployer
kubectl auth can-i patch deployments -n lab --as=$WHO
kubectl auth can-i get secrets -n lab --as=$WHO
kubectl auth can-i patch deployments -n default --as=$WHO
kubectl auth can-i create clusterrolebindings --as=$WHO
```

`bash scripts/dia-07.sh check` hace esas pruebas y deja la evidencia en `evidence/dia-07/`. `kubectl apply -f manifests/` aplica `rbac.yaml` sin un orden especial.

## Hardening y Pod Security (Día 8)

`manifests/namespace.yaml` etiqueta `lab` con Pod Security Admission: `enforce: baseline` (el servidor rechaza Pods privilegiados y otras escaladas conocidas), `warn: restricted` y `audit: restricted` (avisan de lo que faltaría para `restricted`, sin rechazar nada). `enforce` no está en `restricted` porque `db` (MySQL) corre como root y sin `securityContext`: con ese nivel sus Pods nuevos serían rechazados. Los Pods que ya corren no se desalojan. No se etiquetó el namespace `traefik`: su Pod usa `hostPort`, que `baseline` no permite.

`web` cumple `restricted` (`manifests/web-deployment.yaml`): `runAsNonRoot` con UID 101, `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]` y `readOnlyRootFilesystem: true`. Con la raíz de solo lectura, `/tmp` es un `emptyDir` (el readiness del Día 4 busca ahí `/tmp/romper_readiness`). No se probó qué pasa sin ese `emptyDir`.

Comprobación (esperado: sin aviso para `web`, con aviso para `db`):

```bash
kubectl get ns lab --show-labels
kubectl apply --dry-run=server -f manifests/web-deployment.yaml   # sin "would violate PodSecurity"
kubectl apply --dry-run=server -f manifests/db-deployment.yaml    # avisa: db corre como root
```

`bash scripts/dia-08.sh check` hace esas pruebas, revisa los 3 Pods de `web` y comprueba que un Pod con `privileged: true` es rechazado (`kubectl create --dry-run=server`, no crea nada). Deja la evidencia en `evidence/dia-08/`. Resultados observados el 2026-11-02, 15:57 UTC.

## NetworkPolicy (Día 9)

`manifests/netpol.yaml` crea 6 NetworkPolicy en `lab`. El archivo pone `default-deny` al final para no cortar tráfico mientras se aplica; una vez aplicadas, el orden no cambia el resultado (las políticas se suman).

| Política | Qué hace |
|---|---|
| `default-deny` | Selecciona todos los Pods de `lab` y declara `Ingress` y `Egress` sin reglas: lo que ninguna otra política permita, se descarta |
| `allow-dns` | Todos los Pods pueden salir hacia CoreDNS (Pods `k8s-app=kube-dns` de `kube-system`, puerto 53 UDP y TCP). Sin ella, `default-deny` corta la resolución de nombres |
| `web-ingress` | `web` solo recibe de los Pods de Traefik, por el puerto 8080 |
| `api-ingress` | Igual para `api` (puerto 8080) |
| `db-ingress` | `db` solo recibe de los Pods `app=web`, por el puerto 3306 |
| `web-to-db` | `web` puede salir hacia los Pods `app=db`, por el puerto 3306 |

Las reglas hablan del puerto del Pod (8080 y 3306), no del puerto 80 del Service. En `web-ingress` y `api-ingress`, el `namespaceSelector` (`kubernetes.io/metadata.name: traefik`) y el `podSelector` (`app.kubernetes.io/name: traefik`) van en el mismo elemento, así que valen juntos (Y). Un camino necesita los dos lados: `web` → `db` pide `web-to-db` (salida) y `db-ingress` (entrada); quitar solo `web-to-db` basta para que falle (opcional O1 del Día 9).

Comprobación (esperado: 3 pruebas funcionan y 3 agotan el tiempo):

| # | Prueba | Esperado |
|---|---|---|
| 1 | Traefik → `web` (`curl -H 'Host: lab.local' http://127.0.0.1/`) | funciona |
| 2 | Traefik → `api` (`curl -H 'Host: lab.local' http://127.0.0.1/api`) | funciona |
| 3 | `web` → `db`:3306 (`nc -z -w 3`) | funciona |
| 4 | Pod de `default` → `db`:3306 | falla por timeout |
| 5 | `web` → `api`:80 (`wget -T 3`) | falla por timeout |
| 6 | Pod de `default` → `web`:80 | falla por timeout |

```bash
bash scripts/dia-09.sh antes             # sin políticas: las 6 pruebas deben funcionar
kubectl apply -f manifests/netpol.yaml
bash scripts/dia-09.sh check            # criterios 1 a 3 y la matriz
```

Las pruebas 4 y 6 salen de un Pod `np-probe` que el script crea en `default` (misma imagen que `web`) y borra al terminar. Las hace cumplir el CNI de kind: el único DaemonSet de red en `kube-system` es `kindnet`. Resultados observados el 2026-11-04, 21:40 UTC (`evidence/dia-09/03-matriz.txt`): pruebas 1 a 3 en ≤1 s; pruebas 4 a 6 agotan el tiempo a los 4 s. `web` 3/3, `api` 2/2 y `db` 1/1 siguieron Ready, sin reinicios nuevos, 2'45" después de aplicar. En el opcional O1 (sin `web-to-db`), `web` → `db`:3306 falló con exit 1.

## Autoescalado y PDB (Día 10)

Tres piezas, en este orden:

1. **metrics-server v0.9.1** (`infra/metrics-server/components-v0.9.1.yaml`, namespace `kube-system`): el manifiesto oficial con una sola línea añadida, `--kubelet-insecure-tls`, porque los kubelet de kind usan certificados autofirmados. Solo sirve para laboratorio. La cabecera del archivo trae el sha256 del original.
2. **HPA `web`** (`manifests/hpa-pdb.yaml`): `autoscaling/v2`, mínimo 2, máximo 5, CPU `Utilization` 1% y `scaleDown.stabilizationWindowSeconds: 60` (por defecto son 300 s).
3. **PDB `web`** (mismo archivo): `policy/v1`, `minAvailable: 2`, selector `app: web`.

```bash
kubectl apply -f infra/metrics-server/components-v0.9.1.yaml
kubectl -n kube-system rollout status deploy/metrics-server
kubectl top nodes                       # debe listar los 3 nodos
bash scripts/dia-10.sh medir            # CPU por Pod de web en reposo y con carga (≈2 min)
kubectl apply -f manifests/hpa-pdb.yaml
bash scripts/dia-10.sh prueba           # sube con carga y drena un worker bajo carga (≈2 a 9 min)
bash scripts/dia-10.sh check            # criterios 1 a 3
```

El HPA compara el uso medio con `requests.cpu` (500m por Pod de `web`), así que 1% son 5m. `medir` midió 1m por Pod en reposo y 11m con carga (`evidence/dia-10/01-medicion.txt`, 3 Pods y 6 bucles de `wget`): el 50% del plan (250m por Pod) nunca se habría alcanzado. Se eligió 1% porque sube con las dos cargas posibles que dio la medición (27m y 33m en total); el 2% no se probó. Si recreas el laboratorio en otro entorno, vuelve a medir.

La carga la genera un Pod `np-load` en `default` (misma imagen que `web`) con bucles de `wget` contra el ClusterIP del Service de Traefik y `Host: lab.local`, el único camino que `web-ingress` admite. `medir` y `prueba` lo crean y lo borran; `CARGA_N` cambia el número de bucles (por defecto 6).

Resultados observados el 2026-11-05 (`evidence/dia-10/`, horas en UTC):

| Qué | Resultado |
|---|---|
| metrics-server | 1/1, APIService `Available=True` y los 3 nodos en `kubectl top nodes` (`02-metrics.txt`, 14:40) |
| CPU por Pod de `web` | reposo 1m; con carga 11m (11, 12 y 11m) (`01-medicion.txt`, 14:16 a 14:17) |
| Subida | de 2 a 3 Pods Ready a los 36 s y a 5 a los 49 s, con CPU 3% con 2 Pods (`03-hpa-carga.txt`, 14:30) |
| Bajada | al crear el HPA, `web` estaba en 3 (por `replicas: 3`) y bajó a 2 a los 50 s; a las 14:40 seguía en 2/2 (`03-hpa-carga.txt`, `05-estado.txt`) |
| Drain bajo carga | `lab-worker2` (3 de los 5 Pods de `web`): exit 0 en ≈7 s, 3 evicciones de `web`, 0 bloqueos y mínimo de 2 disponibles en 3 muestras (`04-drain.txt`, 14:31) |

Qué tener en cuenta:

- `kubectl apply -f manifests/web-deployment.yaml` (o `-f manifests/`) vuelve a fijar `replicas: 3` y el HPA lo corrige después. El campo no se quitó del manifiesto.
- Un PDB solo cubre las interrupciones voluntarias de los Pods que selecciona. El drain de la prueba también sacó a `metrics-server` y a un Pod de `api`, que no tienen PDB.
- Con `web` en 2 réplicas, un `drain` del worker que tenga uno de sus Pods quedaría esperando (acordona el nodo y reintenta cada 5 s); eso se razonó y no se ejecutó. Si cancelas un drain, haz `kubectl uncordon <nodo>`.
- `scripts/dia-10.sh prueba` elige un worker sin `db` y le hace `uncordon` al terminar. A mano, no drenes el nodo de `db` ni el control-plane.
- Sin metrics-server, el HPA no tendría métricas (sin probar).

## Seguridad y convenciones

- Ningún valor de contraseña va en archivos del repo, en `evidence/` ni en las notas. Lo vigilan `.gitignore` y el hook de `gitleaks`; antes de cada commit se revisa con `grep -rlF` sobre `README.md`, `evidence`, `docs`, `manifests`, `infra` y `scripts` (desde el Día 7 lo hace `bash scripts/dia-NN.sh pre`).
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
| 7 | RBAC de mínimo privilegio | ✅ | `dia-07` | [docs/dia-07-rbac.md](docs/dia-07-rbac.md) |
| 8 | Hardening de Pods y Pod Security Admission | ✅ | `dia-08` | [docs/dia-08-hardening.md](docs/dia-08-hardening.md) |
| 9 | NetworkPolicy (default-deny con permisos mínimos) | ✅ | `dia-09` | [docs/dia-09-networkpolicy.md](docs/dia-09-networkpolicy.md) |
| 10 | HPA y PDB | ✅ | `dia-10` | [docs/dia-10-hpa-pdb.md](docs/dia-10-hpa-pdb.md) |

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

- **Recreación en varios pasos** (3 del laboratorio y 4 de la exposición HTTP), no en un comando (D5-2; Día 5, criterio 7 parcial). La recreación con la exposición HTTP no se probó desde cero (Día 6, criterio 7). Los `scripts/dia-NN.sh` solo verifican cada día (`pre` y `check`); ninguno recrea el laboratorio, y no hay `kustomization.yaml`.
- **`db` sin probes**: no hay forma automática de saber si MySQL ya acepta conexiones.
- **`db` con `RollingUpdate`** (D5-1), 1 réplica y un volumen RWO: en la prueba de `evidence/dia-05/05-rollout.txt` el Pod nuevo pasó a `Running` a las 16:46:39 y el viejo empezó a `Terminating` a las 16:46:40 y llegó a `Completed` a las 16:46:43, los dos en `lab-worker2` y con el mismo PVC. Con `Recreate` (16:43:49 a 16:43:54) no hubo solapamiento. Dos MySQL sobre el mismo directorio de datos es un riesgo real. Las horas de ese archivo no indican zona; por la edad del Pod en evidence/dia-05/06-rotacion.txt son UTC.
- **Anotación de prueba** `test: "rollout with a rolloutUpdate strategy"` en el template de `db`: se quedó de la prueba de rollout y fuerza un Pod nuevo si se edita.
- **PVC de 20Mi**: tamaño poco realista para MySQL; el aprovisionador local-path de kind no hace cumplir la capacidad, por eso funciona.
- **Contraseña en la línea de comandos de los clientes de prueba**: las evidencias `02`, `03`, `04` y `06` del Día 5 usan `--env=MYSQL_PWD=$VARIABLE` en `kubectl run`. El valor no aparece en los archivos del repo, pero sí en los argumentos locales de kubectl y en el spec del Pod efímero (pregunta abierta desde el Día 3).
- **Secret por interpolación**: el heredoc del paso 2 mete la variable dentro de un YAML entre comillas; una contraseña con `"` o `\` rompería el YAML.
- **Un solo nodo guarda el dato** (`lab-worker2`, ver arriba). No hay réplica ni respaldo.
- **Imagen de los nodos de kind sin fijar** (ver Requisitos).
- **Solo HTTP, sin TLS**: el `Gateway` tiene un único listener (`web`, puerto 8000 del contenedor); el bonus de HTTPS del Día 6 no se hizo.
- **Permisos amplios de Traefik**: la `ClusterRole` `traefik-traefik` da `get`, `list` y `watch` sobre `secrets` en todo el clúster. Hoy el laboratorio no usa TLS en el controlador. No se retomó en el Día 7 (era opcional) y sigue abierto. El controlador necesita el token de la API (su Deployment lo monta: `automountServiceAccountToken: true`), así que lo que se puede acotar es el permiso, no el token.
- **Token de la API montado en `db`, `api` y Traefik**: solo `web` lo tiene desactivado (Día 7). `db` y `api` no lo necesitan y no se tocaron; Traefik sí lo necesita.
- **`deployer` sin uso real**: el Role `deployer` se verificó con `can-i --as` y con un `rollout restart`, pero ningún proceso lo usa todavía.
- **`db` fuera de `restricted`** (Día 8): corre como root y sin `securityContext`. Con `enforce: restricted` sus Pods nuevos serían rechazados, por eso `restricted` solo está en `warn` y `audit`. El aviso del servidor está en `evidence/dia-08/04-opcional-warnings.txt`. No se endureció `db`; Traefik tampoco se revisó.
- **Pod Security solo en `lab`**: `traefik` no tiene etiquetas (su Pod usa `hostPort`).
- **NetworkPolicy solo en `lab`** (Día 9): `traefik`, `default` y `kube-system` no tienen políticas. Traefik puede conectarse a cualquier destino y recibir de cualquier origen.
- **Matriz de NetworkPolicy parcial**: la prueba 5 (`web` → `api`) la bloquean a la vez la salida de `web` y la entrada de `api`, así que `api-ingress` solo está probada en positivo (prueba 2). No hay una prueba negativa desde otro Pod de `lab` (por ejemplo, `api` → `db`).
- **`web` → `db`:3306 permitido sin necesidad real**: nginx no usa MySQL. `web-to-db` y `db-ingress` existen porque el ejercicio pide ese camino; en una aplicación real se darían al servicio que sí lo usa.
- **Evidencia del O1 del Día 9 incompleta**: `evidence/dia-09/O1-sin-web-to-db.txt` termina con la prueba fallando, sin hora ni duración, y no muestra la restauración. El estado vivo sí consta: `evidence/dia-10/00-seguro.txt` (2026-11-05, 13:34 UTC) lista las 6 NetworkPolicy, con `web-to-db` de 15 h.
- **HPA y `replicas: 3`** (Día 10): `web-deployment.yaml` sigue con `replicas: 3` y el HPA también manda sobre las réplicas. Cada `apply` de ese archivo las vuelve a poner en 3 hasta que el HPA las corrige (al crear el HPA bajaron de 3 a 2 a los 50 s). No se quitó el campo (O2 del Día 10, no realizado).
- **Objetivo de CPU de 1% (5m por Pod)**: sale de una medición con 6 bucles de `wget` (1m en reposo, 11m con carga) y de requests de 500m. Es muy sensible: un nginx estático casi no usa CPU. Sirve para que el HPA reaccione en el laboratorio (36 s), no como valor de producción. El 2% no se probó.
- **El PDB nunca bloqueó una evicción**: en `evidence/dia-10/04-drain.txt` el PDB permitía 3 evicciones (5 − 2) y el nodo tenía 3 Pods de `web` (`bloqueos_pdb=0`). El caso bloqueado, con `web` en 2 réplicas, se razonó y no se ejecutó. El muestreo de disponibilidad fue de 3 puntos en ≈7 s.
- **El drain saca lo que no tiene PDB**: además de `web`, salieron `metrics-server` (1 réplica) y un Pod de `api`. `api`, `db` y `metrics-server` no tienen PDB.
- **Réplicas de `web` sin repartir**: los 2 Pods que quedaron a las 14:40 (`7rpbs` y `lrzrd`) figuran ambos en `lab-worker` en el listado de las 14:31 (`04-drain.txt`). No hay `topologySpreadConstraints` ni anti-afinidad (O3 del Día 10, no realizada), y Kubernetes no rebalancea tras el `uncordon`: un solo nodo caído dejaría `web` sin servicio.
- **metrics-server en modo laboratorio**: corre con `--kubelet-insecure-tls`, el manifiesto oficial trae el APIService con `insecureSkipTLSVerify: true`, y su imagen se fijó por tag (`v0.9.1`), no por digest.
- **Carga sintética**: solo sale de un Pod en `default` por el ClusterIP del Service de Traefik. Mide el camino Traefik → `web` con las NetworkPolicy puestas, no tráfico real.
- **Dónde corre `db` hoy (por revisar)**: este README dice que el PV está ligado a `lab-worker2` (Día 5), pero `prueba` drenó `lab-worker2` porque `db` corría en otro nodo (`04-drain.txt`) y el drain no sacó a `db`. Esa afirmación del Día 5 puede estar desactualizada; se comprueba con `kubectl get pv -o wide` y `kubectl -n lab get pods -o wide`.
- **Clientes de prueba en `lab` (sin probar)**: con `default-deny`, un Pod creado con `kubectl run` en `lab` (como los clientes MySQL del Día 5) no tiene política que le permita llegar a `db`. Habría que añadirla; es el opcional O2 del Día 9, no realizado.
- **`audit: restricted` sin comprobar**: no se revisó el registro de auditoría del API server, así que hoy `audit` solo deja la intención escrita.
- **Manifiestos que no coinciden con el clúster (sin verificar)**: `kubectl apply --dry-run=server -f manifests/` marca `db` y `lab-routes` como `configured` mientras el resto sale `unchanged` (`evidence/dia-08/00-seguro.txt`). No se investigó con `kubectl diff`. Sigue igual el 2026-11-04 (`evidence/dia-09/00-seguro.txt`, 21:59 UTC): `db` y `lab-routes` salen `configured` y las 6 NetworkPolicy `unchanged`.
- **Traefik con 1 réplica y `hostPort`** en `lab-control-plane`: un solo punto de entrada, y no escala con más réplicas porque el puerto del nodo es uno.
- **Tres versiones a mano**: el tag y el digest de la imagen (`values.yaml`), el chart y los CRDs de Gateway API se actualizan por separado. Según la guía de migración de Traefik, la versión de Gateway API que soporta cambia entre parches de la 3.7, así que subir uno sin los otros puede desfasarlos.
- **`api` es `traefik/whoami`**: devuelve las cabeceras de la petición. Sirve para probar, no es una aplicación.
- **ingress-nginx retirado** (marzo de 2026): no se usa; el laboratorio no tiene recursos Ingress.
