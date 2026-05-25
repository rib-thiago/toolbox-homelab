# Toolbox Git Routine

## 1. Objetivo

Este documento define a rotina Git operacional da Toolbox.

A Toolbox passou a conter scripts, documentação, políticas, diagnósticos, relatórios, planos, validações e artefatos de evolução rápida. O uso de Git precisa ser disciplinado para preservar rastreabilidade, evitar commits acidentais e separar claramente código, documentação e outputs gerados.

Esta rotina não substitui o fluxo Git geral do homelab ou de outros projetos. Ela se aplica especificamente ao repositório da Toolbox em:

`/srv/toolbox/app`

## 2. Princípios

A rotina Git da Toolbox segue estes princípios:

* nunca commitar às cegas;
* nunca usar `git add .` em frentes grandes sem revisar o estado;
* separar commits por tema;
* validar scripts antes de versionar;
* não commitar outputs gerados por padrão;
* não commitar backups de editor;
* preservar histórico de decisões;
* registrar documentação junto das mudanças estruturais;
* manter a relação entre diagnóstico, plano, aplicação e validação.

Fluxo conceitual:

diagnose → plan → apply → validate

No contexto Git:

1. diagnosticar o estado do repositório;
2. planejar agrupamento dos arquivos;
3. adicionar arquivos por grupo;
4. validar diff;
5. commitar por tema.

## 3. Antes de qualquer mudança

Antes de iniciar uma frente de alteração na Toolbox, verificar o estado do repositório:

```bash
cd /srv/toolbox/app || exit 1
git status --short
```

Quando necessário, verificar também:

```bash
git status
git branch --show-current
git log --oneline -5
```

Se houver mudanças pendentes, elas devem ser entendidas antes de iniciar nova frente.

## 4. Antes de editar arquivos

Antes de editar arquivos importantes, especialmente documentos e scripts, verificar:

```bash
cd /srv/toolbox/app || exit 1
git status --short
```

Se o arquivo já estiver modificado, decidir se:

* a mudança atual pertence à mesma frente;
* a mudança deve ser preservada;
* é necessário fazer backup;
* é melhor adiar a nova alteração;
* é necessário revisar diff antes.

## 5. Depois de editar arquivos

Depois de editar arquivos, verificar:

```bash
cd /srv/toolbox/app || exit 1
git status --short
```

Para revisar conteúdo alterado:

```bash
git diff -- caminho/do/arquivo
```

Para revisar todos os diffs pendentes:

```bash
git diff
```

Para arquivos novos, usar:

```bash
git status --short
ls -la caminho/do/arquivo
```

## 6. Validação de scripts shell

Antes de versionar scripts shell, rodar:

```bash
bashcheck caminho/do/script.sh
```

Quando o script for executável, validar também:

```bash
ls -la caminho/do/script.sh
```

Quando apropriado:

```bash
caminho/do/script.sh
```

ou, para execução longa:

```bash
LOG="/srv/toolbox/shared/reports/media/nome_live_$(date +%Y%m%d-%H%M%S).log"
nf caminho/do/script.sh > "$LOG" 2>&1 &
tf "$LOG"
```

A execução longa com `nf/nohup` deve preservar log externo. O uso de `tee` interno não deve ser o padrão, salvo quando deliberado.

## 7. Validação de documentos

Antes de versionar documentos Markdown, verificar pelo menos:

```bash
ls -la caminho/do/documento.md
wc -l caminho/do/documento.md
sed -n '1,40p' caminho/do/documento.md
```

Quando o documento tiver termos centrais, validar com `grep`.

Exemplo:

```bash
grep -n "host-mode" docs/operations/toolbox_runtime_profiles.md
grep -n "container-mode" docs/operations/toolbox_runtime_profiles.md
grep -n "diagnose → plan → apply → validate" docs/operations/toolbox_runtime_profiles.md
```

## 8. Arquivos não versionados

Arquivos untracked devem ser classificados antes de qualquer commit.

Categorias comuns:

```text
docs
scripts admin
scripts media
scripts diagnostics
scripts Stockhausen
Docker/Compose
manpages
temporários
backups de editor
outputs gerados
snapshots
logs
TSVs
```

Não usar:

```bash
git add .
```

sem revisar cuidadosamente a lista de untracked.

Preferir:

```bash
git status --short
git add caminho/especifico
```

## 9. Backups de editor

Não commitar backups de editor.

Padrões a evitar:

```text
*.save
*.save.*
*.bak
*~
.#*
```

Se esses arquivos aparecerem em `git status --short`, eles devem ser tratados antes do commit.

Exemplo de arquivos que não devem ser commitados:

```text
scripts/admin/system/script.sh.save
scripts/admin/system/script.sh.save.1
documento.md~
documento.md.bak
```

A decisão entre apagar ou adicionar ao `.gitignore` deve ser tomada em frente própria.

## 10. Outputs gerados

Não commitar por padrão:

```text
reports
logs live
TSVs gerados
snapshots
job outputs
temporary diagnostics
artefatos de execução
outputs de validação
```

A Toolbox gera muitos artefatos em:

```text
/srv/toolbox/shared/reports
/srv/toolbox/shared/library-db/raw
/srv/toolbox/shared/library-db/snapshots
/srv/toolbox/jobs
```

Esses diretórios são, por padrão, áreas de output operacional, não código-fonte.

Exceções devem ser deliberadas e documentadas.

## 11. O que deve ser versionado

Devem ser versionados, quando aprovados:

```text
scripts
docs
políticas
manpages
Dockerfiles
compose files
wrappers em bin/
configs versionáveis
templates
playbooks
```

A documentação que registra decisões arquiteturais e operacionais deve ser versionada junto da evolução da Toolbox.

## 12. Commits por tema

Preferir commits pequenos e temáticos.

Exemplos de escopo:

```text
docs:
scripts/admin:
scripts/media:
docker:
man:
ops:
toolbox:
```

Exemplos de mensagens:

```text
docs: add toolbox architecture reconciliation
docs: define toolbox runtime profiles
docs: add toolbox manpages policy
docs: add toolbox scripts lib policy
ops: add toolbox Git routine
scripts/admin: add toolbox documentation backup script
scripts/media: add Stockhausen validation helper
docker: add toolbox media profile
man: add toolbox runtime manpage
```

## 13. Ordem recomendada em frentes grandes

Em frentes grandes, usar esta ordem:

1. diagnosticar estado Git;
2. listar arquivos novos/modificados;
3. separar por tema;
4. validar scripts;
5. revisar documentos;
6. revisar diff;
7. adicionar arquivos por grupo;
8. validar `git diff --cached`;
9. commitar;
10. verificar estado final.

Comandos típicos:

```bash
cd /srv/toolbox/app || exit 1
git status --short
git diff
```

Adicionar por grupo:

```bash
git add docs/operations/toolbox_architecture_reconciliation.md
git add docs/operations/toolbox_scripts_lib_policy.md
```

Validar staged:

```bash
git diff --cached
git status --short
```

Commit:

```bash
git commit -m "docs: add toolbox phase 2 architecture policies"
```

## 14. Separação entre documentação e implementação

Quando possível, separar:

1. commit documental;
2. commit de script;
3. commit de Docker;
4. commit de manpages;
5. commit de reorganização;
6. commit de limpeza.

Exemplo:

```text
Commit 1: docs da arquitetura e política
Commit 2: scripts/lib mínimo
Commit 3: manpages host access
Commit 4: Docker profiles
Commit 5: cleanup Git/untracked
```

Essa separação facilita revisão, rollback e auditoria.

## 15. Scripts de diagnóstico

Scripts de diagnóstico devem ser tratados como artefatos versionáveis quando:

* forem reutilizáveis;
* documentarem metodologia;
* seguirem padrões da Toolbox;
* gerarem reports/TSVs;
* forem relevantes para futuras auditorias.

Antes de versionar:

```bash
bashcheck script.sh
script.sh
```

ou, se for execução longa:

```bash
LOG="..."
nf script.sh > "$LOG" 2>&1 &
tf "$LOG"
```

Validar os artefatos gerados, mas não commitá-los por padrão.

## 16. Scripts de apply

Scripts de apply são mais sensíveis.

Antes de versionar ou executar scripts de apply, verificar:

* se há backup;
* se há snapshot;
* se há confirmação explícita quando necessário;
* se há validação;
* se o escopo está claro;
* se não há comandos destrutivos sem proteção.

Scripts de apply que alteram arquivos reais devem preferir confirmação explícita, como:

```text
APPLY
```

O padrão `APPLY` deve ser usado quando o script faz alterações reais e não apenas diagnóstico.

## 17. Confirmação APPLY

Usar confirmação `APPLY` em scripts que:

* alteram documentos;
* movem arquivos;
* apagam arquivos;
* renomeiam arquivos;
* aplicam tags;
* editam metadata;
* alteram configuração;
* modificam runtime;
* alteram outputs existentes;
* podem afetar acervo vivo.

Não exigir `APPLY` em scripts puramente diagnósticos.

## 18. Git e outputs provisórios

Enquanto a política de outputs estiver em consolidação, lembrar:

* `reports/media` não é destino universal;
* `library-db/raw` não é destino universal;
* logs live não pertencem sempre a `reports/media`;
* outputs antigos são legado;
* reorganização de outputs exige plano próprio.

Esses artefatos não devem entrar no Git sem decisão explícita.

## 19. Git e scripts/lib

`scripts/lib` será criado como base comum mínima.

Mudanças em `scripts/lib` devem ser versionadas com cuidado porque podem afetar múltiplos scripts.

Antes de commitar `scripts/lib`:

```bash
bashcheck scripts/lib/*.sh
```

Depois de migrar scripts para `scripts/lib`, validar scripts migrados individualmente.

Não migrar scripts em massa no mesmo commit em que a lib é criada, salvo plano específico.

## 20. Git e manpages

Manpages devem ser versionadas.

Antes de commitar manpages:

```bash
groff -man -Tutf8 docs/man1/<page>.1 >/tmp/<page>.txt
groff -man -Tutf8 docs/man7/<page>.7 >/tmp/<page>.txt
```

Quando `MANPATH` ou `tbman` estiverem configurados:

```bash
tbman <page>
```

A configuração de acesso às manpages deve ser commitada separadamente da criação dos documentos, quando possível.

## 21. Git e Docker profiles

Perfis Docker devem ser versionados com cautela.

Antes de commitar Dockerfiles ou Compose:

* revisar impacto em serviços existentes;
* garantir que Navidrome e serviços do homelab não serão afetados;
* validar build;
* validar containers;
* validar mounts;
* validar manpages;
* validar `run-job`;
* validar que `toolbox-media` opera em staging/cópia.

Não misturar Docker profile com limpeza de outputs ou migração de scripts no mesmo commit.

## 22. Git e documentos históricos

Documentos históricos da Toolbox não devem ser apagados apenas porque a prática mudou.

Preferir:

* preservar;
* adicionar nota histórica;
* criar documentos novos de reconciliação;
* atualizar com cautela;
* evitar reescrita destrutiva.

A arquitetura original é fonte histórica e conceitual.

A prática emergente complementa e corrige a arquitetura original, mas não apaga sua importância.

## 23. Checklist antes de commit

Antes de commit:

```text
git status --short revisado
arquivos agrupados por tema
diff revisado
scripts validados com bashcheck
documentos revisados
sem .save/.bak/*~
sem outputs gerados acidentais
sem logs live acidentais
sem snapshots acidentais
commit tem escopo único
mensagem de commit clara
```

## 24. Checklist depois de commit

Depois de commit:

```bash
git status --short
git log --oneline -3
```

Verificar se o working tree ficou no estado esperado.

## 25. O que não fazer

Não fazer:

```bash
git add .
```

em árvore grande sem revisão.

Não commitar:

* `.save`;
* `.bak`;
* `*~`;
* logs live;
* reports gerados;
* snapshots;
* job outputs;
* artefatos temporários;
* arquivos grandes sem decisão;
* dumps acidentais.

Não misturar no mesmo commit:

* documentação;
* Docker;
* scripts;
* outputs;
* reorganização;
* limpeza;
* import de acervo.

## 26. Rotina mínima

Rotina mínima para frentes pequenas:

```bash
cd /srv/toolbox/app || exit 1
git status --short
# editar arquivos
git diff
# validar
git add caminho/especifico
git diff --cached
git commit -m "escopo: mensagem"
git status --short
```

## 27. Rotina para frentes Toolbox/Stockhausen

Para frentes arquivísticas ou de alto risco:

```text
diagnose Git state
diagnose data state
plan changes
backup/snapshot
apply
validate artifacts
validate Git diff
commit scripts/docs only
leave generated outputs out of Git unless explicitly approved
```

## 28. Estado atual esperado nesta fase

Durante a Fase 2 documental, é esperado que apareçam arquivos novos em:

```text
docs/operations/
```

E scripts novos em:

```text
scripts/admin/system/
```

Esses arquivos devem permanecer untracked até a fase de commit planejado.

O commit ainda não deve ser feito automaticamente.

## 29. Relação com backup

Backup operacional e Git são coisas diferentes.

Git versiona:

* scripts;
* docs;
* políticas;
* Dockerfiles;
* manpages;
* configs versionáveis.

Backup preserva:

* dados operacionais;
* snapshots;
* reports;
* outputs;
* estados de execução;
* arquivos fora do Git.

Não usar Git como substituto de backup.

## 30. Próximas frentes

Frentes futuras relacionadas à rotina Git:

1. classificar untracked atuais;
2. decidir `.gitignore` para backups de editor;
3. separar commits documentais;
4. separar commits dos scripts de diagnóstico;
5. separar commits Stockhausen;
6. versionar `scripts/lib` quando criado;
7. versionar manpages novas;
8. versionar perfis Docker quando implementados.
