# Día 02 — Service y DNS
**Fecha:** 2026-10-13 · **Tiempo:** 120' (planificado: 30')

## 🎯 Objetivo medible
Darle a `web` una identidad de red estable y entender cómo se descubre por nombre

## 🧩 Predicciones
- ¿Resuelve el nombre corto web desde lab? ¿Y desde default?

Para que el nombre corto funcioné debe estar el Service creado en el mismo namespace que el deployment y el pod efímero.

- ¿Cuántas IPs devuelve nslookup web y cuántas nslookup web-headless?

El web devuelve la IP del ClusterIP, web-headless devuelve las IPs de los 3 Pods

- Si borras un Pod, ¿qué cambia en el EndpointSlice y qué no cambia en el Service?

Al borrar un pod se elimina esa configuración del EndpointSlice, el Service se mantiene igual.

## Preguntas

- ¿Por qué web resuelve dentro de lab pero no desde default? Muestra algo concreto, dentro del Pod, que lo explique.

Porque el Service creado en lab configura un DNS para resolver web hacia web.lab.svc.cluster.local. En default no existe ese registro.

- ¿Qué campo de tu YAML une el Service con los Pods y qué recurso materializa esa unión?

El atributo selector es el que relaciona el Service con los Pods. El recurso EndpointSlice registra la unión del Services y los Pods.

- ¿Qué cambia para un cliente con el Service headless, y cuándo preferirías uno u otro?

El Services headless expone las IPs de cada pod en vez de la IP del cluster. Headless sirve para acceder al pod especifico de un StateFulSet por ejemplo para las bases de datos que usan pods como replicas. ClusterIP sirve para pods stateless por ejemplo microservicios que los pods pueden escalar y no es necesario diferenciarlos.

- ¿Qué pasa si el selector no coincide con ninguna etiqueta?

El Service se crea pero sin Pods hacia donde enrutar el tráfico.

## Preguntas de troubleshooting (Nivel 1)

- La ClusterIP ¿Qué tipo de dirección es y qué componente hace que responda?

Es una IP virtual creada por el Service y que es visible desde cualquier parte dentro del Cluster. El kube-proxy es quien coloca reglas a nivel de kernel linux en los nodos para interceptar el trafico y enrutarlo hacia los Pods.

- Nombre corto. El FQDN funciona desde default y el corto no. Dentro del Pod de prueba, ¿qué archivo muestra los dominios que se prueban, y en qué orden? Muéstralo desde lab y desde default, y compáralos.

desde lab
$ cat /etc/resolv.conf
search lab.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

desde default
$ cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

# Día 02 — Service y DNS
**Fecha:** 2026-10-13 · **Tiempo:** 120' (planificado: 30') + 10' de cierre el 2026-10-14 · **Estado:** ⚠️ parcial → ✅ al re-capturar 04, 05 y probar la pregunta 4

## 🎯 Objetivo medible
Darle a `web` una identidad de red estable y entender cómo se descubre por nombre: ClusterIP 80→8080, FQDN con 200, EndpointSlice con 3 IPs que cambia al borrar un Pod, `nslookup` normal vs headless.

## 🧩 Predicciones
- ¿Resuelve el nombre corto web desde lab? ¿Y desde default?

Para que el nombre corto funcioné debe estar el Service creado en el mismo namespace que el deployment y el pod efímero.

- ¿Cuántas IPs devuelve nslookup web y cuántas nslookup web-headless?

El web devuelve la IP del ClusterIP, web-headless devuelve las IPs de los 3 Pods

- Si borras un Pod, ¿qué cambia en el EndpointSlice y qué no cambia en el Service?

Al borrar un pod se elimina esa configuración del EndpointSlice, el Service se mantiene igual.

## 🧩 Problema
Desde un Pod en `default`, `curl web` falla con `Could not resolve host: web`, aunque desde `lab` responde 200. El FQDN `web.lab.svc.cluster.local` responde 200 desde ambos namespaces. Evidencia: `evidence/dia-02/03-default-namespace.txt`.

## 🔍 Bitácora de depuración
| # | Hipótesis | Comando | Resultado | ¿Descartada? |
|---|-----------|---------|-----------|--------------|
| 1 | El Service no existe o no enruta | `kubectl get svc,endpointslices -n lab` | ClusterIP `10.96.80.8` y slice con 3 IPs | ✅ descartada |
| 2 | El nombre corto depende del namespace del cliente | `cat /etc/resolv.conf` en `lab` y en `default` | Solo cambia el primer dominio del `search` | ❌ confirmada |
| 3 | El FQDN no depende del namespace del cliente | `curl web.lab.svc.cluster.local` desde `default` | 200 | ❌ confirmada |

## 🛠️ Causa raíz
Cuando escribes `web` en un Pod de `default` el /etc/resolv.conf lo convierte a web.default.svc.cluster.local que corresponde a la instrucción de la primera linea: search default.svc.cluster.local svc.cluster.local cluster.local

## ✅ Solución definitiva
No hay cambio de manifiesto: el comportamiento es el esperado. Regla de uso: dentro del mismo namespace, nombre corto; entre namespaces, `<svc>.<ns>` o el FQDN.

## 🧪 Verificación reproducible
```bash
kubectl get svc -n lab            # web: ClusterIP 80/TCP · web-headless: CLUSTER-IP None
kubectl get endpointslices -n lab --show-labels
kubectl get pods -n lab -o wide   # las IPs coinciden con el slice
# desde un Pod efímero (imagen con tag fijo, no root):
curl -s -o /dev/null -w "%{http_code}\n" web                          # 200 en lab; falla en default
curl -s -o /dev/null -w "%{http_code}\n" web.lab.svc.cluster.local    # 200 en ambos
```

## ❓ Preguntas
- ¿Por qué web resuelve dentro de lab pero no desde default? Muestra algo concreto, dentro del Pod, que lo explique.

Porque el Service creado en lab configura un DNS para resolver web hacia web.lab.svc.cluster.local. En default no existe ese registro.

- ¿Qué campo de tu YAML une el Service con los Pods y qué recurso materializa esa unión?

El atributo selector es el que relaciona el Service con los Pods. El recurso EndpointSlice registra la unión del Services y los Pods.

- ¿Qué cambia para un cliente con el Service headless, y cuándo preferirías uno u otro?

El Services headless expone las IPs de cada pod en vez de la IP del cluster. Headless sirve para acceder al pod especifico de un StateFulSet por ejemplo para las bases de datos que usan pods como replicas. ClusterIP sirve para pods stateless por ejemplo microservicios que los pods pueden escalar y no es necesario diferenciarlos.

- ¿Qué pasa si el selector no coincide con ninguna etiqueta?

El Service se crea pero sin Pods hacia donde enrutar el tráfico.

## Preguntas de troubleshooting (Nivel 1)

- La ClusterIP ¿Qué tipo de dirección es y qué componente hace que responda?

Es una IP virtual creada por el Service y que es visible desde cualquier parte dentro del Cluster. El kube-proxy es quien coloca reglas a nivel de kernel linux en los nodos para interceptar el trafico y enrutarlo hacia los Pods.

- Nombre corto. El FQDN funciona desde default y el corto no. Dentro del Pod de prueba, ¿qué archivo muestra los dominios que se prueban, y en qué orden? Muéstralo desde lab y desde default, y compáralos.

desde lab
$ cat /etc/resolv.conf
search lab.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

desde default
$ cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

## 🔎 Revisión del mentor (estado al 13 oct)
🎯 ✅ criterios 1, 2, 3 y 6; 4, 5 y 7 mejoran al re-capturar · 🔐 ⚠️ Pod de prueba sin tag fijo y como root (a corregir con la imagen nueva) · 📈 ✅ ClusterIP vs headless entendido · 🧰 ⚠️ nombres de evidencia con erratas y alias `k` en las salidas
