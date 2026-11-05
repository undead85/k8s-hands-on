#!/usr/bin/env bash
# Día 10 (HPA + PDB). Se ejecuta desde la raíz del repo:
#   bash scripts/dia-10.sh pre      # Parte 0 (nivel 1), estado del clúster y plantilla de predicción -> evidence/dia-10/00-seguro.txt
#   bash scripts/dia-10.sh medir    # ~2 min con carga: cuánta CPU gasta cada Pod de web            -> evidence/dia-10/01-medicion.txt
#   bash scripts/dia-10.sh prueba   # ~5 a 8 min: sube con carga y drena un worker bajo carga        -> evidence/dia-10/03-hpa-carga.txt y 04-drain.txt
#   bash scripts/dia-10.sh check    # criterios 1 a 3 (rápido: lee el clúster y la evidencia)        -> evidence/dia-10/02-metrics.txt y 05-estado.txt
# Antes de aplicar el HPA, completa y GUARDA evidence/dia-10/00-prediccion.txt (4 líneas, `yes` o `no` al final de cada una).
# CARGA_N=10 bash scripts/dia-10.sh medir  -> más bucles de carga (por defecto 6).
set -u
DIA=dia-10; NS=lab
EV="evidence/$DIA"; mkdir -p "$EV"
RES=(); FAILS=0
CARGA_N=${CARGA_N:-6}
LOADPOD=np-load
DRAIN_NODE=""; SAMPLER=""; TMPS=()
POLICIES=(allow-dns web-ingress api-ingress db-ingress web-to-db default-deny)
PRED=("web llega a 3 o más réplicas Ready en 180 s o menos con la carga"
      "web llega a 5 réplicas (el máximo) con la carga"
      "durante el drain, los Pods disponibles de web nunca bajan de 2"
      "el drain termina con éxito (exit 0) antes de 180 s")

ok()   { RES+=("✅ $1"); }
bad()  { RES+=("❌ $1"); FAILS=$((FAILS + 1)); }
pend() { RES+=("⏳ $1"); }

# run <archivo> <comando...>: guarda hora UTC, comando copiable, salida y código de salida
run() {
  local f="$EV/$1" rc tmp; shift; tmp=$(mktemp)
  { echo "# $(date -u -Iseconds)"; printf '$'; printf ' %q' "$@"; echo; } >"$tmp"
  "$@" >>"$tmp" 2>&1; rc=$?
  printf 'exit=%s\n\n' "$rc" >>"$tmp"
  tee -a "$f" <"$tmp"; rm -f "$tmp"; return "$rc"
}

# Valores que no deben aparecer en el repo: el Secret del clúster y tus variables de sesión. Nunca se imprimen.
valid() {
  { kubectl -n "$NS" get secret mysql-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null; echo
    printf '%s\n' "${MYSQL_PWD:-}" "${VIEJA:-}" "${NUEVA:-}" "${AZAR:-}"; } | grep -v '^[[:space:]]*$'
}

cleanup() {
  [ -n "$SAMPLER" ] && kill "$SAMPLER" 2>/dev/null
  [ -n "$DRAIN_NODE" ] && kubectl uncordon "$DRAIN_NODE" >/dev/null 2>&1
  kubectl -n default delete pod "$LOADPOD" --ignore-not-found --wait=false >/dev/null 2>&1
  local t; for t in "${TMPS[@]:-}"; do [ -n "$t" ] && rm -f "$t"; done
}

# ---- carga: un Pod en default (misma imagen que web) con N bucles de wget contra el Service de Traefik, con Host lab.local
carga_start() {
  local f=$1 img ip script
  img=$(kubectl -n "$NS" get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ip=$(kubectl -n traefik get svc traefik -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  if [ -z "$img" ] || [ -z "$ip" ]; then bad "carga: no pude leer la imagen de web o la IP del Service traefik"; return 1; fi
  kubectl -n default delete pod "$LOADPOD" --ignore-not-found --wait=true >/dev/null 2>&1
  script="i=0; while [ \$i -lt $CARGA_N ]; do ( while true; do wget -q -O /dev/null -T 2 --header 'Host: lab.local' http://$ip/ ; done ) & i=\$((i+1)); done; wait"
  run "$f" kubectl -n default run "$LOADPOD" --image="$img" --restart=Never --command -- sh -c "$script" >/dev/null || { bad "carga: no pude crear $LOADPOD (mira $EV/$f)"; return 1; }
  run "$f" kubectl -n default wait --for=condition=Ready "pod/$LOADPOD" --timeout=90s >/dev/null || { bad "carga: $LOADPOD no quedó Ready (mira $EV/$f)"; return 1; }
}

# promedio de CPU (m) de los Pods de web y cuántos son: "avg n"
top_avg() {
  kubectl -n "$NS" top pods -l app=web --no-headers 2>/dev/null | awk '{c=$2; gsub("m","",c); if (c ~ /^[0-9]+$/) {s+=c; n++}} END{if (n) printf "%d %d", s/n, n}'
}

pre() {
  local f=00-seguro.txt n hits b ready w code names missing cord
  if command -v gitleaks >/dev/null 2>&1; then
    if run $f gitleaks git --redact && run $f gitleaks dir --redact; then ok "S1a gitleaks (git y dir)"
    else bad "S1a gitleaks: hallazgos o error (mira $EV/$f)"; fi
  else bad "S1a gitleaks no está instalado"; fi
  n=$(valid | wc -l)
  hits=$(grep -rlF -f <(valid) README.md docs evidence manifests infra scripts 2>/dev/null)
  { echo "# $(date -u -Iseconds)"
    echo '$ grep -rlF -f <valores de mysql-secret, $MYSQL_PWD, $VIEJA, $NUEVA, $AZAR> README.md docs evidence manifests infra scripts'
    echo "patrones usados: $n"; echo "${hits:-sin coincidencias}"; echo; } | tee -a "$EV/$f"
  if [ "$n" -eq 0 ]; then bad "S1b grep de fugas: 0 patrones (¿el clúster no tiene el Secret?)"
  elif [ -n "$hits" ]; then bad "S1b valores reales en: $(echo $hits | tr '\n' ' ')"
  else ok "S1b grep de fugas ($n patrones)"; fi
  # S2: manifiestos válidos contra el servidor (solo cuando no quedan blancos)
  b=$(grep -rn '___' manifests infra 2>/dev/null | wc -l)
  if [ "$b" -eq 0 ]; then
    if run $f kubectl apply --dry-run=server -f manifests/ && run $f kubectl apply --dry-run=server -f infra/metrics-server/; then ok "S2 manifests/ e infra/metrics-server/ válidos (dry-run=server)"
    else bad "S2 dry-run falló (mira $EV/$f)"; fi
  else pend "S2 pendiente: $b línea(s) con ___ (el dry-run se hace cuando no queden; es normal antes de completar las plantillas)"; fi
  # S5: estado del clúster
  run $f kubectl get nodes >/dev/null
  ready=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)
  [ "$ready" -eq 3 ] && ok "S5 3 nodos Ready" || bad "S5 nodos Ready: $ready de 3"
  cord=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.unschedulable}{"\n"}{end}' 2>/dev/null | awk '$2=="true"{print $1}' | tr '\n' ' ')
  [ -z "$cord" ] && ok "S5 ningún nodo cordonado" || bad "S5 nodo(s) cordonado(s): $cord (kubectl uncordon <nodo>)"
  run $f kubectl -n "$NS" get deploy,pods >/dev/null
  w=$(kubectl -n "$NS" get deploy web -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
  case "$w" in [1-9]*/[1-9]*) [ "${w%/*}" = "${w#*/}" ] && ok "S5 web $w Ready" || bad "S5 web $w (se espera todas Ready)";; *) bad "S5 web $w (se espera todas Ready)";; esac
  code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: lab.local' http://127.0.0.1/ 2>/dev/null)
  run $f curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: lab.local' http://127.0.0.1/ >/dev/null
  [ "$code" = "200" ] && ok "Día 6 vivo: curl lab.local = 200" || bad "curl lab.local = ${code:-sin respuesta} (se espera 200)"
  # Día 9: las 6 NetworkPolicy deben existir (web-to-db se borró en el opcional O1)
  run $f kubectl -n "$NS" get networkpolicy >/dev/null
  names=$(kubectl -n "$NS" get networkpolicy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
  missing=""; for n in "${POLICIES[@]}"; do grep -qx "$n" <<<"$names" || missing="$missing $n"; done
  [ -z "$missing" ] && ok "Día 9: las 6 NetworkPolicy existen" || bad "Día 9: faltan NetworkPolicy:$missing (kubectl apply -f manifests/netpol.yaml)"
  run $f kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null
  RES+=("ℹ️  API de métricas: $(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | sed 's/^$/no instalada todavía/;s/^True$/disponible/;s/^False$/instalada pero no disponible/')")
  # Plantilla de predicción (solo si no existe; nunca se sobrescribe)
  if [ ! -f "$EV/00-prediccion.txt" ]; then
    { echo "# Día 10: tu predicción de lo que verá \`prueba\`, con el HPA y el PDB ya aplicados."
      echo "# Escribe yes o no al final de cada línea y GUARDA el archivo ANTES de aplicar el HPA."
      for i in 0 1 2 3; do echo "$((i + 1)). ${PRED[i]}:"; done; } >"$EV/00-prediccion.txt"
    RES+=("📝 creé $EV/00-prediccion.txt: complétalo y guárdalo antes de aplicar el HPA")
  fi
}

medir() {
  local f=01-medicion.txt r0 r1 m0 m1 n1 p0 p1 t xmin xmax
  trap cleanup EXIT; trap 'exit 130' INT TERM
  if ! run $f kubectl top nodes >/dev/null; then bad "medir: kubectl top nodes falla (¿metrics-server listo? espera ~1 min tras aplicarlo)"; return; fi
  r0=$(top_avg); [ -z "$r0" ] && { bad "medir: kubectl top pods no devuelve datos de web (mira $EV/$f)"; return; }
  run $f kubectl -n "$NS" top pods -l app=web >/dev/null
  carga_start $f || return
  echo "carga encendida con $CARGA_N bucles; midiendo 3 muestras (≈75 s)…"
  sleep 45
  for t in 45 60 75; do
    r1=$(top_avg)
    { echo "# $(date -u -Iseconds)  t=${t}s con carga: promedio por Pod de web = ${r1:-?}  (m, Pods)"; } | tee -a "$EV/$f"
    [ "$t" -lt 75 ] && sleep 15
  done
  run $f kubectl -n "$NS" top pods -l app=web >/dev/null
  kubectl -n default delete pod "$LOADPOD" --ignore-not-found --wait=false >/dev/null 2>&1
  m0=${r0% *}; n0=${r0#* }; m1=${r1% *}; n1=${r1#* }
  p0=$(( m0 * 100 / 500 )); p1=$(( ${m1:-0} * 100 / 500 ))
  { echo "RESULTADO medicion reposo_m=$m0 carga_m=${m1:-0} reposo_pct=$p0 carga_pct=$p1 pods=${n1:-0}"
    echo "requests.cpu de web = 500m  =>  el 50% del plan serían 250m por Pod"; echo; } | tee -a "$EV/$f"
  xmin=$(( m0 / 5 + 1 )); xmax=$(( (${m1:-0} - 1) / 5 ))
  if [ "$xmin" -le "$xmax" ]; then
    ok "medir: reposo ${m0}m y con carga ${m1}m por Pod de web (${n1:-?} Pods); 1% de los 500m = 5m"
    RES+=("➡️  averageUtilization válido entre ${xmin}% y ${xmax}% (entre ${m0}m y ${m1}m por Pod). Un objetivo por debajo del reposo impide que el HPA baje; uno por encima de la carga impide que suba. Elige uno hacia la mitad del rango")
  else
    bad "medir: la carga no alcanza para un objetivo útil (reposo ${m0}m, con carga ${m1:-0}m; el mínimo posible, 1%, son 5m). Prueba CARGA_N=12 bash scripts/dia-10.sh medir"
  fi
}

# Elige un worker (no control-plane) que no tenga a db y que tenga al menos un Pod de web
elegir_nodo() {
  local dbnode nodes webnodes n
  dbnode=$(kubectl -n "$NS" get pods -l app=db -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null)
  [ -z "$dbnode" ] && return 1
  nodes=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
  webnodes=$(kubectl -n "$NS" get pods -l app=web -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null)
  for n in $nodes; do
    if [ "$n" != "$dbnode" ] && grep -qx "$n" <<<"$webnodes"; then echo "$n"; return 0; fi
  done
  return 1
}

prueba() {
  local f3=03-hpa-carga.txt f4=04-drain.txt hmin pmin t t0 r3 maxr spec rdy cpu hs cand dout samples mind drc evict blk
  trap cleanup EXIT; trap 'exit 130' INT TERM
  hmin=$(kubectl -n "$NS" get hpa web -o jsonpath='{.spec.minReplicas}' 2>/dev/null)
  pmin=$(kubectl -n "$NS" get pdb web -o jsonpath='{.spec.minAvailable}' 2>/dev/null)
  [ -z "$hmin" ] && { bad "prueba: no existe el HPA web (kubectl apply -f manifests/hpa-pdb.yaml)"; return; }
  [ -z "$pmin" ] && { bad "prueba: no existe el PDB web (kubectl apply -f manifests/hpa-pdb.yaml)"; return; }
  # 1) punto de partida: web en el mínimo del HPA, sin carga
  echo "1/3 esperando a que web baje a $hmin réplicas (ventana de bajada del HPA, hasta 150 s)…"
  for ((t = 0; t <= 150; t += 10)); do
    spec=$(kubectl -n "$NS" get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null)
    rdy=$(kubectl -n "$NS" get deploy web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    { echo "# $(date -u -Iseconds) punto de partida t=${t}s spec=$spec ready=${rdy:-0}"; } >>"$EV/$f3"
    [ "$spec" = "$hmin" ] && [ "${rdy:-0}" = "$hmin" ] && break
    sleep 10
  done
  if [ "$spec" != "$hmin" ]; then
    echo "RESULTADO subida segundos= max_ready=0 inicio=$spec" >>"$EV/$f3"
    bad "prueba: web sigue en $spec réplicas (mín $hmin) tras 150 s sin carga: el HPA no baja. Mira kubectl -n $NS describe hpa web (¿TARGETS <unknown>? ¿objetivo por debajo del reposo?)"; return
  fi
  # 2) carga y subida
  echo "2/3 carga encendida ($CARGA_N bucles); esperando ≥3 réplicas Ready (hasta 180 s)…"
  carga_start $f3 || return
  t0=$(date +%s); r3=""; maxr=0
  while :; do
    t=$(( $(date +%s) - t0 ))
    spec=$(kubectl -n "$NS" get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null)
    rdy=$(kubectl -n "$NS" get deploy web -o jsonpath='{.status.readyReplicas}' 2>/dev/null); rdy=${rdy:-0}
    hs=$(kubectl -n "$NS" get hpa web -o jsonpath='{.status.currentReplicas}/{.status.desiredReplicas}' 2>/dev/null)
    cpu=$(kubectl -n "$NS" get hpa web -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
    printf '# %s t=%3ss ready=%s spec=%s hpa=%s cpu=%s%%\n' "$(date -u -Iseconds)" "$t" "$rdy" "$spec" "${hs:-?}" "${cpu:-?}" | tee -a "$EV/$f3"
    [ "$rdy" -gt "$maxr" ] && maxr=$rdy
    [ -z "$r3" ] && [ "$rdy" -ge 3 ] && r3=$t
    [ "$t" -ge 180 ] && break
    if [ -n "$r3" ] && { [ "$maxr" -ge 5 ] || [ "$t" -ge $((r3 + 40)) ]; }; then break; fi
    sleep 10
  done
  echo "RESULTADO subida segundos=${r3:-} max_ready=$maxr inicio=$hmin" | tee -a "$EV/$f3"; echo >>"$EV/$f3"
  if [ -n "$r3" ] && [ "$r3" -le 180 ]; then ok "prueba: web subió de $hmin a ≥3 réplicas Ready en ${r3} s (máximo visto: $maxr)"
  else bad "prueba: web no llegó a 3 réplicas Ready en 180 s (máximo: $maxr). Mira $EV/$f3 y kubectl -n $NS describe hpa web"; pend "prueba: drain no probado (necesita ≥3 réplicas)"; return; fi
  # 3) drain de un worker sin db, con la carga encendida
  echo "3/3 drain de un worker bajo carga (hasta 180 s)…"
  cand=$(elegir_nodo) || { pend "prueba: no hay un worker sin db con Pods de web para drenar (mira $EV/$f4)"; echo "# sin nodo candidato" >>"$EV/$f4"; return; }
  dout=$(mktemp); samples=$(mktemp); TMPS+=("$dout" "$samples")
  { echo "# $(date -u -Iseconds) nodo elegido: $cand (db corre en otro nodo)"; kubectl -n "$NS" get pods -l app=web -o wide 2>/dev/null; echo; } | tee -a "$EV/$f4"
  ( while :; do a=$(kubectl -n "$NS" get deploy web -o jsonpath='{.status.availableReplicas}' 2>/dev/null); echo "$(date +%s) ${a:-0}"; sleep 1; done ) >"$samples" 2>/dev/null &
  SAMPLER=$!
  DRAIN_NODE=$cand
  { echo "# $(date -u -Iseconds)"; echo "\$ kubectl drain $cand --ignore-daemonsets --delete-emptydir-data --timeout=180s"; } | tee -a "$EV/$f4"
  kubectl drain "$cand" --ignore-daemonsets --delete-emptydir-data --timeout=180s >"$dout" 2>&1; drc=$?
  kill "$SAMPLER" 2>/dev/null; wait "$SAMPLER" 2>/dev/null; SAMPLER=""
  { cat "$dout"; echo "exit=$drc"; echo; } | tee -a "$EV/$f4"
  run $f4 kubectl uncordon "$cand" >/dev/null && DRAIN_NODE=""
  mind=$(awk '{ if (min == "" || $2 < min) min = $2 } END { print min }' "$samples")
  evict=$(grep -c 'lab/web-' "$dout"); blk=$(grep -c 'would violate the pod' "$dout")
  { echo "disponibles de web durante el drain (cada 1 s; $(wc -l <"$samples") muestras): mínimo = ${mind:-?}"; awk '{ c[$2]++ } END { for (k in c) printf "  %d muestra(s) con %s disponibles\n", c[k], k }' "$samples" | sort -k4,4n
    echo "RESULTADO drain nodo=$cand rc=$drc min_disponibles=${mind:-} evictiones_web=$evict bloqueos_pdb=$blk pdb_min=$pmin"; echo; } | tee -a "$EV/$f4"
  if [ -z "$mind" ]; then bad "prueba: el drain no dejó muestras de disponibilidad"
  elif [ "$mind" -ge "$pmin" ] && [ $((evict + blk)) -ge 1 ]; then ok "prueba: durante el drain de $cand, web nunca bajó de $mind disponibles (PDB mínimo $pmin; evicciones de web: $evict, bloqueos del PDB: $blk; drain exit $drc)"
  elif [ "$mind" -ge "$pmin" ]; then pend "prueba: el drain de $cand no tocó a web (ni evicciones ni bloqueos): no prueba el PDB"
  else bad "prueba: durante el drain web bajó a $mind disponibles (PDB mínimo $pmin): el PDB no protegió"; fi
}

# lee la última línea RESULTADO <clave> de un archivo de evidencia y devuelve el valor de un campo
res_line() { grep -h "^RESULTADO $1 " "$EV/$2" 2>/dev/null | tail -1; }
res_val()  { sed -n "s/.*[[:space:]]$2=\([^[:space:]]*\).*/\1/p" <<<"$1"; }

check() {
  local f lines nodes top apis dep ins hmin hmax hmet hcur htgt hscale pmin pexp pcr first pe v i npred hits=0
  local rs3 rs4 s3 mx mind drc evict blk real_ nombres cord np
  if grep -n '___' manifests/hpa-pdb.yaml infra/metrics-server/*.yaml; then
    echo "❌ quedan blancos ___ (líneas de arriba). Complétalos y aplica antes de verificar."; exit 1; fi

  # Criterio 1: metrics-server funcionando
  f=02-metrics.txt
  run $f kubectl -n kube-system get deploy metrics-server >/dev/null
  run $f kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null
  run $f kubectl top nodes >/dev/null
  dep=$(kubectl -n kube-system get deploy metrics-server -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
  apis=$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
  top=$(kubectl top nodes --no-headers 2>/dev/null)
  lines=$(grep -c . <<<"$top"); [ -z "$top" ] && lines=0
  ins=$(kubectl -n kube-system get deploy metrics-server -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null | grep -c 'kubelet-insecure-tls')
  echo "metrics-server=$dep apiservice=${apis:-?} nodos con datos=$lines flag insecure-tls=$ins" | tee -a "$EV/$f"
  if [ "$dep" = "1/1" ] && [ "$apis" = "True" ] && [ "$lines" -eq 3 ] && ! grep -q 'unknown' <<<"$top" && [ "$ins" -ge 1 ]; then
    ok "1 metrics-server 1/1, APIService disponible y kubectl top nodes con los 3 nodos"
  else
    bad "1 metrics-server=$dep, APIService=${apis:-?}, nodos con datos=$lines, flag --kubelet-insecure-tls en el Pod: $([ "$ins" -ge 1 ] && echo sí || echo NO) (mira $EV/$f; tras aplicar, los datos tardan ~1 min)"; fi

  # Criterio 2: HPA bien definido y subida bajo carga
  f=03-hpa-carga.txt
  hmin=$(kubectl -n "$NS" get hpa web -o jsonpath='{.spec.minReplicas}' 2>/dev/null)
  hmax=$(kubectl -n "$NS" get hpa web -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)
  hmet=$(kubectl -n "$NS" get hpa web -o jsonpath='{.spec.metrics[0].resource.name}/{.spec.metrics[0].resource.target.type}' 2>/dev/null)
  htgt=$(kubectl -n "$NS" get hpa web -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}' 2>/dev/null)
  hscale=$(kubectl -n "$NS" get hpa web -o jsonpath='{.spec.scaleTargetRef.kind}/{.spec.scaleTargetRef.name}' 2>/dev/null)
  hcur=$(kubectl -n "$NS" get hpa web -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
  run $f kubectl -n "$NS" get hpa web >/dev/null
  echo "hpa: min=$hmin max=$hmax métrica=$hmet objetivo=${htgt}% apunta a=$hscale uso actual=${hcur:-?}%" | tee -a "$EV/$f"
  rs3=$(res_line subida $f); s3=$(res_val "$rs3" segundos); mx=$(res_val "$rs3" max_ready)
  if ! kubectl -n "$NS" get hpa web >/dev/null 2>&1; then
    bad "2 no existe el HPA web en $NS: aplica manifests/hpa-pdb.yaml"
  elif [ "$hmin" != "2" ] || [ "$hmax" != "5" ] || [ "$hmet" != "cpu/Utilization" ] || [ "$hscale" != "Deployment/web" ] || [ -z "$htgt" ]; then
    bad "2 el HPA no es el pedido (min 2, max 5, cpu/Utilization sobre Deployment/web): min=$hmin max=$hmax métrica=$hmet apunta=$hscale"
  elif [ -z "$hcur" ]; then bad "2 el HPA no recibe métricas (uso actual vacío): mira kubectl -n $NS describe hpa web"
  elif [ -z "$rs3" ]; then pend "2 el HPA está bien definido, pero falta la prueba de carga: corre bash scripts/dia-10.sh prueba"
  elif [ -n "$s3" ] && [ "$s3" -le 180 ]; then ok "2 HPA min $hmin, max $hmax, objetivo ${htgt}%: web llegó a ≥3 réplicas Ready en ${s3} s (máximo $mx)"
  else bad "2 el HPA está definido, pero web no llegó a 3 réplicas Ready en 180 s (máximo $mx): mira $EV/$f"; fi

  # Criterio 3: PDB bien definido y drain protegido
  f=04-drain.txt
  pmin=$(kubectl -n "$NS" get pdb web -o jsonpath='{.spec.minAvailable}' 2>/dev/null)
  pexp=$(kubectl -n "$NS" get pdb web -o jsonpath='{.status.expectedPods}' 2>/dev/null)
  run $f kubectl -n "$NS" get pdb web >/dev/null
  echo "pdb: minAvailable=$pmin Pods que selecciona=${pexp:-?}" | tee -a "$EV/$f"
  rs4=$(res_line drain $f); mind=$(res_val "$rs4" min_disponibles); drc=$(res_val "$rs4" rc); evict=$(res_val "$rs4" evictiones_web); blk=$(res_val "$rs4" bloqueos_pdb)
  if [ "$pmin" != "2" ]; then bad "3 el PDB debe tener minAvailable 2 (tiene '${pmin:-nada}')"
  elif [ -z "$pexp" ] || [ "$pexp" -lt 2 ]; then bad "3 el PDB selecciona ${pexp:-0} Pods: la etiqueta no coincide con web, así que no protege nada"
  elif [ -z "$rs4" ]; then pend "3 el PDB está bien definido, pero falta el drain bajo carga: corre bash scripts/dia-10.sh prueba"
  elif [ -n "$mind" ] && [ "$mind" -ge "$pmin" ] && [ $(( ${evict:-0} + ${blk:-0} )) -ge 1 ]; then
    ok "3 PDB minAvailable $pmin: en el drain web nunca bajó de $mind disponibles (evicciones: $evict, bloqueos del PDB: $blk, exit $drc)"
  else bad "3 en el drain web bajó a ${mind:-?} disponibles o el drain no tocó a web (evicciones: ${evict:-?}, bloqueos: ${blk:-?}): mira $EV/$f"; fi

  # Predicción frente a lo que registró `prueba`
  f=05-estado.txt
  local -a pred=() real=()
  if [ -f "$EV/00-prediccion.txt" ]; then
    mapfile -t pred < <(tr -d '\r' <"$EV/00-prediccion.txt" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' \
      | tr 'A-Z' 'a-z' | sed -e 's/[[:space:]]*$//' -e 's/.*[[:space:]:]//' -e 's/^si$/yes/' -e 's/^sí$/yes/')
    npred=0; for v in "${pred[@]}"; do [[ $v == yes || $v == no ]] && npred=$((npred + 1)); done
    [ "$npred" -eq 4 ] || echo "⚠️  $EV/00-prediccion.txt tiene $npred de 4 líneas con yes/no: lo que falte no cuenta." | tee -a "$EV/$f"
    pe=$(date -u -r "$EV/00-prediccion.txt" +%s 2>/dev/null)
    first=$(kubectl -n "$NS" get hpa web -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
    if [ -n "$first" ] && [ -n "${pe:-}" ] && [ "$pe" -gt "$(date -u -d "$first" +%s 2>/dev/null || echo 99999999999)" ]; then
      echo "⚠️  la predicción es posterior a la creación del HPA ($first): no cuenta como predicción." | tee -a "$EV/$f"; fi
  else echo "⚠️  no hay $EV/00-prediccion.txt: escríbela ANTES de aplicar el HPA (corre pre para crear la plantilla)." | tee -a "$EV/$f"; fi
  if [ -n "$rs3" ] && [ -n "$rs4" ]; then
    real=( $([ -n "$s3" ] && [ "$s3" -le 180 ] && echo yes || echo no)
           $([ "${mx:-0}" -ge 5 ] && echo yes || echo no)
           $([ -n "$mind" ] && [ "$mind" -ge 2 ] && echo yes || echo no)
           $([ "$drc" = "0" ] && echo yes || echo no) )
    printf '%-2s %-66s %-10s %-5s\n' '#' 'qué predijiste' 'tu apuesta' real | tee -a "$EV/$f"
    for i in 0 1 2 3; do
      [ "${pred[i]:-?}" = "${real[i]}" ] && hits=$((hits + 1))
      printf '%-2s %-66s %-10s %-5s\n' "$((i + 1))" "${PRED[i]}" "${pred[i]:-?}" "${real[i]}" | tee -a "$EV/$f"
    done
    echo "aciertos de tu predicción: $hits/4" | tee -a "$EV/$f"
  else echo '(la tabla de predicción sale cuando prueba ya registró la subida y el drain)' | tee -a "$EV/$f"; fi

  # Estado final (sin esto, un drain mal cerrado dejaría el clúster roto)
  run $f kubectl get nodes >/dev/null
  cord=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.unschedulable}{"\n"}{end}' 2>/dev/null | awk '$2=="true"{print $1}' | tr '\n' ' ')
  [ -z "$cord" ] && ok "E nodos todos programables (ninguno cordonado)" || bad "E nodo(s) cordonado(s): $cord (kubectl uncordon <nodo>)"
  np=$(kubectl -n default get pod "$LOADPOD" --no-headers 2>/dev/null | wc -l)
  [ "$np" -eq 0 ] && ok "E el Pod de carga ($LOADPOD) ya no existe" || bad "E sigue vivo el Pod de carga: kubectl -n default delete pod $LOADPOD"
  nombres=$(kubectl -n "$NS" get networkpolicy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -c .)
  [ "$nombres" -eq 6 ] && ok "E las 6 NetworkPolicy siguen en pie" || bad "E hay $nombres NetworkPolicy (se esperan 6)"
  run $f kubectl -n "$NS" get deploy,pods >/dev/null
  RES+=("ℹ️  manifests/web-deployment.yaml sigue diciendo replicas: $(grep -m1 -E '^[[:space:]]+replicas:' manifests/web-deployment.yaml | awk '{print $2}'): cada apply de ese archivo pelea con el HPA (pregunta 2 de la nota)")
}

case "${1:-}" in
  pre|medir|prueba|check) ;;
  *) echo "uso: bash scripts/dia-10.sh pre | medir | prueba | check"; exit 2 ;;
esac
ctx=$(kubectl config current-context 2>/dev/null)
[ "$ctx" = "kind-lab" ] || { echo "❌ contexto '${ctx:-ninguno}': se espera kind-lab. No hago nada."; exit 2; }
"$1"
echo; echo "== Resumen $DIA ($1) =="; printf '%s\n' "${RES[@]}"
[ "$FAILS" -eq 0 ] || { echo "→ $FAILS punto(s) en ❌: míralos antes de seguir."; exit 1; }
