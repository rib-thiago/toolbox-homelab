# Toolbox Reports Policy

## 1. Objetivo

Este documento define a política da Toolbox para:

* relatórios humanos;
* outputs estruturados;
* TSVs;
* snapshots;
* manifests;
* datasets intermediários;
* logs operacionais;
* logs live;
* evidências de diagnóstico, plano, aplicação e validação.

A Toolbox utiliza relatórios e outputs estruturados como parte central da auditabilidade operacional.

Relatórios não são considerados artefatos secundários.

Eles fazem parte da arquitetura operacional da Toolbox.

Este documento deve ser lido em conjunto com:

* `docs/operations/toolbox_architecture_reconciliation.md`;
* `docs/operations/toolbox_script_conventions.md`;
* `docs/operations/toolbox_logging_policy.md`;
* `docs/operations/toolbox_runtime_profiles.md`;
* `docs/operations/toolbox_git_routine.md`;
* `docs/operations/toolbox_scripts_lib_policy.md`.

## 2. Filosofia

Toda operação relevante deve idealmente produzir:

* evidência;
* rastreabilidade;
* outputs auditáveis;
* manifests;
* métricas;
* contexto operacional;
* indicação dos artefatos gerados;
* indicação clara de escopo;
* indicação clara do que foi ou não foi modificado.

A Toolbox prefere:

```text
operações auditáveis
```

em vez de:

```text
automação opaca
```

Reports, TSVs, snapshots e logs não existem apenas para depuração imediata. Eles registram a memória operacional da Toolbox.

## 3. Estado atual da política

A política de outputs da Toolbox está em transição.

Durante a saga Stockhausen e os diagnósticos posteriores, alguns diretórios foram usados de forma intensiva e provisória, especialmente:

```text
/srv/toolbox/shared/reports/media
/srv/toolbox/shared/library-db/raw
/srv/toolbox/shared/library-db/snapshots
```

Esses caminhos continuam válidos como legado e como prática recente, mas não devem ser interpretados como política universal definitiva.

Princípios já consolidados:

* `reports/media` não é destino universal de todo relatório humano;
* `library-db/raw` não é destino universal de todo TSV;
* logs live não pertencem sempre a `reports/media`;
* snapshots de acervo e snapshots administrativos podem precisar de políticas distintas;
* outputs antigos não devem ser movidos apenas por estética;
* qualquer reorganização de outputs deve seguir `diagnose → plan → apply → validate`.

## 4. Categorias de output

A Toolbox reconhece as seguintes categorias de output:

```text
human report
structured TSV
manifest
plan
apply record
validation record
snapshot
freeze
live log
job output
cold archive manifest
diagnostic artifact
```

Cada categoria deve ter finalidade clara.

## 5. Reports humanos

Reports humanos são documentos textuais voltados à leitura por operador.

Eles devem ser:

* textuais;
* legíveis;
* timestampados;
* compatíveis com `cat`;
* compatíveis com `less`;
* compatíveis com `grep`;
* compatíveis com `tail`;
* claros quanto ao escopo;
* claros quanto aos caminhos analisados;
* claros quanto aos artefatos produzidos.

Extensão preferencial:

```text
.txt
```

Reports humanos devem priorizar legibilidade terminal.

Evitar:

* formatos binários;
* dependência de GUI;
* outputs excessivamente decorativos;
* cores obrigatórias;
* símbolos que dificultem parsing.

## 6. Estrutura recomendada para reports humanos

Estrutura recomendada:

```text
Title
Generated at
Host
User
Scope
Inputs
Outputs
Summary
Details
Warnings
Errors
Validation
Next steps
Generated artifacts
```

Nem todo report precisa ter todas as seções, mas scripts importantes devem registrar pelo menos:

* título;
* timestamp;
* escopo;
* diretórios relevantes;
* resumo;
* achados;
* artefatos gerados.

## 7. Reports por domínio

Reports devem ser organizados por domínio quando a política final for aplicada.

Domínios possíveis:

```text
reports/system
reports/docker
reports/network
reports/storage
reports/backup
reports/git
reports/media
reports/media/stockhausen
reports/docs
reports/runtime
reports/manpages
```

O diretório `reports/media` deve ser usado para reports de mídia, música, acervos, metadados, artwork e curadoria.

Ele não deve ser usado como destino universal para todos os reports da Toolbox.

## 8. Reports administrativos

Reports administrativos devem pertencer ao domínio correspondente.

Exemplos:

```text
reports/system
reports/docker
reports/network
reports/storage
reports/backup
reports/git
```

A política final ainda deve decidir os caminhos exatos.

Enquanto essa decisão não for aplicada, scripts podem continuar usando destinos provisórios, desde que declarem isso explicitamente no report.

## 9. Reports de mídia

Reports de mídia incluem:

* inventários musicais;
* diagnósticos de metadata;
* validações de acervo;
* diagnósticos de artwork;
* importações;
* cold archives;
* reports Stockhausen;
* futuros reports Sun Ra;
* futuros reports Anthony Braxton;
* reports de outros acervos.

Destino histórico/provisório usado:

```text
/srv/toolbox/shared/reports/media
```

Destino futuro possível:

```text
/srv/toolbox/shared/reports/media/<collection>
```

Exemplo:

```text
/srv/toolbox/shared/reports/media/stockhausen
```

Essa reorganização não deve ser feita retroativamente sem plano.

## 10. Dados estruturados

Dados estruturados são outputs voltados a parsing, comparação, validação ou automação.

Formato preferencial:

```text
.tsv
```

Usos:

* inventários;
* manifests;
* planos;
* validações;
* registros de apply;
* snapshots textuais;
* datasets intermediários;
* listas de arquivos;
* diagnósticos tabulares.

TSVs devem ser legíveis por:

* `awk`;
* `cut`;
* `sort`;
* `grep`;
* Python;
* SQLite import;
* scripts shell.

## 11. Política de TSV

TSVs devem:

* possuir header obrigatório;
* usar TAB real;
* evitar delimitadores ambíguos;
* preservar caminhos absolutos quando necessário;
* escapar quebras de linha quando necessário;
* evitar colunas sem nome;
* ser parseáveis por ferramentas Unix;
* ter finalidade clara.

Funções como `tsv_escape()` devem migrar para:

```text
scripts/lib/tsv.sh
```

## 12. `library-db/raw`

O caminho:

```text
/srv/toolbox/shared/library-db/raw
```

foi usado intensivamente para TSVs de acervo, especialmente durante a saga Stockhausen.

Ele continua adequado para:

* inventários de biblioteca;
* dados brutos de acervos;
* TSVs de música;
* planos e validações diretamente ligados à biblioteca de mídia;
* manifests relacionados a acervos.

Mas não deve ser interpretado como destino universal de todo TSV da Toolbox.

TSVs administrativos, de Docker, Git, rede, manpages ou documentação podem exigir destinos próprios no futuro.

## 13. Snapshots

Snapshots são registros do estado anterior ou de um estado congelado.

Destino histórico/provisório:

```text
/srv/toolbox/shared/library-db/snapshots
```

Snapshots devem ser:

* timestampados;
* preferencialmente imutáveis;
* nunca sobrescritos;
* auditáveis;
* associados a uma operação;
* referenciados em reports.

Snapshots devem ser usados antes de:

* apply em acervo vivo;
* edição em lote;
* normalização de metadata;
* rename em massa;
* purge;
* import;
* reorganização de outputs;
* alterações documentais relevantes;
* alterações de runtime;
* mudanças estruturais na Toolbox.

## 14. Freeze

Um freeze é um snapshot de maior significado operacional.

Usar freeze quando o estado registrado representa marco relevante, por exemplo:

* fim de normalização de acervo;
* estado validado de biblioteca;
* fechamento de fase;
* baseline antes de mudança grande;
* estado canônico antes de import.

Um freeze deve ter:

* report associado;
* TSV ou manifest associado;
* timestamp;
* escopo claro;
* critérios de validação.

## 15. Manifests

Manifests registram conjuntos de arquivos, outputs ou artefatos.

Manifests devem incluir, quando aplicável:

* path;
* tamanho;
* hash;
* tipo;
* origem;
* destino;
* status;
* observações.

Manifests são recomendados para:

* cold archives;
* imports;
* backups;
* validações;
* outputs de jobs;
* migrações;
* reorganizações.

## 16. Logs operacionais

Logs operacionais registram execução.

Eles podem ser:

* logs live;
* logs internos de job;
* logs temporários;
* logs de erro;
* logs de build;
* logs de validação.

Logs não substituem reports finais.

Logs mostram a execução.

Reports interpretam a execução.

## 17. Logs live

Logs live são usados para execução longa, geralmente via `nf/nohup`.

Padrão operacional:

```bash
LOG="/path/to/live_<timestamp>.log"
nf script.sh > "$LOG" 2>&1 &
tf "$LOG"
```

Logs live devem:

* ser timestampados;
* indicar o script executado;
* ser compatíveis com `tail -f`;
* registrar erros;
* permitir acompanhamento incremental.

Logs live são operacionais e nem sempre canônicos.

O destino de logs live ainda precisa ser organizado por domínio.

Eles não devem ser assumidos como pertencentes sempre a `reports/media`.

## 18. Logs internos de `run-job`

Pipelines `run-job` podem ter logs internos em seu diretório de job.

Exemplo conceitual:

```text
/toolbox/jobs/<job-id>/log.txt
```

Esses logs fazem parte do job.

A política de logs de `run-job` deve conviver com a política de logs externos de workflows host-mode.

## 19. Reports finais

Relatórios finais são os artefatos humanos oficiais de uma operação.

Eles devem registrar:

* o que foi feito;
* quando;
* por qual script;
* sobre quais caminhos;
* quais outputs foram produzidos;
* quais warnings ocorreram;
* quais erros ocorreram;
* qual validação foi feita;
* quais próximos passos são recomendados.

Em operações longas, o report final é mais importante que o log live.

## 20. Convenção de timestamp

Todos os outputs devem utilizar timestamp previsível.

Padrão:

```bash
STAMP="$(date +%Y%m%d-%H%M%S)"
```

Exemplo:

```text
stockhausen_metadata_scan_20260523-131530.tsv
```

O timestamp deve aparecer no nome de artefatos gerados para evitar sobrescrita acidental.

## 21. Convenções de naming

### 21.1 Reports

Formato recomendado:

```text
<contexto>_<tipo>_<timestamp>.txt
```

Exemplo:

```text
toolbox_phase2_docs_validation_report_20260524-211221.txt
```

### 21.2 TSV

Formato recomendado:

```text
<contexto>_<dataset>_<timestamp>.tsv
```

Exemplo:

```text
toolbox_phase2_docs_validation_20260524-211221.tsv
```

### 21.3 Snapshots

Formato recomendado:

```text
<contexto>_snapshot_<timestamp>.tsv
```

Ou, quando houver estado pré-apply:

```text
<contexto>_pre_apply_snapshot_<timestamp>.tsv
```

### 21.4 Logs live

Formato recomendado:

```text
<contexto>_live_<timestamp>.log
```

Exemplo:

```text
toolbox_host_container_tools_diagnosis_live_20260524-191932.log
```

## 22. Política de retenção

### 22.1 Reports

Reports devem ser mantidos até limpeza manual ou plano de retenção futuro.

Não devem ser apagados automaticamente.

### 22.2 Raw TSV

TSVs devem ser mantidos enquanto forem úteis como histórico operacional, evidência ou base de validação.

### 22.3 Snapshots

Snapshots não devem ser sobrescritos.

Snapshots são evidência histórica operacional.

### 22.4 Logs live

Logs live podem ser menos canônicos que reports finais, mas não devem ser apagados durante uma frente ativa.

A limpeza de logs antigos deve ter plano próprio.

## 23. Política de build pipelines

Pipelines importantes devem idealmente gerar:

| Tipo        | Objetivo                    |
| ----------- | --------------------------- |
| plan        | preview                     |
| apply/build | execução                    |
| validate    | auditoria                   |
| snapshot    | rollback/referência         |
| report      | interpretação humana        |
| manifest    | rastreabilidade de arquivos |

## 24. Diagnose, plan, apply, validate

Operações relevantes devem preferir:

```text
diagnose → plan → apply → validate
```

### 24.1 Diagnose

Gera evidência inicial.

Pode produzir:

* report;
* TSV;
* inventário;
* diagnóstico tabular;
* lista de gaps;
* lista de riscos.

Não modifica dados reais.

### 24.2 Plan

Gera plano revisável.

Pode produzir:

* report;
* TSV de plano;
* preview;
* manifest;
* estimativa;
* lista de ações futuras.

Não modifica dados reais.

### 24.3 Apply

Executa modificações reais.

Deve produzir:

* report;
* registro de apply;
* logs;
* referência a snapshot prévio;
* lista de ações executadas.

Quando houver risco, deve exigir confirmação explícita como:

```text
APPLY
```

### 24.4 Validate

Verifica resultado.

Pode produzir:

* report;
* TSV de validação;
* lista de divergências;
* lista de erros;
* recomendações.

## 25. Política de auditabilidade

Toda operação relevante deve permitir responder:

* o que foi feito?
* quando?
* por qual script?
* sobre quais arquivos?
* com quais métricas?
* com quais resultados?
* houve erros?
* houve warnings?
* houve preservação de metadata?
* quais artefatos foram gerados?
* onde estão os reports?
* onde estão os TSVs?
* onde estão os snapshots?
* qual foi a validação?

## 26. Política de long-running jobs

Jobs demorados devem:

* emitir logs progressivos;
* funcionar com `nohup`;
* ser compatíveis com `tail -f`;
* produzir relatório final consolidado;
* registrar artefatos produzidos;
* ser seguros para interrupção quando possível;
* registrar status final.

Logs live devem ser complementados por reports finais.

## 27. Política de destruição

Operações destrutivas devem idealmente possuir:

* diagnóstico prévio;
* plano;
* snapshot prévio;
* relatório pós-operação;
* manifest;
* validação posterior;
* confirmação explícita quando necessário.

Comandos destrutivos ou potencialmente perigosos devem ser tratados com cuidado especial.

Exemplos:

```text
rm
mv
find -delete
rsync --delete
sed -i
chmod -R
chown -R
metaflac --remove-all-tags
docker compose down
```

## 28. Política de compressão e cold archive

Cold archives devem possuir:

* manifest;
* relatório de build;
* métricas de redução;
* validação posterior;
* referência ao acervo original;
* timestamp;
* estratégia de retenção.

No caso de mídia, cold archive deve preservar o que foi deliberadamente removido da hot library.

## 29. Política de human readability

Relatórios devem priorizar:

* legibilidade terminal;
* `grep`;
* `less`;
* `cat`;
* `awk`;
* `tail`.

Evitar:

* formatos binários;
* dependência de GUI;
* outputs excessivamente decorativos;
* dados importantes apenas em cor;
* tabelas difíceis de copiar.

## 30. Política de crescimento

A Toolbox assume que:

* reports crescerão continuamente;
* datasets intermediários crescerão;
* snapshots crescerão;
* logs live crescerão;
* jobs crescerão.

Portanto:

* organização por domínio é obrigatória;
* naming consistente é obrigatório;
* timestamping é obrigatório;
* limpeza deve ser deliberada;
* outputs antigos são legado até plano contrário.

## 31. Outputs legados

Outputs existentes não devem ser reorganizados retroativamente sem plano.

Isso vale especialmente para:

```text
/srv/toolbox/shared/reports/media
/srv/toolbox/shared/library-db/raw
/srv/toolbox/shared/library-db/snapshots
```

Antes de reorganizar outputs legados:

1. diagnosticar;
2. classificar;
3. planejar destino;
4. aplicar com segurança;
5. validar;
6. registrar report;
7. preservar rastreabilidade.

## 32. Relação com Git

Outputs gerados não devem ser commitados por padrão.

Não commitar automaticamente:

* reports;
* logs live;
* TSVs gerados;
* snapshots;
* job outputs;
* dumps;
* artefatos temporários.

Git deve versionar:

* scripts;
* docs;
* políticas;
* manpages;
* Dockerfiles;
* compose files;
* wrappers;
* configs versionáveis.

A rotina Git está definida em:

```text
docs/operations/toolbox_git_routine.md
```

## 33. Relação com scripts/lib

Funções relacionadas a outputs devem migrar gradualmente para `scripts/lib`.

Módulos prováveis:

```text
scripts/lib/timestamps.sh
scripts/lib/tsv.sh
scripts/lib/reports.sh
scripts/lib/paths.sh
```

A biblioteca deve ajudar a padronizar outputs sem esconder efeitos importantes.

## 34. Relação com TUI/dashboard/search

Uma futura TUI, dashboard ou busca operacional poderá indexar:

* reports;
* TSVs;
* snapshots;
* logs;
* manifests;
* jobs;
* validações.

Essa camada futura não substitui outputs textuais.

A política continua sendo:

* primeiro texto auditável;
* depois visualização;
* nunca apenas interface gráfica.

## 35. Filosofia final

Relatórios não são logs descartáveis.

Eles são:

* memória operacional;
* rastreabilidade;
* documentação viva;
* auditoria histórica;
* base para automação futura;
* base para dashboards futuros;
* base para busca operacional futura.

A Toolbox só deve automatizar agressivamente aquilo que consegue auditar com clareza.
