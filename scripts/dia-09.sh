#!/usr/bin/env bash
# Día 9 (NetworkPolicy). Se ejecuta desde la raíz del repo:
#   bash scripts/dia-09.sh pre     # Parte 0 (nivel 1), estado del clúster y plantilla de predicción -> evidence/dia-09/00-seguro.txt
#   bash scripts/dia-09.sh antes   # las 6 pruebas SIN políticas (deben funcionar las 6)            -> evidence/dia-09/01-antes.txt
#   bash scripts/dia-09.sh check   # criterios 1 a 3                                                -> evidence/dia-09/02-netpol.txt, 03-matriz.txt, 04-vivo.txt
# Antes de aplicar las políticas, completa y GUARDA evidence/dia-09/00-prediccion.txt (6 líneas, `yes` o `no` al final de cada una).
set -u
DIA=dia-09; NS=lab
EV="evidence/$DIA"; mkdir -p "$EV"
RES=(); FAILS=0
CASO=("Traefik -> web (curl / con Host lab.local)" "Traefik -> api (curl /api)" "web -> db:3306"
      "Pod de default -> db:3306" "web -> api:80" "Pod de default -> web:80")
EXPECT=(yes yes yes no no no)
REAL=(); SECS=()
POLICIES=(allow-dns web-ingress api-ingress db-ingress web-to-db default-deny)

ok()  { RES+=("✅ $1"); }
bad() { RES+=("❌ $1"); FAILS=$((FAILS + 1)); }

# run <archivo> <comando...>: guarda hora UTC, comando copiable, salida y código de salida
run() {
  local f="$EV/$1" rc tmp; shift; tmp=$(mktemp)
  { echo "# $(date -u -Iseconds)"; printf '$'; printf ' %q' "$@"; echo; } >"$tmp"
  "$@" >>"$tmp" 2>&1; rc=$?
  printf 'exit=%s\n\n' "$rc" >>"$tmp"
  tee -a "$f" <"$tmp"; rm -f "$tmp"; return "$rc"
}

# probe <archivo> <caso> <comando...>: ejecuta una prueba de conectividad y guarda hora UTC, comando, error, código y segundos.
# Deja el resultado en PROBE_RC y PROBE_S (no se llama dentro de $(...)).
probe() {
  local f="$EV/$1" caso=$2 t0 err; shift 2
  t0=$(date +%s)
  err=$("$@" 2>&1 >/dev/null); PROBE_RC=$?
  PROBE_S=$(( $(date +%s) - t0 ))
  { echo "# $(date -u -Iseconds)"; echo "# caso: $caso"; printf '$'; printf ' %q' "$@"; echo
    [ -n "$err" ] && printf '%s\n' "$err" | head -3
    echo "exit=$PROBE_RC  segundos=$PROBE_S"; echo; } >>"$f"
}

# Valores que no deben aparecer en el repo: el Secret del clúster y tus variables de sesión.
# Nunca se imprimen.
valid() {
  { kubectl -n "$NS" get secret mysql-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null; echo
    printf '%s\n' "${MYSQL_PWD:-}" "${VIEJA:-}" "${NUEVA:-}" "${AZAR:-}"; } | grep -v '^[[:space:]]*$'
}

pre() {
  local f=00-seguro.txt n hits b ready w code cni
  # S1a: gitleaks (historial y árbol de trabajo)
  if command -v gitleaks >/dev/null 2>&1; then
    if run $f gitleaks git --redact && run $f gitleaks dir --redact; then ok "S1a gitleaks (git y dir)"
    else bad "S1a gitleaks: hallazgos o error (mira $EV/$f)"; fi
  else bad "S1a gitleaks no está instalado"; fi
  # S1b: grep -rlF con los valores reales (solo se imprimen nombres de archivo)
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
    if run $f kubectl apply --dry-run=server -f manifests/; then ok "S2 manifests/ válidos (dry-run=server)"
    else bad "S2 dry-run falló (mira $EV/$f)"; fi
  else RES+=("⏳ S2 pendiente: $b línea(s) con ___ (el dry-run se hace cuando no queden; es normal antes de completar la plantilla)"); fi
  # S5: estado del clúster y Día 6 vivo
  run $f kubectl get nodes >/dev/null
  ready=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)
  [ "$ready" -eq 3 ] && ok "S5 3 nodos Ready" || bad "S5 nodos Ready: $ready de 3"
  run $f kubectl -n "$NS" get deploy,pods >/dev/null
  w=$(kubectl -n "$NS" get deploy web -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
  [ "$w" = "3/3" ] && ok "S5 web 3/3" || bad "S5 web $w (se espera 3/3)"
  code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: lab.local' http://127.0.0.1/ 2>/dev/null)
  run $f curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: lab.local' http://127.0.0.1/ >/dev/null
  [ "$code" = "200" ] && ok "Día 6 vivo: curl lab.local = 200" || bad "curl lab.local = ${code:-sin respuesta} (se espera 200)"
  # Informativo: el CNI del clúster (no cuenta como ✅ ni ❌)
  cni=$(kubectl -n kube-system get ds kindnet -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  run $f kubectl -n kube-system get ds >/dev/null
  RES+=("ℹ️  CNI: ${cni:-no hay DaemonSet kindnet (¿otro CNI?)}")
  # Plantilla de predicción (solo si no existe; nunca se sobrescribe)
  if [ ! -f "$EV/00-prediccion.txt" ]; then
    { echo "# Día 9: tu predicción del estado FINAL, con las 6 políticas ya aplicadas."
      echo "# Escribe yes (funciona) o no (falla) al final de cada línea y GUARDA el archivo ANTES de aplicar."
      for i in 0 1 2 3 4 5; do echo "$((i + 1)). ${CASO[i]}:"; done; } >"$EV/00-prediccion.txt"
    RES+=("📝 creé $EV/00-prediccion.txt: complétalo y guárdalo antes de aplicar")
  fi
}

# Ejecuta las 6 pruebas y deja REAL[] y SECS[]. Crea un Pod de prueba en default (misma imagen que web, ya está en los nodos).
run_matrix() {
  local f=$1 img i
  img=$(kubectl -n "$NS" get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  kubectl -n default delete pod np-probe --ignore-not-found --wait=true >/dev/null 2>&1
  trap 'kubectl -n default delete pod np-probe --ignore-not-found --wait=false >/dev/null 2>&1' EXIT
  run $f kubectl -n default run np-probe --image="$img" --restart=Never --command -- sleep 600 >/dev/null
  run $f kubectl -n default wait --for=condition=Ready pod/np-probe --timeout=90s >/dev/null
  for i in 0 1 2 3 4 5; do
    case $i in
      0) probe $f "${CASO[i]}" curl -fs --max-time 5 -H 'Host: lab.local' http://127.0.0.1/ ;;
      1) probe $f "${CASO[i]}" curl -fs --max-time 5 -H 'Host: lab.local' http://127.0.0.1/api ;;
      2) probe $f "${CASO[i]}" kubectl -n "$NS" exec deploy/web -- nc -z -w 3 db.lab.svc.cluster.local 3306 ;;
      3) probe $f "${CASO[i]}" kubectl -n default exec np-probe -- nc -z -w 3 db.lab.svc.cluster.local 3306 ;;
      4) probe $f "${CASO[i]}" kubectl -n "$NS" exec deploy/web -- wget -q -T 3 -O- http://api.lab.svc.cluster.local/ ;;
      5) probe $f "${CASO[i]}" kubectl -n default exec np-probe -- wget -q -T 3 -O- http://web.lab.svc.cluster.local/ ;;
    esac
    REAL[i]=$([ "$PROBE_RC" -eq 0 ] && echo yes || echo no); SECS[i]=$PROBE_S
  done
}

# Nota sobre una prueba denegada: un bloqueo por política se ve como timeout (≈3 s); un fallo inmediato es otra cosa.
nota_denegada() {  # $1 = real, $2 = segundos
  [ "$1" = yes ] && { echo "pasó (debía bloquearse)"; return; }
  [ "$2" -ge 2 ] && echo "timeout (${2}s)" || echo "falló rápido (${2}s): ¿rechazo y no timeout?"
}

antes() {
  local f=01-antes.txt i good=0 np
  np=$(kubectl -n "$NS" get networkpolicy --no-headers 2>/dev/null | wc -l)
  [ "$np" -eq 0 ] || RES+=("⚠️  ya hay $np NetworkPolicy en $NS: esto no es un «antes» limpio")
  run_matrix $f
  printf '%-2s %-44s %-6s %s\n' '#' caso real seg | tee -a "$EV/$f"
  for i in 0 1 2 3 4 5; do
    [ "${REAL[i]}" = yes ] && good=$((good + 1))
    printf '%-2s %-44s %-6s %s\n' "$((i + 1))" "${CASO[i]}" "${REAL[i]}" "${SECS[i]}s" | tee -a "$EV/$f"
  done
  [ "$good" -eq 6 ] && ok "antes: 6/6 funcionan sin políticas (las pruebas están bien armadas)" \
    || bad "antes: $good/6 funcionan. Si falla alguna sin políticas, es un problema de la prueba, no de la política (mira $EV/$f)"
}

check() {
  local f lab i good=0 hits=0 names missing dd ready_w ready_a ready_d pe first npred v
  if grep -n '___' manifests/netpol.yaml; then
    echo "❌ quedan blancos ___ (líneas de arriba). Complétalos y aplica antes de verificar."; exit 1; fi

  # Criterio 1: las 6 políticas existen y default-deny cubre todo el namespace en ambos sentidos
  f=02-netpol.txt
  run $f kubectl -n "$NS" get networkpolicy >/dev/null
  names=$(kubectl -n "$NS" get networkpolicy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
  missing=""
  for v in "${POLICIES[@]}"; do grep -qx "$v" <<<"$names" || missing="$missing $v"; done
  run $f kubectl -n "$NS" get networkpolicy default-deny -o 'jsonpath=tipos={.spec.policyTypes[*]} selector={.spec.podSelector} ingress={.spec.ingress} egress={.spec.egress}{"\n"}' >/dev/null
  dd=$(kubectl -n "$NS" get networkpolicy default-deny -o 'jsonpath=tipos={.spec.policyTypes[*]} selector={.spec.podSelector} ingress={.spec.ingress} egress={.spec.egress}' 2>/dev/null)
  echo "políticas en $NS: $(echo $names | tr '\n' ' ')"; echo "default-deny: $dd"
  if [ -z "$missing" ] && [ "$dd" = "tipos=Ingress Egress selector={} ingress= egress=" ]; then
    ok "1 las 6 NetworkPolicy existen y default-deny cubre Ingress y Egress de todos los Pods"
  else bad "1 faltan:${missing:- ninguna}; default-deny='${dd:-no existe}' (mira $EV/$f)"; fi

  # Criterio 2: matriz de 6 pruebas (3 permitidas y 3 denegadas) frente a tu predicción
  f=03-matriz.txt
  run_matrix $f
  local -a pred=()
  if [ -f "$EV/00-prediccion.txt" ]; then
    mapfile -t pred < <(tr -d '\r' <"$EV/00-prediccion.txt" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' \
      | tr 'A-Z' 'a-z' | sed -e 's/[[:space:]]*$//' -e 's/.*[[:space:]:]//' -e 's/^si$/yes/' -e 's/^sí$/yes/')
    pe=$(date -u -r "$EV/00-prediccion.txt" +%s 2>/dev/null)
    echo "predicción escrita: $(date -u -r "$EV/00-prediccion.txt" -Iseconds)" | tee -a "$EV/$f"
    npred=0; for v in "${pred[@]}"; do [[ $v == yes || $v == no ]] && npred=$((npred + 1)); done
    [ "$npred" -eq 6 ] || echo "⚠️  $EV/00-prediccion.txt tiene $npred de 6 líneas con yes/no: lo que falte no cuenta." | tee -a "$EV/$f"
    first=$(kubectl -n "$NS" get networkpolicy -o jsonpath='{.items[*].metadata.creationTimestamp}' 2>/dev/null | tr ' ' '\n' | sort | head -1)
    if [ -n "$first" ] && [ -n "${pe:-}" ] && [ "$pe" -gt "$(date -u -d "$first" +%s 2>/dev/null || echo 99999999999)" ]; then
      echo "⚠️  la predicción es posterior a la primera política ($first): no cuenta como predicción." | tee -a "$EV/$f"; fi
  else
    echo "⚠️  no hay $EV/00-prediccion.txt: escríbela ANTES de aplicar (corre pre para crear la plantilla)." | tee -a "$EV/$f"
  fi
  printf '%-2s %-44s %-10s %-6s %-5s %s\n' '#' caso 'tu apuesta' real seg objetivo | tee -a "$EV/$f"
  for i in 0 1 2 3 4 5; do
    [ "${REAL[i]}" = "${EXPECT[i]}" ] && good=$((good + 1))
    [ "${pred[i]:-?}" = "${REAL[i]}" ] && hits=$((hits + 1))
    if [ "${EXPECT[i]}" = yes ]; then v=$([ "${REAL[i]}" = yes ] && echo "✅ funciona" || echo "❌ debía funcionar")
    else v=$([ "${REAL[i]}" = no ] && echo "✅ $(nota_denegada "${REAL[i]}" "${SECS[i]}")" || echo "❌ $(nota_denegada "${REAL[i]}" "${SECS[i]}")"); fi
    printf '%-2s %-44s %-10s %-6s %-5s %s\n' "$((i + 1))" "${CASO[i]}" "${pred[i]:-?}" "${REAL[i]}" "${SECS[i]}s" "$v" | tee -a "$EV/$f"
  done
  echo "aciertos de tu predicción: $hits/6" | tee -a "$EV/$f"
  [ "$good" -eq 6 ] && ok "2 matriz 6/6: 3 permitidas funcionan y 3 denegadas fallan" || bad "2 matriz $good/6 (mira $EV/$f)"

  # Criterio 3: el stack sigue vivo (las probes no se rompieron con las políticas)
  f=04-vivo.txt
  run $f kubectl -n "$NS" get deploy,pods >/dev/null
  ready_w=$(kubectl -n "$NS" get deploy web -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
  ready_a=$(kubectl -n "$NS" get deploy api -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
  ready_d=$(kubectl -n "$NS" get deploy db -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
  echo "Ready: web=$ready_w api=$ready_a db=$ready_d" | tee -a "$EV/$f"
  if [ "$ready_w" = "3/3" ] && [ "$ready_a" = "2/2" ] && [ "$ready_d" = "1/1" ]; then ok "3 web 3/3, api 2/2 y db 1/1 Ready con las políticas aplicadas"
  else bad "3 Ready: web=${ready_w:-?} api=${ready_a:-?} db=${ready_d:-?} (se espera 3/3, 2/2 y 1/1)"; fi
}

case "${1:-}" in
  pre|antes|check) ;;
  *) echo "uso: bash scripts/dia-09.sh pre | antes | check"; exit 2 ;;
esac
ctx=$(kubectl config current-context 2>/dev/null)
[ "$ctx" = "kind-lab" ] || { echo "❌ contexto '${ctx:-ninguno}': se espera kind-lab. No hago nada."; exit 2; }
"$1"
echo; echo "== Resumen $DIA ($1) =="; printf '%s\n' "${RES[@]}"
[ "$FAILS" -eq 0 ] || { echo "→ $FAILS punto(s) en ❌: míralos antes de seguir."; exit 1; }
