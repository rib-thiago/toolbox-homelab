# Toolbox Output Destinations Policy

## 1. Objetivo

Este documento define a política de destino dos outputs e artefatos gerados pela Toolbox.

Ele consolida uma dívida técnica deixada pelas políticas anteriores de reports e logging: distinguir claramente onde devem ser salvos reports humanos, TSVs, snapshots, logs, inventories, manifests, briefs, artefatos temporários, outputs de `run-job` e outputs de pipelines.

Esta política deve ser lida junto com:

* `docs/operations/toolbox_reports_policy.md`
* `docs/operations/toolbox_logging_policy.md`
* `docs/operations/toolbox_storage_policy.md`
* `docs/operations/toolbox_script_conventions.md`
* `docs/operations/toolbox_scripts_lib_policy.md`
* `docs/operations/toolbox_git_routine.md`

## 2. Princípio central

A regra central é:

```text
/srv/toolbox/app
= método, código, documentação, políticas, runbooks e conhecimento versionado.

/srv/toolbox/shared
= evidência, outputs gerados, reports, TSVs, snapshots, logs, inventories e briefs.
```

O repositório `/srv/toolbox/app` não deve acumular outputs datados, logs de execução, reports gerados, TSVs brutos, snapshots ou inventories, salvo quando forem deliberadamente usados como documentação, fixture, exemplo ou dado de teste.

## 3. Relação com políticas existentes

A política anterior de reports já estabeleceu que:

* `reports/media` não é destino universal;
* `library-db/raw` não é destino universal;
* logs live não pertencem sempre a `reports/media`;
* snapshots de acervo e snapshots administrativos podem precisar de políticas distintas;
* scripts legados podem continuar usando destinos provisórios quando declaram isso explicitamente.

A política de logging já estabeleceu que:

* logs não substituem reports;
* reports não substituem TSVs;
* TSVs não substituem reports;
* logs live são operacionais e nem sempre canônicos;
* `tee` interno não deve ser o padrão;
* logs de `run-job` pertencem ao diretório estruturado do job;
* destinos de logs live devem ser organizados por domínio.

Este documento consolida a política de destino para resolver essas ambiguidades.

## 4. Classes de artefatos

A Toolbox reconhece as seguintes classes principais de artefatos gerados:

1. Reports humanos.
2. TSVs e dados estruturados.
3. Snapshots.
4. Logs live.
5. Logs internos de jobs.
6. Inventories.
7. Manifests.
8. Briefs para ChatGPT.
9. Outputs temporários.
10. Outputs finais de pipeline.
11. Artefatos de cold archive.
12. Artefatos legados ou provisórios.

Cada classe tem função e destino próprios.

## 5. Reports humanos

Reports humanos são documentos textuais destinados à leitura por operador.

Eles interpretam uma operação, diagnóstico, validação, plano ou auditoria.

Destino canônico:

```text
/srv/toolbox/shared/reports/<domain>/
```

Domínios recomendados:

```text
/srv/toolbox/shared/reports/system/
/srv/toolbox/shared/reports/docker/
/srv/toolbox/shared/reports/network/
/srv/toolbox/shared/reports/storage/
/srv/toolbox/shared/reports/backup/
/srv/toolbox/shared/reports/git/
/srv/toolbox/shared/reports/media/
/srv/toolbox/shared/reports/media/staging/
/srv/toolbox/shared/reports/media/stockhausen/
/srv/toolbox/shared/reports/docs/
/srv/toolbox/shared/reports/runtime/
/srv/toolbox/shared/reports/manpages/
/srv/toolbox/shared/reports/agent/
```

`reports/media` deve ser usado para mídia, música, acervos, metadados, artwork e curadoria. Não deve ser usado como destino universal para reports da Toolbox.

Reports administrativos devem usar domínio administrativo específico, como `system`, `docker`, `network`, `storage`, `backup` ou `git`.

## 6. TSVs e dados estruturados

TSVs são evidência estruturada.

Eles devem ser usados quando a operação gera linhas, checks, entidades, arquivos, álbuns, serviços, paths, dependências, validações ou status.

Destino canônico:

```text
/srv/toolbox/shared/library-db/raw/<domain>/
```

Domínios recomendados:

```text
/srv/toolbox/shared/library-db/raw/system/
/srv/toolbox/shared/library-db/raw/docker/
/srv/toolbox/shared/library-db/raw/network/
/srv/toolbox/shared/library-db/raw/storage/
/srv/toolbox/shared/library-db/raw/backup/
/srv/toolbox/shared/library-db/raw/git/
/srv/toolbox/shared/library-db/raw/media/
/srv/toolbox/shared/library-db/raw/media/staging/
/srv/toolbox/shared/library-db/raw/media/stockhausen/
/srv/toolbox/shared/library-db/raw/docs/
/srv/toolbox/shared/library-db/raw/runtime/
/srv/toolbox/shared/library-db/raw/manpages/
/srv/toolbox/shared/library-db/raw/agent/
```

`library-db/raw` foi historicamente usado de modo intensivo para acervos musicais, mas não deve ser interpretado como destino universal sem domínio.

TSVs administrativos, de Docker, rede, Git, documentação, runtime ou agentes devem usar subdiretórios por domínio.

## 7. Snapshots

Snapshots registram estado anterior, estado congelado ou evidência de comparação.

Eles devem ser usados antes de operações sensíveis, especialmente:

* escrita de metadados;
* renames em massa;
* movimentação de mídia;
* importação de acervos;
* purga de biblioteca quente;
* criação ou validação de cold archive;
* mudanças de configuração;
* alterações de backup;
* alterações de firewall ou rede;
* alterações estruturais na Toolbox.

Destino canônico:

```text
/srv/toolbox/shared/library-db/snapshots/<domain>/
```

Domínios recomendados:

```text
/srv/toolbox/shared/library-db/snapshots/system/
/srv/toolbox/shared/library-db/snapshots/docker/
/srv/toolbox/shared/library-db/snapshots/network/
/srv/toolbox/shared/library-db/snapshots/storage/
/srv/toolbox/shared/library-db/snapshots/backup/
/srv/toolbox/shared/library-db/snapshots/git/
/srv/toolbox/shared/library-db/snapshots/media/
/srv/toolbox/shared/library-db/snapshots/media/staging/
/srv/toolbox/shared/library-db/snapshots/media/stockhausen/
/srv/toolbox/shared/library-db/snapshots/docs/
/srv/toolbox/shared/library-db/snapshots/agent/
```

Snapshots devem ser nomeados com contexto e timestamp.

Snapshots devem ser referenciados em reports quando usados para validação, rollback ou auditoria.

## 8. Logs live

Logs live acompanham execução, especialmente comandos longos.

Eles servem para acompanhar progresso, preservar stdout/stderr e permitir análise de falha.

Destino canônico:

```text
/srv/toolbox/shared/logs/<domain>/
```

Domínios recomendados:

```text
/srv/toolbox/shared/logs/system/
/srv/toolbox/shared/logs/docker/
/srv/toolbox/shared/logs/network/
/srv/toolbox/shared/logs/storage/
/srv/toolbox/shared/logs/backup/
/srv/toolbox/shared/logs/git/
/srv/toolbox/shared/logs/media/
/srv/toolbox/shared/logs/media/staging/
/srv/toolbox/shared/logs/media/stockhausen/
/srv/toolbox/shared/logs/docs/
/srv/toolbox/shared/logs/runtime/
/srv/toolbox/shared/logs/manpages/
/srv/toolbox/shared/logs/agent/
```

Logs live não devem ser salvos automaticamente em `reports/`.

Reports interpretam a execução.

Logs registram a execução.

Quando houver report final, o report final tem precedência interpretativa sobre o log live.

## 9. Logs internos de `run-job`

Pipelines `run-job` podem ter logs internos no diretório estruturado do job.

Destino típico:

```text
/toolbox/jobs/<job-id>/log.txt
```

ou, conforme o runtime configurado:

```text
/srv/toolbox/jobs/<job-id>/log.txt
```

Esses logs fazem parte da unidade de job.

Eles não substituem reports finais quando o workflow exige interpretação, validação ou handoff humano.

A política de logs internos de `run-job` convive com a política de logs externos para workflows host-mode.

## 10. Inventories

Inventories descrevem estado observado em um momento específico.

Eles não são decisões arquiteturais.

Eles devem ser tratados como evidência datada.

Destino canônico:

```text
/srv/toolbox/shared/inventory/<domain>/
```

Domínios recomendados:

```text
/srv/toolbox/shared/inventory/homelab/
/srv/toolbox/shared/inventory/system/
/srv/toolbox/shared/inventory/docker/
/srv/toolbox/shared/inventory/network/
/srv/toolbox/shared/inventory/storage/
/srv/toolbox/shared/inventory/backup/
/srv/toolbox/shared/inventory/media/
/srv/toolbox/shared/inventory/toolbox/
/srv/toolbox/shared/inventory/agent/
```

Inventories podem alimentar `knowledge/graph/`, `knowledge/services/` ou `knowledge/architecture/`, mas não devem ser confundidos com eles.

Quando uma decisão estável é derivada de um inventory, a decisão deve ser registrada em `knowledge/architecture/` ou `knowledge/policies/`, mantendo o inventory como evidência.

## 11. Manifests

Manifests registram conjuntos de arquivos, pacotes, outputs ou artefatos.

Eles podem ser usados para:

* cold archives;
* pacotes `.7z`;
* conjuntos de artwork;
* conjuntos de mídia;
* outputs de pipeline;
* entregáveis de job;
* validações de integridade.

Destino canônico:

```text
/srv/toolbox/shared/manifests/<domain>/
```

Domínios recomendados:

```text
/srv/toolbox/shared/manifests/media/
/srv/toolbox/shared/manifests/media/stockhausen/
/srv/toolbox/shared/manifests/archive/
/srv/toolbox/shared/manifests/jobs/
/srv/toolbox/shared/manifests/agent/
```

Quando o manifest for parte inseparável de um job, ele pode viver no diretório do job.

Quando o manifest for parte de um cold archive, ele deve ser armazenado junto do pacote ou referenciado no report de validação.

## 12. Briefs para ChatGPT

Briefs para ChatGPT são artefatos de handoff.

Eles existem para reduzir copy-paste bruto, upload recorrente de arquivos e dumps longos de terminal.

Destino canônico:

```text
/srv/toolbox/shared/briefs/chatgpt/
```

Briefs devem incluir, quando aplicável:

* tarefa;
* contexto lido;
* arquivos inspecionados;
* comandos executados;
* reports gerados;
* TSVs gerados;
* achados relevantes;
* warnings;
* failures;
* decisões pendentes;
* próximo passo proposto;
* paths para evidência completa.

Briefs não substituem reports e TSVs.

Briefs resumem evidência para revisão estratégica.

## 13. Outputs temporários

Outputs temporários devem ficar fora de `/srv/toolbox/app`.

Destinos aceitáveis:

```text
/srv/toolbox/shared/tmp/<domain>/
/srv/toolbox/shared/work/<domain>/
/tmp/
```

A escolha depende do risco e da necessidade de auditoria.

`/tmp` é aceitável para dados realmente descartáveis.

`/srv/toolbox/shared/tmp/` é preferível quando o output temporário pode ser útil para diagnóstico posterior.

`/srv/toolbox/shared/work/` é preferível para workdirs de processamento não encapsulados por `run-job`.

Outputs temporários devem ter cleanup explícito quando ocuparem espaço relevante.

## 14. Outputs finais de pipeline

Outputs finais de pipeline devem ir para destino explícito e documentado.

Possíveis destinos:

```text
/srv/toolbox/shared/outputs/<domain>/
/srv/toolbox/shared/exports/<domain>/
/srv/toolbox/shared/archive/<domain>/
```

A escolha depende da natureza do output:

* `outputs/` para resultados processados genéricos;
* `exports/` para material gerado para consumo externo;
* `archive/` para material preservado;
* diretório do job quando o output pertence a uma execução específica.

Pipelines não devem despejar outputs finais em diretórios genéricos sem contexto.

## 15. Cold archives

Cold archives preservam material pesado, auxiliar, intermediário ou não adequado à biblioteca quente.

Destino canônico geral:

```text
/srv/toolbox/shared/artwork-cold-archive/<collection>/
```

ou, para arquivos não relacionados a artwork:

```text
/srv/toolbox/shared/cold-archive/<domain>/<collection>/
```

Cold archives devem ter:

* plano;
* manifest quando aplicável;
* report;
* validação;
* política de limpeza da origem;
* rastreabilidade.

Nenhuma purga de biblioteca quente deve ocorrer apenas porque um cold archive existe.

A validação do cold archive deve preceder a limpeza.

## 16. Agent artifacts

Artefatos gerados por agentes devem ter domínio explícito.

Destinos recomendados:

```text
/srv/toolbox/shared/reports/agent/
/srv/toolbox/shared/library-db/raw/agent/
/srv/toolbox/shared/logs/agent/
/srv/toolbox/shared/inventory/agent/
/srv/toolbox/shared/briefs/chatgpt/
```

Quando o agente trabalha em um domínio específico, o domínio específico pode ser preferível:

```text
/srv/toolbox/shared/reports/system/
/srv/toolbox/shared/reports/media/staging/
/srv/toolbox/shared/library-db/raw/git/
```

A regra é: artefato de agente não precisa ficar em `agent/` se pertence claramente a outro domínio.

O domínio deve refletir a finalidade do artefato, não apenas a ferramenta que o gerou.

## 17. Legacy and provisional destinations

Destinos legados ou provisórios podem continuar existindo durante transição.

Exemplos históricos:

```text
/srv/toolbox/shared/reports/media
/srv/toolbox/shared/library-db/raw
/srv/toolbox/shared/library-db/snapshots
```

Eles não devem ser interpretados como destino universal.

Scripts legados podem continuar usando esses destinos até serem revisados.

Scripts novos devem preferir destinos por domínio.

Quando um script novo usar destino provisório, deve declarar isso no report.

## 18. Naming policy

Artefatos gerados devem ter nomes previsíveis.

Nomes devem incluir:

* domínio;
* tarefa;
* tipo de artefato;
* timestamp.

Exemplos:

```text
toolbox_knowledge_context_validation_20260602-113415.txt
toolbox_knowledge_context_validation_20260602-113415.tsv
toolbox_git_stage_check_commit_report_20260602-113400.txt
music_staging_tagging_audit_report_20260531-224700.txt
stockhausen_artwork_cold_archive_manifest_20260524-000000.tsv
```

Evitar nomes como:

```text
output.txt
report.txt
log.txt
temp.tsv
notes.md
result.txt
```

## 19. Timestamp policy

Artefatos gerados devem usar timestamp para evitar sobrescrita acidental.

O formato deve seguir a convenção já usada pela Toolbox sempre que possível.

Formato típico:

```text
YYYYMMDD-HHMMSS
```

O timestamp deve aparecer no nome do arquivo quando o artefato for datado.

## 20. Report/TSV correlation

Quando uma operação gera report e TSV, ambos devem ter correlação clara.

Preferencialmente:

* mesmo timestamp;
* mesmo prefixo de domínio/tarefa;
* report apontando para TSV;
* TSV com linhas estruturadas.

Exemplo:

```text
toolbox_knowledge_context_validation_20260602-113415.txt
toolbox_knowledge_context_validation_20260602-113415.tsv
```

## 21. Git policy for generated artifacts

Artefatos gerados não devem ser commitados por padrão.

Normalmente não entram no Git:

* reports gerados;
* TSVs brutos;
* logs;
* snapshots;
* inventories;
* briefs;
* outputs temporários;
* outputs de job.

Podem entrar no Git quando forem deliberadamente:

* documentação;
* template;
* fixture;
* exemplo;
* política;
* runbook;
* spec;
* teste.

A razão deve ser explícita.

## 22. Cleanup and retention

Nem todo output precisa ser preservado indefinidamente.

Critérios de retenção podem variar por tipo:

* reports importantes devem ser preservados;
* TSVs de auditoria devem ser preservados;
* snapshots críticos devem ser preservados;
* logs live podem ter retenção menor;
* tmp/work pode ser limpo;
* cold archives devem ter política própria;
* outputs de job podem seguir política de job.

Esta política define destinos, não resolve sozinha retenção final.

Retenção detalhada deve ser tratada por política própria ou por seção específica nos runbooks de domínio.

## 23. Migration policy

Scripts existentes não precisam ser migrados imediatamente.

A migração deve ser gradual.

Prioridade de migração:

1. Scripts novos.
2. Scripts em manutenção ativa.
3. Scripts usados por agentes.
4. Scripts com reports/TSVs ambíguos.
5. Scripts legados de baixo uso.

Ao revisar scripts legados, preferir ajustar destinos para esta política.

## 24. Anti-drift rule

Novos destinos não devem ser criados por conveniência momentânea.

Todo novo destino deve explicar:

* função;
* tipo de artefato;
* domínio;
* relação com destinos existentes;
* risco de redundância;
* regra de retenção ou cleanup;
* impacto em scripts existentes;
* impacto em agentes.

A política de destinos deve reduzir ambiguidade, não criar mais uma camada paralela.

## 25. Filosofia final

Outputs são parte da arquitetura operacional da Toolbox.

Reports, TSVs, logs, snapshots, inventories, manifests e briefs são a memória operacional do sistema.

A Toolbox deve produzir evidência suficiente para que humanos, ChatGPT, Codex e futuros agentes consigam entender o que foi feito, por que foi feito, onde está registrado e como validar ou reverter quando necessário.
