#!/usr/bin/env bash
# Día 8 (hardening de Pods y Pod Security Admission). Se ejecuta desde la raíz del repo:
#   bash scripts/dia-08.sh pre     # Parte 0 (nivel 1) y estado del clúster -> evidence/dia-08/00-seguro.txt
#   bash scripts/dia-08.sh check   # criterios 1 a 3 -> evidence/dia-08/01-securitycontext.txt, 02-psa.txt, 03-privilegiado.txt
# Antes de `check`, escribe tu predicción en evidence/dia-08/00-prediccion.txt (4 líneas: `yes` o `no`, o `caso: yes`).
set -u
DIA=dia-08; NS=lab
EV="evidence/$DIA"; mkdir -p "$EV"
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
  # S2: manifiestos válidos contra el servidor (solo cuando no quedan blancos: un booleano con ___ no valida)
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
}

check() {
  local f line code npods nbad lab psa out rc img manifest i
  if grep -n '___' manifests/namespace.yaml manifests/web-deployment.yaml; then
    echo "❌ quedan blancos ___ (líneas de arriba). Complétalos y aplica antes de verificar."; exit 1; fi

  # Criterio 1: securityContext completo en la plantilla y en los Pods, con web Ready y sirviendo
  f=01-securitycontext.txt
  # seccomp vale en el Pod o en el contenedor ("seccomp=RuntimeDefault " también casa dentro de "cseccomp=RuntimeDefault ")
  local TPL='runAsNonRoot={.spec.template.spec.securityContext.runAsNonRoot} seccomp={.spec.template.spec.securityContext.seccompProfile.type} cseccomp={.spec.template.spec.containers[0].securityContext.seccompProfile.type} allowPrivilegeEscalation={.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation} readOnlyRootFilesystem={.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem} drop={.spec.template.spec.containers[0].securityContext.capabilities.drop[*]} tmp={.spec.template.spec.containers[0].volumeMounts[?(@.mountPath=="/tmp")].name} ready={.status.readyReplicas}/{.spec.replicas}{"\n"}'
  local PODS='jsonpath={range .items[*]}{.metadata.deletionTimestamp}{"|"}{.metadata.name}{"|"}{.spec.containers[0].securityContext.readOnlyRootFilesystem}{"|"}{.status.phase}{"\n"}{end}'
  run $f kubectl -n "$NS" rollout status deploy/web --timeout=120s >/dev/null
  run $f kubectl -n "$NS" get deploy web -o "jsonpath=$TPL" >/dev/null
  run $f kubectl -n "$NS" get pods -l app=web -o "$PODS" >/dev/null
  run $f curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: lab.local' http://127.0.0.1/ >/dev/null
  line=$(kubectl -n "$NS" get deploy web -o "jsonpath=$TPL" 2>/dev/null)
  out=$(kubectl -n "$NS" get pods -l app=web -o "$PODS" 2>/dev/null | awk -F'|' '$1==""')
  npods=$(printf '%s\n' "$out" | grep -c '|web-')
  nbad=$(printf '%s\n' "$out" | awk -F'|' '$2!="" && ($3!="true" || $4!="Running")' | wc -l)
  code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: lab.local' http://127.0.0.1/ 2>/dev/null)
  echo "plantilla: $line"; echo "Pods en ejecución: $npods, fuera de norma: $nbad, curl lab.local = ${code:-sin respuesta}"
  if [[ $line == *"runAsNonRoot=true "* && $line == *"seccomp=RuntimeDefault "* && $line == *"allowPrivilegeEscalation=false "* \
     && $line == *"readOnlyRootFilesystem=true "* && $line == *"drop=ALL "* && $line =~ tmp=[^[:space:]] \
     && $line == *"ready=3/3"* && $npods -eq 3 && $nbad -eq 0 && $code == 200 ]]; then
    ok "1 securityContext completo, 3 Pods Ready y web sirviendo"
  else bad "1 securityContext incompleto o Pods no listos (mira $EV/$f)"; fi

  # Criterio 2: etiquetas de PSA y web sin advertencias de nivel restricted
  # Sonda: `apply --dry-run=server` de cada manifiesto. Con warn=restricted el servidor avisa "would violate PodSecurity",
  # aunque enforce ya esté en restricted (el dry-run de la etiqueta no compara nada si la etiqueta no cambia).
  f=02-psa.txt
  local LBL='enforce={.metadata.labels.pod-security\.kubernetes\.io/enforce} warn={.metadata.labels.pod-security\.kubernetes\.io/warn} audit={.metadata.labels.pod-security\.kubernetes\.io/audit}{"\n"}'
  run $f kubectl get ns "$NS" -o "jsonpath=$LBL" >/dev/null
  lab=$(kubectl get ns "$NS" -o "jsonpath=$LBL" 2>/dev/null)
  local o_web o_db o_api w_web w_db w_api
  run $f kubectl apply --dry-run=server -f manifests/web-deployment.yaml >/dev/null
  o_web=$(kubectl apply --dry-run=server -f manifests/web-deployment.yaml 2>&1)
  run $f kubectl apply --dry-run=server -f manifests/db-deployment.yaml >/dev/null
  o_db=$(kubectl apply --dry-run=server -f manifests/db-deployment.yaml 2>&1)
  run $f kubectl apply --dry-run=server -f manifests/api.yaml >/dev/null
  o_api=$(kubectl apply --dry-run=server -f manifests/api.yaml 2>&1)
  pw() {  # cuenta los avisos de restricted de una salida de apply; n/d si el apply falló o warn no es restricted
    if [[ $lab != *"warn=restricted "* ]] || ! grep -q 'server dry run' <<<"$1"; then echo "n/d"
    else grep -c 'would violate PodSecurity "restricted' <<<"$1"; fi; }
  w_web=$(pw "$o_web"); w_db=$(pw "$o_db"); w_api=$(pw "$o_api")
  echo "etiquetas: $lab"; echo "avisos de restricted (apply --dry-run=server): web=$w_web db=$w_db api=$w_api"
  if [ "$lab" = "enforce=baseline warn=restricted audit=restricted" ] && [ "$w_web" = "0" ]; then
    ok "2 PSA baseline/restricted/restricted y web sin advertencias"
  else bad "2 etiquetas='${lab:-ninguna}' y avisos de web=$w_web (mira $EV/$f)"; fi

  # Criterio 3: un Pod privilegiado es rechazado (dry-run del servidor: no se crea nada)
  f=03-privilegiado.txt
  img=$(kubectl -n "$NS" get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  manifest="apiVersion: v1
kind: Pod
metadata:
  name: priv-test
  namespace: $NS
spec:
  containers:
  - name: t
    image: $img
    securityContext:
      privileged: true"
  out=$(printf '%s\n' "$manifest" | kubectl create --dry-run=server -f - 2>&1); rc=$?
  { echo "# $(date -u -Iseconds)"; echo '$ kubectl create --dry-run=server -f -   # Pod priv-test con privileged: true; no se crea nada'
    printf '%s\n' "$manifest"; echo "--- respuesta ---"; echo "$out"; echo "exit=$rc"; echo; } | tee -a "$EV/$f"
  if [ "$rc" -ne 0 ] && grep -Eq 'violates PodSecurity "(baseline|restricted)' <<<"$out"; then ok "3 Pod privilegiado rechazado por PodSecurity"
  else bad "3 el Pod privilegiado no fue rechazado por PodSecurity (mira $EV/$f)"; fi

  # Predicciones (00-prediccion.txt, una línea yes/no por caso) frente a lo real
  local -a CASO=("web aparece en las advertencias de restricted" "db aparece en las advertencias de restricted" \
    "api aparece en las advertencias de restricted" "un Pod privilegiado es rechazado") pred=() real=() EXP=(no "" "" yes)
  yn() { case "$1" in 0) echo no ;; n/d) echo n/d ;; *) echo yes ;; esac; }
  real=("$(yn "$w_web")" "$(yn "$w_db")" "$(yn "$w_api")" "$([ "$rc" -ne 0 ] && echo yes || echo no)")
  if [ -f "$EV/00-prediccion.txt" ]; then
    mapfile -t pred < <(tr -d '\r' <"$EV/00-prediccion.txt" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' \
      | tr 'A-Z' 'a-z' | sed -e 's/[[:space:]]*$//' -e 's/.*[[:space:]:]//' -e 's/^si$/yes/' -e 's/^sí$/yes/')
    echo "predicción escrita: $(date -u -r "$EV/00-prediccion.txt" -Iseconds)" | tee -a "$EV/$f"
    [ "${#pred[@]}" -gt 0 ] || echo "⚠️  $EV/00-prediccion.txt no tiene líneas yes/no: la apuesta no cuenta." | tee -a "$EV/$f"
  else
    echo "⚠️  no hay $EV/00-prediccion.txt: escríbela ANTES de ejecutar (4 líneas, yes o no)." | tee -a "$EV/$f"
  fi
  local hits=0
  printf '%-2s %-48s %-10s %-6s %s\n' '#' caso 'tu apuesta' real objetivo | tee -a "$EV/$f"
  for i in 0 1 2 3; do
    [ "${pred[i]:-?}" = "${real[i]}" ] && hits=$((hits + 1))
    printf '%-2s %-48s %-10s %-6s %s\n' "$((i + 1))" "${CASO[i]}" "${pred[i]:-?}" "${real[i]}" \
      "$([ -z "${EXP[i]}" ] && echo "—" || { [ "${real[i]}" = "${EXP[i]}" ] && echo "✅ (${EXP[i]})" || echo "❌ (se espera ${EXP[i]})"; })" | tee -a "$EV/$f"
  done
  echo "aciertos de tu predicción: $hits/4" | tee -a "$EV/$f"

  # Opcional O2: avisos de restricted para db y api (solo informa)
  { echo "# $(date -u -Iseconds)"; echo '$ kubectl apply --dry-run=server -f manifests/db-deployment.yaml -f manifests/api.yaml   # avisos de restricted'
    echo "[db]"; grep 'would violate' <<<"$o_db" || echo "(sin avisos)"
    echo "[api]"; grep 'would violate' <<<"$o_api" || echo "(sin avisos)"; echo; } | tee -a "$EV/04-opcional-warnings.txt"
}

case "${1:-}" in
  pre|check) ;;
  *) echo "uso: bash scripts/dia-08.sh pre | check"; exit 2 ;;
esac
ctx=$(kubectl config current-context 2>/dev/null)
[ "$ctx" = "kind-lab" ] || { echo "❌ contexto '${ctx:-ninguno}': se espera kind-lab. No hago nada."; exit 2; }
"$1"
echo; echo "== Resumen $DIA ($1) =="; printf '%s\n' "${RES[@]}"
[ "$FAILS" -eq 0 ] || { echo "→ $FAILS punto(s) en ❌: míralos antes de seguir."; exit 1; }
