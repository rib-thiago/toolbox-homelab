# Toolbox Script Conventions

## 1. Objetivo

Este documento define as convenções operacionais e arquiteturais para scripts da Toolbox.

A Toolbox evoluiu de um conjunto de scripts isolados para uma plataforma operacional modular utilizada para:

* automação do homelab;
* pipelines multimídia;
* curadoria arquivística;
* processamento de documentos;
* manutenção operacional;
* observabilidade;
* workflows de administração;
* documentação operacional executável.

O objetivo destas convenções é:

* reduzir drift operacional;
* manter previsibilidade;
* padronizar outputs;
* facilitar manutenção futura;
* facilitar automação;
* permitir crescimento incremental sem caos estrutural;
* preservar auditabilidade;
* separar claramente diagnóstico, plano, aplicação e validação;
* reconciliar a arquitetura original da Toolbox com a prática operacional emergente.

Este documento deve ser lido em conjunto com:

* `docs/operations/toolbox_architecture_reconciliation.md`;
* `docs/operations/toolbox_scripts_lib_policy.md`;
* `docs/operations/toolbox_runtime_profiles.md`;
* `docs/operations/toolbox_manpages_policy.md`;
* `docs/operations/toolbox_git_routine.md`;
* `docs/operations/toolbox_reports_policy.md`;
* `docs/operations/toolbox_logging_policy.md`.

---

## 2. Filosofia geral

A Toolbox segue uma filosofia:

* Unix-like;
* incremental;
* operacional;
* auditável;
* orientada a scripts legíveis;
* baseada em ferramentas pequenas;
* compatível com pipelines;
* conservadora com destruição;
* simples antes de sofisticada;
* documentada pelo próprio uso;
* capaz de operar em host-mode e container-mode.

Prioridades:

1. segurança;
2. previsibilidade;
3. auditabilidade;
4. reversibilidade;
5. clareza operacional;
6. automação gradual;
7. ergonomia;
8. performance.

A Toolbox não deve evoluir para:

* microservices desnecessários;
* Kubernetes;
* abstrações excessivas;
* frameworks pesados;
* dependências invisíveis;
* scripts opacos;
* automação destrutiva sem validação.

Preferência por:

* shell simples;
* funções explícitas;
* ferramentas Unix;
* pipelines quando fizerem sentido;
* workflows operacionais por fase quando houver risco;
* documentação local;
* validação antes de apply.

---

## 3. Modelo operacional da Toolbox

A Toolbox passa a reconhecer explicitamente três eixos de classificação para scripts:

```text
domínio operacional
runtime
tipo de automação
```

### 3.1 Domínios operacionais

Domínios reconhecidos:

```text
core
document-processing
media-archive
homelab-admin
operations
future-interface
```

### 3.2 Runtimes

Runtimes reconhecidos:

```text
host-mode
container-mode
both
```

### 3.3 Tipos de automação

Tipos reconhecidos:

```text
atomic tool
run-job pipeline
operational workflow
admin diagnostic
archive campaign
support command
```

Essas categorias orientam naming, documentação, outputs, validação e segurança.

---

## 4. host-mode

`host-mode` é usado quando o script precisa observar, auditar ou modificar o estado real do homelab.

Usar host-mode quando o script precisa acessar:

* `/srv`;
* `/srv/media`;
* `/srv/compose`;
* Docker daemon;
* UFW;
* Tailscale;
* Restic;
* Samba;
* Navidrome;
* FileBrowser;
* Git real;
* permissões reais;
* serviços reais;
* discos reais;
* paths reais da biblioteca.

Exemplos de scripts host-mode:

```text
scripts/admin/system/*
scripts/admin/docker/*
scripts/admin/network/*
scripts/admin/storage/*
scripts/admin/backup/*
scripts/admin/firewall/*
scripts/admin/git/*
scripts/media/stockhausen/*
```

Scripts host-mode são o padrão para:

* diagnósticos administrativos;
* auditorias do homelab;
* curadoria de acervos vivos;
* validações do estado real;
* rotinas Git;
* imports para bibliotecas canônicas;
* alterações em `/srv/media`.

---

## 5. container-mode

`container-mode` é usado quando o processo pode ser encapsulado em entrada, trabalho intermediário e saída reprodutível.

Usar container-mode quando o trabalho puder operar sobre:

* input controlado;
* cópia;
* staging;
* diretório de job;
* `/toolbox/shared`;
* `/toolbox/jobs`;
* `input/`;
* `work/`;
* `output/`.

Exemplos de container-mode:

* OCR;
* PDF;
* processamento de imagem;
* NLP;
* split de áudio em staging;
* verificação de FLAC em cópia;
* conversão de artwork em cópia;
* extração de metadados sem alterar acervo canônico.

O container-mode será organizado futuramente em perfis:

```text
toolbox-base
toolbox-docs
toolbox-media
toolbox-nlp
```

`toolbox-media` é prioridade de implementação após consolidação documental e plano de implementação.

---

## 6. Estrutura de diretórios

A estrutura da Toolbox deve preservar a intenção original, mas reconhecer a prática real.

Raiz principal:

```text
/srv/toolbox/app/
```

Áreas principais:

```text
bin/
scripts/
docs/
```

Áreas operacionais externas ao repositório:

```text
/srv/toolbox/shared/
/srv/toolbox/jobs/
/srv/toolbox/models/
/srv/toolbox/secrets/
```

### 6.1 `bin/`

Contém comandos públicos ou wrappers estáveis.

Exemplos:

```text
ocr
pdf-text
pdf-images
img-convert
exif
run-job
```

Comandos em `bin/` devem preferencialmente ter documentação em `docs/man1`.

### 6.2 `scripts/admin/`

Scripts operacionais de infraestrutura:

```text
admin/backup/
admin/docker/
admin/firewall/
admin/git/
admin/network/
admin/storage/
admin/system/
```

Esses scripts normalmente rodam em host-mode.

### 6.3 `scripts/media/`

Scripts e workflows de mídia:

```text
media/library/
media/soulseek/
media/stockhausen/
```

Usos:

* música;
* metadata;
* artwork;
* archival;
* transcoding;
* inventários;
* curadoria.

### 6.4 `scripts/helpers/`

Implementações de ferramentas atômicas, especialmente da arquitetura original da Toolbox.

Uso típico:

* OCR;
* PDF;
* imagem;
* texto;
* comandos pequenos reutilizáveis.

### 6.5 `scripts/pipelines/`

Implementações de pipelines compostos, especialmente aqueles executados por `run-job`.

Uso típico:

* `pdf-ocr`;
* `image-ocr-translate`;
* futuros pipelines encapsulados de mídia.

### 6.6 `scripts/lib/`

Biblioteca comum mínima da Toolbox.

`scripts/lib` deixa de ser placeholder futuro e deve ser criado como base comum real, com adoção gradual.

Módulos iniciais esperados:

```text
scripts/lib/logging.sh
scripts/lib/timestamps.sh
scripts/lib/paths.sh
scripts/lib/tsv.sh
scripts/lib/reports.sh
```

A biblioteca não deve virar framework.

Ela deve conter apenas funções simples, explícitas e reutilizáveis.

### 6.7 `scripts/dev/`

Namespace reservado para futuras ferramentas de ergonomia operacional e desenvolvimento (`toolbox-dev`).

Ainda experimental.

### 6.8 `docs/operations/`

Políticas vivas, convenções, reconciliações arquiteturais e documentação operacional.

### 6.9 `docs/media/`

Documentação de acervos, políticas específicas de mídia e modelos arquivísticos.

### 6.10 `docs/man1/` e `docs/man7/`

Manpages Unix.

```text
docs/man1/ = comandos de usuário
docs/man7/ = conceitos, arquitetura e políticas estáveis
```

---

## 7. Shell environment modular

A Toolbox utiliza ambiente shell modular baseado em:

```text
~/.bashrc.d/
~/.bash_aliases.d/
```

Objetivos:

* organização incremental;
* separação de responsabilidades;
* redução de drift;
* ergonomia operacional;
* manutenção simplificada.

### 7.1 `~/.bashrc.d/`

Responsável por:

* PATH;
* ergonomia shell;
* Starship;
* zoxide;
* helpers operacionais;
* bootstrap do shell.

### 7.2 `~/.bash_aliases.d/`

Responsável por:

* aliases;
* funções leves;
* jobs ergonomics;
* helpers operacionais;
* comandos de navegação;
* wrappers leves.

### 7.3 Filosofia de modularização

A modularização shell da Toolbox:

* não utiliza frameworks externos;
* não depende de zsh/fish;
* mantém compatibilidade Bash pura;
* preserva simplicidade operacional;
* deve ser auditável.

### 7.4 PATH idempotente

A Toolbox utiliza função como:

```bash
path_append()
```

para evitar duplicações no PATH durante:

```bash
source ~/.bashrc
```

ou:

```bash
reload
```

Objetivo:

```text
reloads múltiplos não devem duplicar PATH
```

### 7.5 Alias vs função vs script

#### Alias

Usado para substituição textual simples.

Exemplo:

```bash
alias mkx='chmod +x'
```

#### Função

Usada quando há:

* parâmetros;
* lógica;
* múltiplas etapas.

Exemplo:

```bash
bashcheck() {
    bash -n "$1"
    echo $?
}
```

#### Script Toolbox

Usado para:

* diagnósticos;
* pipelines;
* geração de relatórios;
* automações maiores;
* workflows reutilizáveis;
* operações auditáveis.

Local oficial:

```text
/srv/toolbox/app/scripts/
```

---

## 8. Baseline obrigatório de scripts shell

Scripts shell novos devem usar:

```bash
#!/usr/bin/env bash
set -u
```

O uso de `set -u` é obrigatório para reduzir erros causados por variáveis não definidas.

### 8.1 Sobre `set -euo pipefail`

A preferência histórica por:

```bash
set -euo pipefail
```

deve ser tratada com cautela.

`set -e` pode ser inadequado em scripts de diagnóstico, porque esses scripts precisam continuar mesmo quando itens opcionais não existem.

`set -o pipefail` pode ser útil em scripts específicos, mas não deve ser imposto como padrão universal sem análise.

Regra atual:

* padrão mínimo obrigatório: `set -u`;
* `set -e` e `pipefail`: permitidos quando fizerem sentido;
* scripts de diagnóstico devem ser tolerantes a ausências opcionais;
* scripts de apply podem ser mais estritos, desde que isso seja deliberado.

---

## 9. Funções padrão

Scripts novos devem usar funções padronizadas para logging e erro.

Forma mínima atual:

```bash
log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}
```

Com a criação de `scripts/lib`, essas funções devem migrar gradualmente para:

```text
scripts/lib/logging.sh
```

Durante a transição:

* scripts autocontidos continuam aceitáveis;
* scripts novos devem preferir `scripts/lib` quando o módulo já existir e estiver validado;
* scripts antigos não devem ser migrados em massa sem plano.

---

## 10. Importação de `scripts/lib`

Quando um script usar `scripts/lib`, a importação deve ser explícita.

Exemplo host-mode:

```bash
#!/usr/bin/env bash
set -u

source /srv/toolbox/app/scripts/lib/logging.sh
source /srv/toolbox/app/scripts/lib/tsv.sh
```

Exemplo container-mode:

```bash
#!/usr/bin/env bash
set -u

source /toolbox/app/scripts/lib/logging.sh
source /toolbox/app/scripts/lib/tsv.sh
```

A política final de paths deve ser centralizada em `scripts/lib/paths.sh`.

A adoção deve ser gradual.

Não migrar todos os scripts existentes apenas por estética.

---

## 11. Tipos de automação

A Toolbox reconhece os seguintes tipos de automação:

```text
atomic tool
run-job pipeline
operational workflow
admin diagnostic
archive campaign
support command
```

### 11.1 Atomic tool

Ferramenta pequena e especializada que executa uma operação principal.

Exemplos:

```text
ocr
pdf-text
pdf-images
img-convert
exif
audio-probe
flac-verify
cue-diagnose
metadata-extract
```

Características:

* input claro;
* output claro;
* comportamento previsível;
* possível composição com outras ferramentas;
* documentação em `man1` quando estável.

### 11.2 run-job pipeline

Pipeline encapsulado executado via `run-job`.

Exemplos:

```text
pdf-ocr
image-ocr-translate
audio-cue-split
artwork-convert
```

Características:

* input claro;
* output claro;
* diretório de job;
* status;
* log;
* workdir;
* baixa necessidade de decisão humana durante execução.

`run-job` continua válido, mas não é padrão universal da Toolbox.

### 11.3 Operational workflow

Workflow auditável por fases.

Fluxo padrão:

```text
diagnose → plan → apply → validate
```

Usar quando houver:

* risco;
* acervo vivo;
* biblioteca canônica;
* muitos arquivos;
* metadados complexos;
* necessidade de snapshot;
* necessidade de TSV de plano;
* necessidade de revisão humana;
* necessidade de validação independente;
* possibilidade de interrupção;
* necessidade de retomar;
* necessidade de repair;
* valor documental do processo.

### 11.4 Admin diagnostic

Script de diagnóstico administrativo do homelab.

Características:

* normalmente host-mode;
* não modifica nada;
* tolera ausência de itens opcionais;
* gera report humano;
* pode gerar TSV estruturado;
* registra paths e critérios;
* ajuda a planejar próximas ações.

Exemplos:

```text
diagnose-toolbox-host-container-tools.sh
diagnose-toolbox-output-policy-and-lib.sh
diagnose-toolbox-operations-docs-policy.sh
diagnose-toolbox-architecture-vs-practice.sh
```

### 11.5 Archive campaign

Conjunto de scripts e documentos voltados à curadoria de acervo.

Exemplos:

```text
Stockhausen-Verlag
Sun Ra futuro
Anthony Braxton futuro
outros acervos musicais
```

Campanhas arquivísticas devem preservar separação entre:

* normalização estrutural;
* enrichment musicológico;
* metadata confiável;
* metadata inferida;
* validação técnica;
* validação de player.

### 11.6 Support command

Comando auxiliar usado para facilitar a operação.

Exemplos:

```text
backup-toolbox-phase2-docs.sh
validate-toolbox-phase2-docs.sh
future validate-toolbox-doc-file.sh
future tbman
```

Comandos de suporte devem ser simples, previsíveis e seguros.

---

## 12. Relação entre workflow operacional e `run-job`

Um workflow operacional pode chamar `run-job` como subetapa.

Modelo:

```text
diagnose
  ↓
plan
  ↓
run-job para etapa encapsulada
  ↓
validate output do job
  ↓
apply no estado vivo
  ↓
validate estado vivo
```

Exemplo futuro:

```text
diagnose-album-staging.sh
plan-cue-split.sh
run-job audio-cue-split
validate-cue-split-output.sh
plan-import.sh
apply-import-to-library.sh
validate-library-import.sh
```

Nesse modelo:

* `run-job` processa uma unidade encapsulada;
* o workflow operacional decide, audita, aplica e valida;
* o acervo vivo só é alterado em fase controlada.

---

## 13. Convenções de naming

Nomes de scripts devem ser claros.

Padrões recomendados:

```text
diagnose-*.sh
plan-*.sh
apply-*.sh
validate-*.sh
repair-*.sh
resume-*.sh
build-*.sh
backup-*.sh
scan-*.sh
import-*.sh
purge-*.sh
```

Evitar nomes genéricos demais:

```text
script.sh
test.sh
new.sh
fix.sh
run.sh
```

Quando o script pertence a um domínio, o nome deve refletir o domínio.

Exemplos:

```text
diagnose-toolbox-host-container-tools.sh
validate-toolbox-phase2-docs.sh
plan-stockhausen-import-050.sh
apply-stockhausen-import-050.sh
validate-stockhausen-import-050.sh
```

---

## 14. Estrutura interna recomendada

Scripts operacionais devem seguir estrutura previsível.

Estrutura recomendada:

```text
shebang
set -u
constantes
funções utilitárias
funções de relatório/TSV
funções de diagnóstico/plano/apply/validate
main()
main "$@"
```

Exemplo:

```bash
main() {
  log "Starting operation"
  # ...
  log "Completed"
}

main "$@"
```

---

## 15. Confirmação APPLY

Scripts que fazem alterações reais devem exigir confirmação explícita quando houver risco.

Padrão:

```text
APPLY
```

Usar confirmação `APPLY` em scripts que:

* alteram documentos;
* movem arquivos;
* apagam arquivos;
* renomeiam arquivos;
* editam metadados;
* aplicam tags;
* alteram outputs existentes;
* alteram configuração;
* alteram runtime;
* afetam acervos vivos;
* podem afetar serviços.

Não exigir `APPLY` em scripts puramente diagnósticos.

---

## 16. Convenção de timestamp

Todos os outputs devem utilizar timestamp previsível.

Padrão:

```bash
STAMP="$(date +%Y%m%d-%H%M%S)"
```

Exemplo:

```text
report_20260523-132015.txt
```

Funções de timestamp devem migrar para `scripts/lib/timestamps.sh`.

---

## 17. Reports humanos

Scripts de diagnóstico, plano, apply e validação devem gerar report humano quando o resultado precisar ser revisado.

Reports humanos devem conter:

* timestamp;
* host;
* usuário;
* escopo;
* paths relevantes;
* ações executadas ou simuladas;
* achados;
* avisos;
* próximos passos;
* artefatos gerados.

A política final de destino de reports ainda está em consolidação.

Princípios atuais:

* `/srv/toolbox/shared/reports/media` não é destino universal;
* reports devem ser organizados por domínio quando a política final for aplicada;
* outputs legados não devem ser movidos sem plano próprio.

---

## 18. TSVs estruturados

Quando fizer sentido, scripts devem gerar TSV estruturado.

Usar TSV para:

* inventários;
* planos;
* validações;
* snapshots textuais;
* registros de apply;
* listas de arquivos;
* diagnósticos tabulares.

TSVs devem ter cabeçalho.

Funções como `tsv_escape()` devem migrar para:

```text
scripts/lib/tsv.sh
```

A política final de destino dos TSVs ainda está em consolidação.

Princípios atuais:

* `/srv/toolbox/shared/library-db/raw` não é destino universal de todo TSV;
* TSVs de acervo podem continuar usando `library-db/raw`;
* TSVs administrativos podem precisar de destino próprio no futuro.

---

## 19. Snapshots

Snapshots devem ser usados antes de alterações relevantes.

Usar snapshot antes de:

* apply em acervo vivo;
* edição em lote;
* normalização de metadata;
* rename em massa;
* purge;
* import;
* reorganização de outputs;
* alterações documentais relevantes;
* alterações de runtime.

Snapshots devem registrar, quando possível:

* path;
* existência;
* tamanho;
* hash;
* timestamp;
* estado anterior.

A política final de snapshots ainda deve distinguir snapshots de acervo, snapshots administrativos e snapshots documentais.

---

## 20. Logs live

Para execução longa, preferir log externo controlado pelo shell:

```bash
LOG="/srv/toolbox/shared/reports/media/nome_live_$(date +%Y%m%d-%H%M%S).log"
nf script.sh > "$LOG" 2>&1 &
tf "$LOG"
```

O destino acima ainda é provisório e herdado da prática recente.

A política final deve organizar logs live por domínio.

Scripts não devem usar `tee` interno por padrão.

`tee` interno é aceitável quando deliberado e documentado.

---

## 21. Long-running jobs

Scripts demorados devem:

* ser seguros para `nohup`;
* emitir logs progressivos;
* funcionar com `tail -f`;
* evitar output excessivamente verboso;
* emitir timestamps;
* não depender de input interativo inesperado;
* deixar claro se podem ser interrompidos;
* registrar artefatos gerados.

Padrão recomendado:

```bash
nf script.sh > log.txt 2>&1 &
```

---

## 22. Idempotência

Sempre que possível:

* reruns não devem quebrar;
* diretórios devem usar `mkdir -p` quando criação for esperada;
* builds devem detectar outputs já existentes;
* operações devem tolerar reexecução;
* scripts de apply devem saber diferenciar “já aplicado” de “erro real”.

Idempotência não deve ocultar falhas.

Quando algo for pulado porque já existe, o script deve registrar isso.

---

## 23. Política de dependências

Scripts devem validar dependências explicitamente quando a ausência da ferramenta impedir execução.

Exemplo:

```bash
command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg não encontrado."
```

A validação deve diferenciar:

* dependência obrigatória;
* dependência opcional;
* dependência apenas para uma subfunção;
* dependência esperada no host;
* dependência esperada no container.

A política de runtime deve orientar onde a dependência deve existir.

---

## 24. Política de paths

Scripts devem preferir:

* caminhos absolutos;
* variáveis explícitas;
* diretórios centralizados;
* paths compatíveis com runtime.

Evitar:

* dependência de cwd implícito;
* caminhos relativos frágeis;
* paths host dentro de container sem tradução;
* paths container dentro do host sem explicação.

Exemplos:

```text
/srv/toolbox/app
/srv/toolbox/shared
/toolbox/app
/toolbox/shared
```

A tradução host/container deve ser documentada quando necessária.

---

## 25. Segurança e não destruição

Scripts devem evitar alterações destrutivas sem:

* diagnóstico;
* plano;
* backup;
* snapshot;
* confirmação;
* validação.

Comandos sensíveis:

```text
rm
mv
find -delete
rsync --delete
metaflac --remove-all-tags
sed -i
chmod -R
chown -R
docker compose down
```

Quando usados, devem estar protegidos por escopo claro e validação.

---

## 26. Metadados e acervos

Scripts de mídia não devem inventar metadados.

Política geral:

* usar filesystem quando tags forem menos confiáveis;
* preservar o que for confiável;
* separar normalização estrutural de enrichment;
* registrar campos alterados;
* validar tags depois do apply;
* evitar perda de MusicBrainz IDs;
* tratar performer/enrichment como fase separada quando necessário.

Essa regra vem da prática Stockhausen e deve orientar futuros acervos.

---

## 27. Filosofia arquivística

A Toolbox adota separação entre:

* hot storage;
* cold storage;
* staging;
* curated;
* archival.

Exemplos:

* FLAC master;
* transcoding sob demanda;
* artwork frio;
* cover quente;
* snapshots imutáveis;
* cold archive;
* staging antes de import.

---

## 28. Observabilidade

Toda automação importante deve idealmente produzir:

* logs;
* reports;
* manifests;
* métricas básicas;
* TSVs;
* snapshots;
* outputs auditáveis.

Observabilidade deve ser simples antes de sofisticada.

Não exigir dashboard, TUI ou serviço web para validação básica.

---

## 29. Performance

Prioridades:

1. segurança;
2. previsibilidade;
3. auditabilidade;
4. correção;
5. depois performance.

Evitar otimizações prematuras.

Quando performance for importante, registrar:

* volume de arquivos;
* duração;
* gargalo;
* ferramenta usada;
* risco operacional;
* impacto em serviços existentes.

---

## 30. Documentação no próprio script

Scripts devem documentar:

* objetivo;
* escopo;
* paths;
* runtime;
* tipo de automação;
* outputs;
* riscos;
* pressupostos;
* se modificam ou não modificam arquivos;
* se exigem `APPLY`;
* quais artefatos geram.

Essa documentação pode estar em comentários no topo e no próprio relatório gerado.

---

## 31. bashcheck

Antes de executar ou versionar script shell:

```bash
bashcheck caminho/do/script.sh
```

`bashcheck` é parte da rotina operacional da Toolbox.

Um script só deve avançar para execução real depois de passar no `bashcheck`, salvo exceção consciente e registrada.

---

## 32. Git

Scripts novos devem ser versionados quando forem reutilizáveis ou documentarem metodologia importante.

Antes de commit:

* revisar `git status --short`;
* evitar `git add .`;
* revisar diff;
* não commitar outputs gerados;
* não commitar `.save`, `.bak`, `*~`;
* separar commits por tema.

A rotina detalhada está definida em:

```text
docs/operations/toolbox_git_routine.md
```

---

## 33. Manpages

Ferramentas estáveis e comandos recorrentes devem ganhar manpages.

Manpages devem declarar:

* runtime;
* tipo de automação;
* domínio;
* entradas;
* saídas;
* reports;
* logs;
* exemplos;
* segurança.

A política detalhada está definida em:

```text
docs/operations/toolbox_manpages_policy.md
```

---

## 34. Serviços existentes

Scripts da Toolbox não devem afetar serviços existentes sem plano explícito.

Serviços protegidos:

* Navidrome;
* Samba;
* FileBrowser;
* Nginx Proxy Manager;
* Backrest;
* Jellyfin;
* Immich;
* Calibre-Web;
* Kavita;
* slskd;
* monitoramento.

Scripts relacionados à Toolbox devem ser isolados desses serviços, salvo diagnóstico ou integração deliberada.

---

## 35. O que evitar

Evitar:

* scripts grandes demais sem necessidade;
* blocos complexos difíceis de revisar;
* heredocs gigantes com múltiplos documentos;
* lógica destrutiva sem confirmação;
* `git add .` sem revisão;
* `tee` interno por padrão;
* dependência prematura de `scripts/lib`;
* migração em massa sem validação;
* mover outputs antigos por estética;
* tratar container como runtime universal;
* tratar host como runtime universal;
* misturar documentação, Docker, scripts e outputs no mesmo commit.

---

## 36. Futuro

A Toolbox poderá evoluir para:

```text
toolbox-dev
```

como camada operacional de ergonomia shell/dev/admin.

Também poderá evoluir para:

```text
toolbox-base
toolbox-docs
toolbox-media
toolbox-nlp
```

como conjunto de perfis Docker especializados.

Essas frentes devem avançar incrementalmente, sem perder simplicidade e sem romper compatibilidade operacional.

---

## 37. Próximas frentes

Frentes imediatas relacionadas a scripts:

1. criar `scripts/lib` mínimo;
2. validar `scripts/lib`;
3. migrar scripts novos para `scripts/lib`;
4. criar validador genérico de documentos;
5. planejar acesso host às manpages;
6. planejar `toolbox-media`;
7. manter scripts antigos funcionando;
8. evitar migração em massa sem plano.
