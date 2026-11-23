#!/usr/bin/env bash
# ============================================================================
# tool/ui_gates.sh — portões automáticos de UI do PORTIX (loop v2)
#
# Uso:
#   tool/ui_gates.sh                 # regras estruturais em lib/ + formato nos
#                                    # arquivos .dart alterados (catraca)
#   tool/ui_gates.sh --all           # formato em toda a base (após U2-F)
#   tool/ui_gates.sh --skip-analyze  # CI já roda flutter analyze como passo
#   tool/ui_gates.sh --init          # (re)gera a allowlist a partir do estado atual
#
# Falha se, FORA da allowlist (tool/ui_gates_allowlist.txt):
#   raw_color    — Color(0x…) ou Colors.* fora de lib/core/theme/ e lib/app/theme.dart
#   raw_font     — fontSize: literal fora do tema
#   raw_text     — string literal em Text('…'), tooltip: ou label:
#   tok_size   — EdgeInsets/SizedBox/BorderRadius com número mágico (fora do grid 4/8)
#   debug_print  — print( em lib/
#   secret       — token/keystore versionado (ghp_…, github_pat_…, PRIVATE KEY)
#   analyze      — flutter analyze com qualquer problema
#   format       — arquivo .dart alterado sem dart format limpo
#   ui_change    — commit anterior sem mudança em lib/|assets/|test/|integration_test/|pubspec.yaml
#                  (commits só de .ralph/ são registro do loop e ficam isentos)
#
# Meta do loop: allowlist vazia ao fim do U2. Ao reconstruir uma tela, remova
# as linhas dela da allowlist NO MESMO commit.
# ============================================================================
set -u
cd "$(dirname "$0")/.." || exit 1

ALLOWLIST="tool/ui_gates_allowlist.txt"
MODE="changed"
SKIP_ANALYZE=0
for arg in "$@"; do
  case "$arg" in
    --all) MODE="all" ;;
    --skip-analyze) SKIP_ANALYZE=1 ;;
    --init) INIT=1 ;;
  esac
done
INIT="${INIT:-0}"

FAIL=0

is_allowed() {
  # $1 = regra, $2 = caminho do arquivo
  [ -f "$ALLOWLIST" ] || return 1
  local rule="$1" file="$2" line rule_file prefix
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    rule_file="${line%%:*}"
    [ "$rule_file" = "$rule" ] || continue
    prefix="${line#*:}"
    case "$file" in "$prefix"*) return 0 ;; esac
  done < "$ALLOWLIST"
  return 1
}

# scan <regra> <regex-ERE> [mais -g exclusões para rg]
scan() {
  local rule="$1" pattern="$2"
  shift 2
  local out entry file seen=""
  if command -v rg >/dev/null 2>&1; then
    out=$(rg -n --no-heading -e "$pattern" lib \
      -g '!lib/core/theme/**' -g '!lib/app/theme.dart' "$@" 2>/dev/null || true)
  else
    out=$(grep -rnE "$pattern" lib 2>/dev/null \
      | grep -v '^lib/core/theme/' | grep -v '^lib/app/theme.dart' || true)
  fi
  [ -z "$out" ] && return 0
  while IFS= read -r entry; do
    file="${entry%%:*}"
    [ -n "$file" ] || continue
    case ",$seen," in *",$file,"*) continue ;; esac
    seen="$seen,$file"
    if is_allowed "$rule" "$file"; then
      continue
    fi
    echo "UI_GATE FALHOU [$rule] $file"
    if [ "$INIT" = "1" ]; then
      echo "$rule:$file" >> "$ALLOWLIST.new"
    else
      FAIL=1
    fi
  done <<< "$out"
}

# ---- regras estruturais (varrem lib/ inteiro; allowlist absorve o legado) ---
scan raw_color  '\bColors\.[a-zA-Z]|Color\(0x'
scan raw_font   'fontSize:[[:space:]]*[0-9]'
scan raw_text   "Text\([[:space:]]*'|tooltip:[[:space:]]*'|label:[[:space:]]*'" \
  -g '!lib/app/app_strings.dart'
scan tok_size "SizedBox\((height|width):[[:space:]]*[1-9][0-9.]*[,)]|EdgeInsets\.[a-zA-Z]+\([^)]*[^0-9.][1-9]|BorderRadius\.circular\([1-9]"
scan debug_print '^[[:space:]]*print\('

# ---- segredos ---------------------------------------------------------------
if git grep -nEI 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' -- . >/tmp/portix_secrets.txt 2>&1; then
  echo "UI_GATE FALHOU [secret] ver $(wc -l < /tmp/portix_secrets.txt) ocorrência(s)"
  head -5 /tmp/portix_secrets.txt
  FAIL=1
fi
if git grep -nE 'BEGIN (RSA|EC|OPENSSH) PRIVATE KEY' -- . >/tmp/portix_keys.txt 2>&1; then
  echo "UI_GATE FALHOU [secret] chave privada versionada"
  head -5 /tmp/portix_keys.txt
  FAIL=1
fi

# ---- regra de ouro: iteração precisa tocar UI -------------------------------
if git rev-parse --verify -q 'HEAD~1' >/dev/null 2>&1; then
  UI_CHANGED=$(git diff --name-only HEAD~1 HEAD | grep -Ec '^(lib/|assets/|test/|integration_test/|pubspec\.yaml)' || true)
  ONLY_RALPH=$(git diff --name-only HEAD~1 HEAD | grep -Evc '^\.ralph/' || true)
  if [ "$UI_CHANGED" = "0" ] && [ "$ONLY_RALPH" != "0" ]; then
    echo "UI_GATE FALHOU [ui_change] nenhuma mudança de UI no último commit (lib/|assets/|test/|integration_test/|pubspec.yaml)"
    FAIL=1
  fi
fi

# ---- formato (catraca: alterado = limpo) ------------------------------------
if command -v dart >/dev/null 2>&1; then
  if [ "$MODE" = "all" ]; then
    if ! dart format --output=none --set-exit-if-changed lib test >/tmp/portix_fmt.log 2>&1; then
      echo "UI_GATE FALHOU [format] $(tail -1 /tmp/portix_fmt.log)"
      FAIL=1
    fi
  else
    CHANGED=$({ git diff --name-only HEAD 2>/dev/null
                git diff --cached --name-only 2>/dev/null
                git diff --name-only HEAD~1 HEAD 2>/dev/null; } | sort -u | grep '\.dart$' || true)
    for f in $CHANGED; do
      [ -f "$f" ] || continue
      if ! dart format --output=none --set-exit-if-changed "$f" >/dev/null 2>&1; then
        echo "UI_GATE FALHOU [format] $f (rode: dart format $f)"
        FAIL=1
      fi
    done
  fi
else
  echo "UI_GATE aviso [format] dart ausente — CI cobre"
fi

# ---- flutter analyze --------------------------------------------------------
if [ "$SKIP_ANALYZE" = "1" ]; then
  echo "UI_GATE ok [analyze] pulado (--skip-analyze)"
elif command -v flutter >/dev/null 2>&1; then
  if flutter analyze >/tmp/portix_analyze.log 2>&1; then
    echo "UI_GATE ok [analyze]"
  else
    echo "UI_GATE FALHOU [analyze]"
    tail -20 /tmp/portix_analyze.log
    FAIL=1
  fi
else
  echo "UI_GATE aviso [analyze] flutter ausente — CI cobre"
fi

# ---- resultado --------------------------------------------------------------
if [ "$INIT" = "1" ]; then
  if [ -f "$ALLOWLIST.new" ]; then
    { echo "# Allowlist dos portões de UI (gerada por tool/ui_gates.sh --init)."
      echo "# Formato: regra:prefixo/do/caminho. Drene por tela — meta: vazia no fim do U2."
      sort -u "$ALLOWLIST.new"
      rm -f "$ALLOWLIST.new"
    } > "$ALLOWLIST"
    echo "UI_GATE --init: allowlist escrita em $ALLOWLIST"
  else
    echo "UI_GATE --init: nenhuma violação; allowlist vazia."
  fi
  exit 0
fi

if [ "$FAIL" = "0" ]; then
  echo "UI_GATE: todos os portões verdes."
  exit 0
fi
echo "UI_GATE: FALHOU — corrija ou atualize a allowlist com evidência."
exit 1
