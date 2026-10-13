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
