# Toolbox scripts/lib Policy

## 1. Objetivo

Este documento define a política de criação e adoção de `scripts/lib` na Toolbox.

`scripts/lib` deve deixar de ser placeholder e passar a ser uma base comum mínima para scripts operacionais, administrativos, de mídia e de diagnóstico.

A criação da biblioteca não autoriza migração automática de todos os scripts existentes. A adoção deve ser gradual, validada e orientada por necessidade real.

## 2. Motivação

A prática operacional da Toolbox consolidou padrões repetidos:

```bash
#!/usr/bin/env bash
set -u

log() {
  ...
}

fail() {
  ...
}
````

Também consolidou padrões para:

* timestamps;
* reports;
* logs live;
* TSVs;
* snapshots;
* validação;
* paths oficiais ou provisórios;
* mensagens de erro;
* execução auditável.

Esses padrões devem ser centralizados progressivamente em `scripts/lib`.

## 3. Princípios

`scripts/lib` deve seguir estes princípios:

* ser pequeno;
* ser legível;
* não virar framework;
* evitar magia;
* não esconder efeitos destrutivos;
* preservar auditabilidade;
* funcionar com `set -u`;
* ser compatível com scripts host-mode;
* ser compatível com scripts container-mode quando aplicável;
* permitir adoção gradual.

## 4. Módulos iniciais propostos

### 4.1 `logging.sh`

Responsável por:

```bash
log()
fail()
```

Contrato mínimo:

```bash
log "mensagem"
fail "mensagem"
```

### 4.2 `timestamps.sh` ou `common.sh`

Responsável por:

```bash
toolbox_timestamp()
toolbox_now()
```

Formato preferencial:

```text
YYYYMMDD-HHMMSS
```

### 4.3 `paths.sh`

Responsável por funções de path, não por impor política definitiva antes da hora.

Exemplos futuros:

```bash
toolbox_app_dir
toolbox_shared_dir
toolbox_reports_dir
toolbox_raw_dir
toolbox_snapshots_dir
```

Enquanto a política de outputs estiver em transição, este módulo deve deixar claro quando um path é provisório.

### 4.4 `tsv.sh`

Responsável por:

```bash
tsv_escape()
tsv_row()
```

Deve evitar bugs já encontrados, como sobrescrita de variáveis globais por falta de `local`.

### 4.5 `reports.sh`

Responsável por helpers de criação de nomes de artefatos:

```bash
toolbox_report_path
toolbox_tsv_path
toolbox_live_log_path
```

Não deve criar diretórios sem decisão explícita.

### 4.6 `snapshots.sh`

Módulo futuro. Não precisa entrar na primeira leva se não houver contrato claro.

## 5. O que não entra agora

Não entram agora:

* funções complexas de Docker;
* funções de Git avançadas;
* funções de mídia específicas;
* funções Stockhausen específicas;
* funções que apagam, movem ou alteram dados;
* abstrações para todos os tipos de output;
* dependência obrigatória para scripts antigos.

## 6. Adoção gradual

Scripts novos devem preferir `scripts/lib` quando a função já existir e estiver validada.

Scripts antigos só devem ser migrados quando:

* houver motivo real;
* houver teste manual ou `bashcheck`;
* houver comparação de output antes/depois;
* houver validação;
* o risco for baixo.

## 7. Compatibilidade

Durante a transição, são aceitáveis:

* scripts autocontidos;
* scripts importando apenas `logging.sh`;
* scripts importando mais módulos;
* scripts legados ainda não migrados.

O objetivo é convergência gradual, não reescrita em massa.

## 8. Exemplo futuro

```bash
#!/usr/bin/env bash
set -u

source /srv/toolbox/app/scripts/lib/logging.sh
source /srv/toolbox/app/scripts/lib/tsv.sh

main() {
  log "Starting diagnosis"
}

main "$@"
```

## 9. Validação

Antes de usar um módulo de `scripts/lib`:

```bash
bashcheck scripts/lib/<module>.sh
```

Antes de migrar script:

```bash
bashcheck script.sh
```

Depois de migrar:

* executar script;
* comparar artefatos;
* validar relatório;
* validar TSV;
* garantir que não houve mudança destrutiva.
