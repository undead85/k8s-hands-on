#!/usr/bin/env bash
# Día 7 (RBAC). Se ejecuta desde la raíz del repo:
#   bash scripts/dia-07.sh pre     # Parte 0 (nivel 1) y estado del clúster -> evidence/dia-07/00-seguro.txt
#   bash scripts/dia-07.sh check   # criterios 1 a 3 -> evidence/dia-07/01-rbac.txt, 02-matriz.txt, 03-token.txt
# Antes de `check`, escribe tu predicción en evidence/dia-07/00-prediccion.txt (4 líneas: `yes` o `no`, o `caso: yes`).
set -u
DIA=dia-07; NS=lab; SA=deployer; WHO="system:serviceaccount:$NS:$SA"
EV="evidence/$DIA"; mkdir -p "$EV"
export MSYS_NO_PATHCONV=1   # Git Bash: no convierte rutas en los argumentos
RES=(); FAILS=0

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

# Valores que no deben aparecer en el repo: el Secret del clúster y tus variables de sesión.
# Nunca se imprimen.
valid() {
  { kubectl -n "$NS" get secret mysql-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null; echo
    printf '%s\n' "${MYSQL_PWD:-}" "${VIEJA:-}" "${NUEVA:-}" "${AZAR:-}"; } | grep -v '^[[:space:]]*$'
}

pre() {
  local f=00-seguro.txt n hits b ready w code
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
  # S2: manifiestos válidos contra el servidor
  if run $f kubectl apply --dry-run=server -f manifests/; then ok "S2 manifests/ válidos (dry-run=server)"
  else bad "S2 dry-run falló (mira $EV/$f)"; fi
  b=$(grep -rn '___' manifests infra 2>/dev/null | wc -l)
  if [ "$b" -eq 0 ]; then ok "sin blancos ___ pendientes"
  else RES+=("⏳ $b línea(s) con ___ pendientes (normal antes de completar la plantilla)"); fi
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
}

check() {
  local f i real args auto vols
  if [ ! -f manifests/rbac.yaml ]; then echo "❌ falta manifests/rbac.yaml"; exit 1; fi
  if grep -n '___' manifests/rbac.yaml manifests/web-deployment.yaml; then
    echo "❌ quedan blancos ___ (líneas de arriba). Complétalos y aplica antes de verificar."; exit 1; fi

  # Criterio 1: existen la SA, el Role y el RoleBinding
  f=01-rbac.txt
  if run $f kubectl -n "$NS" get "sa/$SA" "role/$SA" "rolebinding/$SA"; then ok "1 SA, Role y RoleBinding existen"
  else bad "1 falta algún objeto (mira $EV/$f)"; fi
  run $f kubectl -n "$NS" describe role "$SA" >/dev/null
  run $f kubectl -n "$NS" describe rolebinding "$SA" >/dev/null

  # Criterio 2: matriz can-i (predicción en 00-prediccion.txt, una línea yes/no por caso)
  f=02-matriz.txt
  local -a V=(patch get patch create) R=(deployments secrets deployments clusterrolebindings)
  local -a N=(lab lab default "") EXP=(yes no no no) CASO=(
    "patch deployments en lab" "get secrets en lab" "patch deployments en default" "create clusterrolebindings (clúster)")
  local -a pred=()
  if [ -f "$EV/00-prediccion.txt" ]; then
    # Vale `yes`, o `caso: yes`: se toma la última palabra de cada línea.
    mapfile -t pred < <(tr -d '\r' <"$EV/00-prediccion.txt" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' \
      | tr 'A-Z' 'a-z' | sed -e 's/[[:space:]]*$//' -e 's/.*[[:space:]:]//' -e 's/^si$/yes/' -e 's/^sí$/yes/')
    echo "predicción escrita: $(date -u -r "$EV/00-prediccion.txt" -Iseconds)" | tee -a "$EV/$f"
  else
    echo "⚠️  no hay $EV/00-prediccion.txt: escríbela ANTES de ejecutar (4 líneas, yes o no)." | tee -a "$EV/$f"
  fi
  { printf '%-2s %-40s %-10s %-6s %s\n' '#' caso 'tu apuesta' real objetivo; } | tee -a "$EV/$f"
  local good=0 hits=0
  for i in 0 1 2 3; do
    args=(auth can-i "${V[i]}" "${R[i]}"); [ -n "${N[i]}" ] && args+=(-n "${N[i]}"); args+=(--as="$WHO")
    real=$(kubectl "${args[@]}" 2>/dev/null)
    run $f kubectl "${args[@]}" >/dev/null
    [ "$real" = "${EXP[i]}" ] && good=$((good + 1))
    [ "${pred[i]:-?}" = "$real" ] && hits=$((hits + 1))
    printf '%-2s %-40s %-10s %-6s %s\n' "$((i + 1))" "${CASO[i]}" "${pred[i]:-?}" "$real" \
      "$([ "$real" = "${EXP[i]}" ] && echo "✅ ($real)" || echo "❌ (se espera ${EXP[i]})")" | tee -a "$EV/$f"
  done
  echo "aciertos de tu predicción: $hits/4" | tee -a "$EV/$f"
  [ "$good" -eq 4 ] && ok "2 matriz can-i: 4/4 cumple el objetivo" || bad "2 matriz can-i: $good/4 (mira $EV/$f)"

  # Criterio 3: web sin token, en la plantilla y en los Pods en ejecución
  f=03-token.txt
  run $f kubectl -n "$NS" rollout status deploy/web --timeout=90s >/dev/null
  run $f kubectl -n "$NS" get deploy web -o 'jsonpath={.spec.template.spec.automountServiceAccountToken}{"\n"}' >/dev/null
  run $f kubectl -n "$NS" get pods -l app=web -o 'jsonpath={range .items[*]}{.metadata.name}{"  "}{.spec.volumes[*].name}{"\n"}{end}' >/dev/null
  auto=$(kubectl -n "$NS" get deploy web -o 'jsonpath={.spec.template.spec.automountServiceAccountToken}' 2>/dev/null)
  vols=$(kubectl -n "$NS" get pods -l app=web -o 'jsonpath={.items[*].spec.volumes[*].name}' 2>/dev/null)
  if [ "$auto" = "false" ] && [ -n "$vols" ] && ! grep -q 'kube-api-access' <<<"$vols"; then
    ok "3 web sin token (plantilla y Pods)"
  else bad "3 automount='${auto:-sin definir}' y volúmenes de los Pods: ${vols:-ninguno}"; fi
}

case "${1:-}" in
  pre|check) ;;
  *) echo "uso: bash scripts/dia-07.sh pre | check"; exit 2 ;;
esac
ctx=$(kubectl config current-context 2>/dev/null)
[ "$ctx" = "kind-lab" ] || { echo "❌ contexto '${ctx:-ninguno}': se espera kind-lab. No hago nada."; exit 2; }
"$1"
echo; echo "== Resumen $DIA ($1) =="; printf '%s\n' "${RES[@]}"
[ "$FAILS" -eq 0 ] || { echo "→ $FAILS punto(s) en ❌: míralos antes de seguir."; exit 1; }
