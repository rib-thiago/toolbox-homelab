# Toolbox Logging Policy

## 1. Objetivo

Este documento define a política da Toolbox para:

* logging;
* execução em background;
* `nohup`;
* `nf`;
* `tail -f`;
* `tf`;
* jobs longos;
* live logs;
* logs internos de jobs;
* reports finais;
* observabilidade textual;
* rastreabilidade operacional.

A Toolbox adota logging textual simples, auditável, local-first, shell-first e compatível com ferramentas Unix.

Logging não deve ser tratado como detalhe secundário. Logs, reports e artefatos estruturados são parte da arquitetura operacional da Toolbox.

Este documento deve ser lido em conjunto com:

* `docs/operations/toolbox_script_conventions.md`;
* `docs/operations/toolbox_reports_policy.md`;
* `docs/operations/toolbox_runtime_profiles.md`;
* `docs/operations/toolbox_scripts_lib_policy.md`;
* `docs/operations/toolbox_git_routine.md`.

## 2. Filosofia geral

A Toolbox prioriza:

* logs legíveis;
* observabilidade simples;
* compatibilidade terminal;
* compatibilidade com `tail`;
* compatibilidade com `grep`;
* compatibilidade com `less`;
* compatibilidade com `awk`;
* compatibilidade com `nohup`;
* execução remota via SSH;
* execução via Tailscale;
* uso em terminal móvel quando necessário.

Evitar:

* sistemas pesados de logging sem necessidade;
* dependência de GUI;
* formatos binários;
* dashboards obrigatórios;
* abstrações excessivas;
* logs que só fazem sentido em terminal interativo;
* outputs coloridos como única forma de sinalização.

A filosofia operacional é:

```text
observabilidade simples e robusta
```

em vez de:

```text
infraestrutura pesada de logging
```

## 3. Logs, reports e TSVs

A Toolbox distingue:

```text
live log
internal job log
human report
structured TSV
snapshot
manifest
```

Esses artefatos não têm a mesma função.

### 3.1 Live log

Um live log acompanha execução.

Ele responde:

* o script ainda está rodando?
* qual etapa está em andamento?
* houve erro?
* há progresso?
* qual arquivo está sendo processado?

### 3.2 Internal job log

Um internal job log pertence a um job encapsulado, especialmente pipelines `run-job`.

Exemplo conceitual:

```text
/toolbox/jobs/<job-id>/log.txt
```

### 3.3 Human report

Um report humano interpreta ou resume a execução.

Ele responde:

* o que foi feito?
* qual foi o resultado?
* quais artefatos foram gerados?
* houve warnings?
* houve validação?
* qual é o próximo passo?

### 3.4 Structured TSV

Um TSV registra dados estruturados.

Ele é usado para:

* inventários;
* validações;
* planos;
* manifests;
* registros de apply;
* diagnósticos tabulares.

Logs não substituem reports.

Reports não substituem TSVs.

TSVs não substituem reports.

## 4. Princípios

Logs devem ajudar a responder:

* o que está acontecendo?
* o script travou?
* ainda está executando?
* onde ocorreu erro?
* qual arquivo está sendo processado?
* houve progresso?
* qual etapa está ativa?
* quais outputs foram gerados?

Logs devem ser humanos primeiro:

```text
human-readable first
```

Logs devem ser compatíveis com ferramentas Unix.

Evitar logs que dependem de:

* terminal específico;
* GUI;
* dashboard;
* cor obrigatória;
* animação;
* TUI.

## 5. Função `log()`

Scripts novos devem usar função `log()` padronizada.

Forma mínima atual:

```bash
log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}
```

Essa forma é preferível ao timestamp apenas com hora, porque melhora rastreabilidade em logs longos e execuções atravessando dias.

Com a criação de `scripts/lib`, `log()` deve migrar gradualmente para:

```text
scripts/lib/logging.sh
```

Durante a transição, scripts autocontidos continuam aceitáveis.

## 6. Função `fail()`

Scripts críticos devem usar função `fail()` padronizada.

Forma mínima atual:

```bash
fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}
```

Com a criação de `scripts/lib`, `fail()` deve migrar gradualmente para:

```text
scripts/lib/logging.sh
```

`fail()` deve ser usado quando o erro impede continuação segura.

Scripts de diagnóstico devem evitar abortar por ausência de itens opcionais.

## 7. Timestamps

Todos os logs relevantes devem conter timestamps.

Formato recomendado para `log()`:

```text
[YYYY-MM-DD HH:MM:SS]
```

Exemplo:

```text
[2026-05-24 21:12:21] Validating Phase 2 documentation.
```

Para nomes de arquivos, usar:

```bash
STAMP="$(date +%Y%m%d-%H%M%S)"
```

Exemplo:

```text
toolbox_phase2_docs_validation_report_20260524-211221.txt
```

## 8. Verbosidade

Logs devem:

* indicar progresso;
* indicar contexto;
* indicar etapa atual;
* indicar warnings;
* indicar outputs finais;
* indicar início;
* indicar conclusão.

Evitar:

* spam excessivo;
* linha por linha inútil;
* logs gigantes sem contexto;
* logs que ocultam o que realmente importa;
* logs sem timestamp.

Para loops muito grandes, preferir logs por etapa, por bloco ou por resumo, salvo quando linha a linha for necessário para auditoria.

## 9. Long-running jobs

Scripts demorados devem:

* funcionar corretamente com `nohup`;
* emitir logs progressivos;
* permitir monitoramento via `tail -f`;
* evitar buffering excessivo quando possível;
* sobreviver ao fechamento do terminal;
* registrar conclusão;
* registrar caminhos dos artefatos finais;
* não depender de input interativo inesperado.

Exemplos de long-running jobs:

* conversão de artwork;
* scans grandes;
* inventários de biblioteca;
* validações extensas;
* builds de cold archive;
* operações de mídia em lote.

## 10. Execução em background

Padrão recomendado para jobs longos:

```bash
LOG="/srv/toolbox/shared/reports/media/nome_live_$(date +%Y%m%d-%H%M%S).log"
nf script.sh > "$LOG" 2>&1 &
tf "$LOG"
```

O caminho acima é exemplo herdado da prática recente e ainda pode ser provisório.

A política final de outputs deve organizar logs live por domínio.

`nf` é entendido como wrapper/alias para `nohup`.

`tf` é entendido como helper para `tail -f`.

Forma expandida equivalente:

```bash
LOG="/path/to/live_<timestamp>.log"
nohup script.sh > "$LOG" 2>&1 &
tail -f "$LOG"
```

## 11. Live logs

Logs live devem usar nomes claros.

Formato recomendado:

```text
<contexto>_live_<timestamp>.log
```

Exemplos:

```text
toolbox_host_container_tools_diagnosis_live_20260524-191932.log
stockhausen_artwork_cold_archive_build_live_20260524-000000.log
```

Logs live são operacionais.

Eles nem sempre são artefatos canônicos.

Quando houver report final, o report final tem precedência interpretativa sobre o live log.

## 12. Localização de logs

A localização de logs ainda está em consolidação.

Princípios:

* logs live não pertencem sempre a `reports/media`;
* logs de mídia podem ficar sob domínio de mídia;
* logs administrativos devem futuramente ficar sob domínio administrativo;
* logs de documentação podem precisar de domínio próprio;
* logs de runtime/manpages podem precisar de domínio próprio.

Enquanto a política final não for aplicada, scripts podem usar destinos provisórios, desde que declarem isso no report.

Exemplo de aviso recomendado:

```text
Output destinations are provisional and inherited from recent scripts, not final policy.
```

## 13. Logs de `run-job`

Pipelines `run-job` podem manter logs internos no diretório de job.

Exemplo:

```text
/toolbox/jobs/<job-id>/log.txt
```

Esses logs fazem parte da estrutura do job.

Eles não eliminam a necessidade de report final quando o pipeline fizer parte de workflow maior.

## 14. Logs em workflows operacionais

Workflows operacionais podem envolver múltiplos scripts.

Fluxo típico:

```text
diagnose → plan → apply → validate
```

Cada fase pode gerar:

* live log;
* report humano;
* TSV;
* snapshot;
* manifest;
* registro de apply.

Em workflows com risco, os logs devem permitir reconstruir a sequência operacional.

## 15. `tee` interno

`tee` interno não deve ser o padrão para novos scripts operacionais.

Preferir logs externos controlados pelo shell:

```bash
nf script.sh > "$LOG" 2>&1 &
```

`tee` interno é aceitável quando deliberado e documentado.

Casos aceitáveis:

* script explicitamente projetado para manter log interno;
* pipeline legado que já usa `tee`;
* necessidade real de stdout e arquivo simultâneos;
* `run-job` encapsulado;
* ferramenta que precisa emitir report enquanto exibe output.

Se `tee` for usado, o motivo deve ser claro.

## 16. `tail -f` e `tf`

Todos os long-running jobs devem idealmente funcionar bem com:

```bash
tail -f "$LOG"
```

ou:

```bash
tf "$LOG"
```

O log deve ser escrito de modo que `tail -f` mostre progresso útil.

## 17. Warnings

Warnings devem:

* ser explícitos;
* indicar contexto;
* não abortar o script automaticamente quando forem não fatais;
* permitir continuidade operacional quando seguro;
* aparecer em logs e, quando relevante, em reports finais.

Exemplo de warning conhecido e não fatal:

```text
libpng warning: iCCP: known incorrect sRGB profile
```

Warnings conhecidos e não fatais devem ser tolerados.

## 18. Erros críticos

Erros críticos devem:

* abortar execução;
* ser claros;
* apontar dependência ou contexto;
* evitar mensagens vagas;
* indicar arquivo, etapa ou comando quando possível.

Usar `fail()` quando a continuação não for segura.

## 19. Falha parcial

Em pipelines ou workflows massivos, falhas individuais podem ser toleradas quando isso for seguro.

Exemplos:

* artwork;
* metadata;
* scanning;
* conversões;
* validações em lote.

Quando houver tolerância a falhas parciais:

* registrar erro;
* continuar com segurança;
* contar falhas;
* reportar falhas no final;
* gerar report ou TSV de anomalias quando fizer sentido.

## 20. Dependências

Toda dependência importante deve ser validada explicitamente quando sua ausência impedir execução.

Exemplo:

```bash
command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg não encontrado."
```

A validação deve distinguir:

* dependência obrigatória;
* dependência opcional;
* dependência host-mode;
* dependência container-mode;
* dependência necessária apenas para uma fase.

## 21. Progress reporting

Scripts longos devem informar:

* início;
* etapa atual;
* arquivo atual quando relevante;
* contexto atual;
* conclusão parcial;
* outputs produzidos;
* conclusão final.

Exemplo:

```text
[2026-05-24 20:08:41] Creating documentation backup.
[2026-05-24 20:08:41] Backup completed.
[2026-05-24 20:08:41] Human report: ...
```

## 22. Observabilidade

A Toolbox favorece observabilidade:

* textual;
* local-first;
* shell-first;
* grep-friendly;
* auditável;
* sem dependência obrigatória de dashboard.

Ferramentas preferenciais:

* `tail`;
* `less`;
* `grep`;
* `awk`;
* `watch`;
* `journalctl`;
* `ss`;
* `docker logs`.

Dashboards futuros podem consumir outputs da Toolbox, mas não devem substituir logs e reports textuais.

## 23. Logs coloridos

Logs coloridos são opcionais.

Scripts não devem depender de:

* ANSI obrigatório;
* terminal específico;
* interface rica;
* cor como única indicação de estado.

Compatibilidade com `nohup` é prioridade.

## 24. Encoding

Preferência:

```text
UTF-8
```

Evitar caracteres problemáticos em:

* nomes de logs;
* TSVs;
* manifests;
* paths;
* outputs que precisam ser parseados.

Unicode é aceitável em documentação e mensagens humanas, mas deve ser usado com moderação em artefatos estruturados.

## 25. Job safety

Scripts devem idealmente:

* sobreviver ao fechamento de terminal;
* evitar outputs interativos obrigatórios;
* evitar prompts desnecessários;
* funcionar remotamente via SSH;
* funcionar remotamente via Tailscale;
* registrar artefatos finais;
* não depender de terminal gráfico.

Scripts que exigem confirmação interativa, como `APPLY`, devem ser executados em foreground, salvo estratégia própria.

## 26. Conclusão de execução

Todo long-running script deve idealmente emitir:

* mensagem de conclusão;
* status final;
* outputs produzidos;
* reports finais;
* localização dos arquivos;
* próximos passos quando necessário.

Exemplo:

```text
Build concluído.
Relatório: ...
TSV: ...
```

## 27. Logs e confirmação `APPLY`

Scripts que exigem confirmação `APPLY` devem, em geral, ser executados em foreground.

Motivo:

* execução em background pode bloquear aguardando input;
* logs live não substituem confirmação consciente;
* operações modificativas exigem controle explícito.

Se um script com `APPLY` for adaptado para background, ele deve ter mecanismo seguro e documentado.

## 28. Logs e Git

Logs gerados não devem ser commitados por padrão.

Não commitar automaticamente:

* live logs;
* logs de execução;
* reports gerados;
* TSVs gerados;
* snapshots;
* job outputs.

A rotina Git está definida em:

```text
docs/operations/toolbox_git_routine.md
```

## 29. Logs e `scripts/lib`

Funções de logging devem migrar gradualmente para:

```text
scripts/lib/logging.sh
```

Esse módulo deve conter, no mínimo:

```bash
log()
fail()
```

Possíveis funções futuras:

```text
warn()
info()
debug()
```

Essas funções futuras só devem ser adicionadas quando houver necessidade real.

## 30. Logs e serviços existentes

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

Logs podem registrar diagnósticos desses serviços, mas scripts não devem alterá-los sem plano.

## 31. Logs e TUI/dashboard/search

Uma futura TUI, dashboard ou busca operacional pode consumir:

* logs;
* reports;
* TSVs;
* snapshots;
* manifests;
* job metadata.

Mas essa camada não substitui logging textual.

A política correta é:

* primeiro logs e reports auditáveis;
* depois indexação;
* depois visualização.

## 32. O que evitar

Evitar:

* logs sem timestamp;
* logs excessivamente verbosos sem contexto;
* logs que dependem de cor;
* logs binários;
* logs que só funcionam em GUI;
* `tee` interno por hábito;
* live log sem report final;
* report final sem indicação dos logs;
* prompts interativos inesperados em jobs longos;
* logs em destino aleatório;
* apagar logs no meio de uma frente ativa.

## 33. Filosofia final

Logs são:

* memória operacional;
* observabilidade;
* rastreabilidade;
* diagnóstico;
* suporte a auditoria;
* segurança psicológica operacional.

A prioridade é:

```text
entender claramente o que o sistema está fazendo
```

mesmo em:

* SSH remoto;
* Tailscale;
* mobile terminal;
* jobs de várias horas;
* workflows interrompidos;
* validações longas.
