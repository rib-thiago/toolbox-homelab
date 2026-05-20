#!/usr/bin/env bash
set -euo pipefail

# Cores para output (desativa se não for TTY)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; BOLD=''; RESET=''
fi

# Configurações padrão
CONFIG_FILE="$HOME/.gcmrc"
OUTPUT_DIR="./git-reports"
VERBOSE=false
INTERACTIVE=false
INCLUDE_DIFFS=false
DIFF_LINES=0  # 0 = completo
COMMIT_RANGE="HEAD"
FORMAT="markdown"
SINCE=""
UNTIL=""
AUTHOR=""
MAX_COMMITS=0  # 0 = ilimitado

# Carregar configurações se existirem
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Função de ajuda
show_help() {
    cat <<EOF
${BOLD}Git Context Manager (gcm)${RESET} - Ferramenta para análise e documentação de repositórios Git

${BOLD}Uso:${RESET}
  $0 [opções] <comando>

${BOLD}Comandos:${RESET}
  context               Coleta contexto atual do repositório (status, branch, diffs)
  history               Gera relatório histórico por commit
  dashboard             Gera dashboard analítico do repositório
  all                   Executa todos os comandos acima
  interactive           Modo interativo (menu)

${BOLD}Opções Gerais:${RESET}
  -o, --output DIR      Diretório de saída (padrão: ./git-reports)
  -f, --format FORMAT   Formato de saída: markdown, text, json (padrão: markdown)
  -v, --verbose         Output verboso
  -h, --help            Mostra esta ajuda

${BOLD}Opções para 'history':${RESET}
  -r, --range RANGE     Range de commits (ex: HEAD~10..HEAD, main..feature)
  -d, --diffs           Incluir diffs completos (padrão: false)
  -l, --lines N         Limitar diffs a N linhas por arquivo (0 = completo)
  -s, --since DATE      Commits desde DATE (ex: "2026-01-01", "2 weeks ago")
  -u, --until DATE      Commits até DATE
  -a, --author AUTHOR   Filtrar por autor (regex)
  -m, --max N           Número máximo de commits

${BOLD}Opções para 'dashboard':${RESET}
  --no-graphs           Não gerar gráficos ASCII
  --csv                 Gerar dados em CSV além do formato principal

${BOLD}Exemplos:${RESET}
  $0 context                             # Coleta contexto atual
  $0 history -d -r HEAD~20                # Histórico dos últimos 20 commits com diffs
  $0 dashboard --csv                      # Dashboard com dados CSV
  $0 all -o ./reports -f json              # Todos os relatórios em JSON
  $0 interactive                           # Modo interativo

EOF
}

# Função de logging
log() {
    local level="$1"
    shift
    case "$level" in
        INFO)  echo -e "${GREEN}[INFO]${RESET} $*" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN]${RESET} $*" >&2 ;;
        ERROR) echo -e "${RED}[ERROR]${RESET} $*" >&2 ;;
        DEBUG) [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[DEBUG]${RESET} $*" >&2 ;;
    esac
}

# Verificar se está em um repositório git
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log ERROR "Não está em um repositório Git"
        exit 1
    fi
}

# Criar diretório de saída
setup_output_dir() {
    mkdir -p "$OUTPUT_DIR"
    log DEBUG "Diretório de saída: $OUTPUT_DIR"
}

# Escapar para JSON
json_escape() {
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || \
    printf '"%s"' "$(sed 's/["\\]/\\&/g' <<< "$1")"
}

# Gerar timestamp
timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# ============================================================================
# COMANDO: context
# ============================================================================
cmd_context() {
    log INFO "Coletando contexto do repositório..."
    setup_output_dir
    
    local output_file="$OUTPUT_DIR/context_$(timestamp).$FORMAT"
    local repo_name=$(basename "$(pwd)")
    local branch=$(git branch --show-current 2>/dev/null || echo "detached")
    local commit_hash=$(git rev-parse HEAD)
    local commit_msg=$(git log -1 --format=%s)
    
    case "$FORMAT" in
        markdown)
            {
                echo "# Contexto do Repositório: $repo_name"
                echo "**Gerado em:** $(date)"
                echo "**Branch:** $branch"
                echo "**HEAD:** $commit_hash - $commit_msg"
                echo
                
                echo "## Status"
                echo '```'
                git status --short
                echo '```'
                echo
                
                echo "## Últimos Commits"
                echo '```'
                git log --oneline --decorate -n 15
                echo '```'
                echo
                
                echo "## Arquivos não monitorados"
                echo '```'
                git ls-files --others --exclude-standard
                echo '```'
                echo
                
                echo "## Diff resumido"
                echo '```'
                git diff --stat
                echo '```'
                echo
                
                echo "## Diff completo"
                echo '```diff'
                git diff
                echo '```'
            } > "$output_file"
            ;;
            
        json)
            {
                printf '{\n'
                printf '  "repository": "%s",\n' "$repo_name"
                printf '  "generated": "%s",\n' "$(date --iso-8601=seconds)"
                printf '  "branch": "%s",\n' "$branch"
                printf '  "head": "%s",\n' "$commit_hash"
                printf '  "status": '
                git status --short | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]'
                printf ',\n  "logs": '
                git log --oneline --decorate -n 15 | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]'
                printf ',\n  "untracked": '
                git ls-files --others --exclude-standard | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]'
                printf ',\n  "diff_stat": '
                git diff --stat | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]'
                printf '\n}\n'
            } > "$output_file"
            ;;
            
        text)
            {
                echo "=== CONTEXTO DO REPOSITÓRIO: $repo_name ==="
                echo "Gerado em: $(date)"
                echo "Branch: $branch"
                echo "HEAD: $commit_hash - $commit_msg"
                echo
                echo "=== STATUS ==="
                git status --short
                echo
                echo "=== ÚLTIMOS COMMITS ==="
                git log --oneline --decorate -n 15
                echo
                echo "=== ARQUIVOS NÃO MONITORADOS ==="
                git ls-files --others --exclude-standard
                echo
                echo "=== DIFF RESUMIDO ==="
                git diff --stat
                echo
                echo "=== DIFF COMPLETO ==="
                git diff
            } > "$output_file"
            ;;
    esac
    
    log INFO "Contexto salvo em: $output_file"
}

# ============================================================================
# COMANDO: history
# ============================================================================
cmd_history() {
    log INFO "Gerando relatório histórico..."
    setup_output_dir
    
    local output_file="$OUTPUT_DIR/history_$(timestamp).$FORMAT"
    local repo_name=$(basename "$(pwd)")
    local total_commits=0
    local processed=0
    
    # Construir lista de commits com filtros
    local git_log_cmd="git log --reverse --format=%H"
    
    [[ -n "$SINCE" ]] && git_log_cmd+=" --since=\"$SINCE\""
    [[ -n "$UNTIL" ]] && git_log_cmd+=" --until=\"$UNTIL\""
    [[ -n "$AUTHOR" ]] && git_log_cmd+=" --author=\"$AUTHOR\""
    [[ -n "$COMMIT_RANGE" && "$COMMIT_RANGE" != "HEAD" ]] && git_log_cmd+=" $COMMIT_RANGE"
    
    log DEBUG "Comando: $git_log_cmd"
    
    # Coletar todos os hashes primeiro para contagem
    local commits=()
    while IFS= read -r hash; do
        commits+=("$hash")
    done < <(eval "$git_log_cmd")
    
    total_commits=${#commits[@]}
    
    if [[ $MAX_COMMITS -gt 0 && $total_commits -gt $MAX_COMMITS ]]; then
        commits=("${commits[@]:0:$MAX_COMMITS}")
        total_commits=$MAX_COMMITS
    fi
    
    log INFO "Processando $total_commits commits..."
    
    case "$FORMAT" in
        markdown)
            {
                echo "# Histórico do Repositório: $repo_name"
                echo "**Gerado em:** $(date)"
                echo "**Range:** ${COMMIT_RANGE} | **Commits:** $total_commits"
                [[ -n "$SINCE" ]] && echo "**Desde:** $SINCE"
                [[ -n "$UNTIL" ]] && echo "**Até:** $UNTIL"
                [[ -n "$AUTHOR" ]] && echo "**Autor:** $AUTHOR"
                echo
                echo "---"
                echo
            } > "$output_file"
            
            for hash in "${commits[@]}"; do
                ((processed++))
                log DEBUG "[$processed/$total_commits] Processando $hash"
                
                local author=$(git log -1 --format="%an <%ae>" "$hash")
                local date=$(git log -1 --format=%ad --date=iso "$hash")
                local msg=$(git log -1 --format=%s "$hash")
                local body=$(git log -1 --format=%b "$hash")
                local stats=$(git show --stat "$hash" | tail -n 1)
                local files=$(git show --name-only --format="" "$hash" | sort -u | grep -v '^$')
                
                {
                    echo "## Commit $hash"
                    echo "**Data:** $date"
                    echo "**Autor:** $author"
                    echo "**Mensagem:** $msg"
                    
                    if [[ -n "$body" ]]; then
                        echo
                        echo "### Descrição"
                        echo "\`\`\`"
                        echo "$body"
                        echo "\`\`\`"
                    fi
                    
                    echo
                    echo "### Arquivos"
                    for file in $files; do
                        echo "- \`$file\`"
                    done
                    
                    echo
                    echo "### Estatísticas"
                    echo "\`\`\`"
                    echo "$stats"
                    echo "\`\`\`"
                    
                    if [[ "$INCLUDE_DIFFS" == true ]]; then
                        echo
                        echo "### Diff"
                        echo "\`\`\`diff"
                        
                        if [[ $DIFF_LINES -gt 0 ]]; then
                            # Limitar linhas por arquivo
                            git show --format="" "$hash" | while IFS= read -r line; do
                                if [[ "$line" =~ ^diff\ --git ]]; then
                                    file_lines=0
                                fi
                                echo "$line"
                                ((file_lines++))
                                if [[ $file_lines -ge $DIFF_LINES ]]; then
                                    echo "... (diff truncado após $DIFF_LINES linhas)"
                                    # Pular até o próximo diff
                                    while IFS= read -r next && [[ ! "$next" =~ ^diff\ --git ]]; do :; done
                                    echo "$next"
                                fi
                            done
                        else
                            git show --format="" "$hash"
                        fi
                        
                        echo "\`\`\`"
                    fi
                    
                    echo
                    echo "---"
                    echo
                } >> "$output_file"
            done
            ;;
            
        json)
            {
                printf '{\n'
                printf '  "repository": "%s",\n' "$repo_name"
                printf '  "generated": "%s",\n' "$(date --iso-8601=seconds)"
                printf '  "range": "%s",\n' "$COMMIT_RANGE"
                printf '  "total_commits": %d,\n' "$total_commits"
                printf '  "commits": [\n'
                
                local first=true
                for hash in "${commits[@]}"; do
                    [[ "$first" == true ]] || printf ',\n'
                    first=false
                    
                    local author=$(git log -1 --format="%an" "$hash" | sed 's/"/\\"/g')
                    local email=$(git log -1 --format="%ae" "$hash" | sed 's/"/\\"/g')
                    local date=$(git log -1 --format=%ad --date=iso "$hash")
                    local msg=$(git log -1 --format=%s "$hash" | sed 's/"/\\"/g')
                    local body=$(git log -1 --format=%b "$hash" | sed 's/"/\\"/g' | tr '\n' ' ')
                    
                    printf '    {\n'
                    printf '      "hash": "%s",\n' "$hash"
                    printf '      "author": "%s",\n' "$author"
                    printf '      "email": "%s",\n' "$email"
                    printf '      "date": "%s",\n' "$date"
                    printf '      "message": "%s",\n' "$msg"
                    printf '      "body": "%s"\n' "$body"
                    printf '    }'
                done
                
                printf '\n  ]\n}\n'
            } > "$output_file"
            ;;
    esac
    
    log INFO "Relatório histórico salvo em: $output_file"
}

# ============================================================================
# COMANDO: dashboard
# ============================================================================
cmd_dashboard() {
    log INFO "Gerando dashboard do repositório..."
    setup_output_dir
    
    local output_file="$OUTPUT_DIR/dashboard_$(timestamp).$FORMAT"
    local repo_name=$(basename "$(pwd)")
    
    # Coletar métricas
    local total_commits=$(git rev-list --count HEAD)
    local total_authors=$(git shortlog -s -n | wc -l)
    local first_commit=$(git log --reverse --format=%ad --date=short | head -1)
    local last_commit=$(git log --format=%ad --date=short | head -1)
    local branches=$(git branch | wc -l)
    local tags=$(git tag | wc -l)
    local total_files=$(git ls-files | wc -l)
    
    case "$FORMAT" in
        markdown)
            {
                echo "# Dashboard do Repositório: $repo_name"
                echo "**Gerado em:** $(date)"
                echo
                echo "## Visão Geral"
                echo "| Métrica | Valor |"
                echo "|---------|-------|"
                echo "| Commits totais | $total_commits |"
                echo "| Contribuidores | $total_authors |"
                echo "| Branches | $branches |"
                echo "| Tags | $tags |"
                echo "| Arquivos rastreados | $total_files |"
                echo "| Primeiro commit | $first_commit |"
                echo "| Último commit | $last_commit |"
                echo
                
                echo "## Top Contribuidores"
                echo "| Autor | Commits | % |"
                echo "|-------|---------|---|"
                git shortlog -s -n | head -10 | while read -r count author; do
                    percent=$((count * 100 / total_commits))
                    echo "| $author | $count | $percent% |"
                done
                echo
                
                echo "## Top Arquivos Mais Modificados"
                echo "| Arquivo | Commits |"
                echo "|---------|---------|"
                git log --name-only --format="" | sort | uniq -c | sort -nr | head -15 | while read -r count file; do
                    echo "| \`$file\` | $count |"
                done
                echo
                
                echo "## Commits por Tipo (baseado na mensagem)" >> "$output_file" 
                local feat=0 fix=0 docs=0 refactor=0 chore=0 test=0 other=0
                while read -r msg; do
                    case "$msg" in
                        feat*|feature*) ((feat++)) ;;
                        fix*) ((fix++)) ;;
                        docs*) ((docs++)) ;;
                        refactor*) ((refactor++)) ;;
                        chore*) ((chore++)) ;;
                        test*) ((test++)) ;;
                        *) ((other++)) ;;
                    esac
                done < <(git log --format=%s)
                
                {
                    echo "| Tipo | Quantidade | % |"
                    echo "|------|------------|---|"
                    echo "| ✨ feat | $feat | $((feat * 100 / total_commits))% |"
                    echo "| 🐛 fix | $fix | $((fix * 100 / total_commits))% |"
                    echo "| 📝 docs | $docs | $((docs * 100 / total_commits))% |"
                    echo "| 🔧 refactor | $refactor | $((refactor * 100 / total_commits))% |"
                    echo "| 🧹 chore | $chore | $((chore * 100 / total_commits))% |"
                    echo "| 🧪 test | $test | $((test * 100 / total_commits))% |"
                    echo "| 📦 other | $other | $((other * 100 / total_commits))% |"
                } >> "$output_file"
                echo >> "$output_file"
                
                echo "## Atividade Recente (últimos 30 dias)" >> "$output_file"
                echo '```' >> "$output_file"
                git log --since="30 days ago" --format=%ad --date=format:%a | sort | uniq -c | while read -r count day; do
                    bar=$(printf '%*s' $((count * 2)) '' | tr ' ' '█')
                    printf "%3s %s %s\n" "$count" "$day" "$bar"
                done >> "$output_file"
                echo '```' >> "$output_file"
                echo >> "$output_file"
                
                echo "## Atividade por Hora do Dia" >> "$output_file"
                echo '```' >> "$output_file"
                git log --format=%ad --date=format:%H | sort | uniq -c | while read -r count hour; do
                    bar=$(printf '%*s' $((count / 2)) '' | tr ' ' '█')
                    printf "%2s:00 %s %s\n" "$hour" "$bar" "$count"
                done >> "$output_file"
                echo '```' >> "$output_file"
                
            } > "$output_file"
            ;;
    esac
    
    log INFO "Dashboard salvo em: $output_file"
}

# ============================================================================
# MODO INTERATIVO
# ============================================================================
cmd_interactive() {
    echo -e "${BOLD}Git Context Manager - Modo Interativo${RESET}"
    echo
    
    local options=(
        "Coletar contexto atual"
        "Gerar relatório histórico (commits)"
        "Gerar dashboard analítico"
        "Executar todos os comandos"
        "Configurar opções"
        "Sair"
    )
    
    PS3="Escolha uma opção (1-${#options[@]}): "
    select opt in "${options[@]}"; do
        case "$opt" in
            "Coletar contexto atual")
                read -p "Formato (markdown/json/text) [markdown]: " fmt
                FORMAT="${fmt:-markdown}"
                cmd_context
                ;;
            "Gerar relatório histórico (commits)")
                read -p "Incluir diffs? (s/N): " inc
                [[ "$inc" =~ ^[Ss] ]] && INCLUDE_DIFFS=true
                read -p "Número máximo de commits [0=ilimitado]: " max
                MAX_COMMITS="${max:-0}"
                read -p "Formato (markdown/json) [markdown]: " fmt
                FORMAT="${fmt:-markdown}"
                cmd_history
                ;;
            "Gerar dashboard analítico")
                read -p "Formato (markdown) [markdown]: " fmt
                FORMAT="${fmt:-markdown}"
                cmd_dashboard
                ;;
            "Executar todos os comandos")
                read -p "Incluir diffs no histórico? (s/N): " inc
                [[ "$inc" =~ ^[Ss] ]] && INCLUDE_DIFFS=true
                read -p "Formato (markdown) [markdown]: " fmt
                FORMAT="${fmt:-markdown}"
                cmd_context
                cmd_history
                cmd_dashboard
                ;;
            "Configurar opções")
                configure_options
                ;;
            "Sair")
                break
                ;;
            *)
                echo "Opção inválida"
                ;;
        esac
        echo
        PS3="Escolha uma opção (1-${#options[@]}): "
    done
}

configure_options() {
    echo "Configurações atuais:"
    echo "1. Diretório de saída: $OUTPUT_DIR"
    echo "2. Formato padrão: $FORMAT"
    echo "3. Verboso: $VERBOSE"
    echo "4. Voltar"
    
    read -p "Escolha uma opção para alterar (1-4): " opt
    case "$opt" in
        1)
            read -p "Novo diretório de saída: " new_dir
            OUTPUT_DIR="$new_dir"
            ;;
        2)
            read -p "Novo formato padrão (markdown/json/text): " new_fmt
            FORMAT="$new_fmt"
            ;;
        3)
            VERBOSE=$([[ "$VERBOSE" == true ]] && echo false || echo true)
            echo "Verboso agora é $VERBOSE"
            ;;
        4)
            return
            ;;
    esac
    
    # Perguntar se quer salvar configurações
    read -p "Salvar configurações em $CONFIG_FILE? (s/N): " save
    if [[ "$save" =~ ^[Ss] ]]; then
        cat > "$CONFIG_FILE" <<EOF
# Configuração do Git Context Manager
OUTPUT_DIR="$OUTPUT_DIR"
FORMAT="$FORMAT"
VERBOSE=$VERBOSE
EOF
        log INFO "Configurações salvas em $CONFIG_FILE"
    fi
}

# ============================================================================
# PARSING DE ARGUMENTOS
# ============================================================================
parse_args() {
    # Se não houver argumentos, mostrar ajuda
    [[ $# -eq 0 ]] && { show_help; exit 0; }
    
    COMMAND=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            context|history|dashboard|all|interactive)
                COMMAND="$1"
                shift
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            -r|--range)
                COMMIT_RANGE="$2"
                shift 2
                ;;
            -d|--diffs)
                INCLUDE_DIFFS=true
                shift
                ;;
            -l|--lines)
                DIFF_LINES="$2"
                shift 2
                ;;
            -s|--since)
                SINCE="$2"
                shift 2
                ;;
            -u|--until)
                UNTIL="$2"
                shift 2
                ;;
            -a|--author)
                AUTHOR="$2"
                shift 2
                ;;
            -m|--max)
                MAX_COMMITS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Opção desconhecida: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    parse_args "$@"
    
    # Verificar se está em repositório git (exceto para help)
    if [[ "$COMMAND" != "interactive" && -n "$COMMAND" ]]; then
        check_git_repo
    fi
    
    case "$COMMAND" in
        context)
            cmd_context
            ;;
        history)
            cmd_history
            ;;
        dashboard)
            cmd_dashboard
            ;;
        all)
            cmd_context
            cmd_history
            cmd_dashboard
            ;;
        interactive)
            cmd_interactive
            ;;
        *)
            log ERROR "Comando não reconhecido: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
