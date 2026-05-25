# Toolbox Manpages Policy

## 1. Objetivo

Este documento define a política de manpages da Toolbox.

Manpages e groff são parte central da identidade Unix da Toolbox. A documentação da Toolbox deve ser acessível tanto no host quanto nos containers, preservando a ideia original de um ambiente Unix real, documentado localmente e consultável pelo terminal.

A política de manpages deve orientar:

* onde a documentação canônica vive;
* quais documentos devem virar manpages;
* como separar `man1`, `man7`, `docs/operations` e `docs/media`;
* como documentar comandos host-mode e container-mode;
* como tornar os manuais acessíveis no host;
* como preservar manuais dentro dos containers;
* como validar a documentação antes de promover comandos como estáveis.

## 2. Local canônico da documentação

A documentação canônica da Toolbox vive no repositório:

`/srv/toolbox/app/docs`

Esse diretório deve ser tratado como fonte principal da documentação da Toolbox.

No host, o caminho canônico é:

`/srv/toolbox/app/docs`

Nos containers da Toolbox, o mesmo conteúdo deve estar acessível em:

`/toolbox/app/docs`

A documentação não deve ser duplicada manualmente em múltiplos locais sem necessidade. Quando possível, host e containers devem consultar os mesmos arquivos versionados.

## 3. Estrutura documental

A estrutura documental da Toolbox deve distinguir:

```text
docs/man1/
docs/man7/
docs/operations/
docs/media/
```

Cada área tem finalidade diferente.

### 3.1 `docs/man1`

`docs/man1` deve conter manpages de comandos de usuário.

Exemplos atuais ou esperados:

```text
ocr(1)
pdf-text(1)
pdf-images(1)
img-convert(1)
exif(1)
run-job(1)
pdf-ocr(1)
```

Exemplos futuros:

```text
audio-probe(1)
flac-verify(1)
cue-diagnose(1)
audio-cue-split(1)
artwork-convert(1)
metadata-extract(1)
```

### 3.2 `docs/man7`

`docs/man7` deve conter manpages conceituais, arquiteturais e políticas estáveis.

Exemplos atuais ou esperados:

```text
toolbox(7)
toolbox-runtime(7)
toolbox-jobs(7)
toolbox-reports(7)
toolbox-media(7)
toolbox-operations(7)
```

### 3.3 `docs/operations`

`docs/operations` deve conter políticas vivas, diagnósticos, decisões operacionais, convenções internas e planos de evolução.

Exemplos:

```text
toolbox_architecture_reconciliation.md
toolbox_runtime_profiles.md
toolbox_scripts_lib_policy.md
toolbox_manpages_policy.md
toolbox_git_routine.md
toolbox_script_conventions.md
toolbox_reports_policy.md
toolbox_logging_policy.md
```

Esses documentos podem amadurecer futuramente para manpages `man7`, mas não precisam virar manpage imediatamente.

### 3.4 `docs/media`

`docs/media` deve conter documentação de acervos, curadoria musical, políticas específicas de mídia e modelos arquivísticos.

Exemplos:

```text
stockhausen_metadata_policy.md
stockhausen_gold_model_stimmung.md
future_sun_ra_policy.md
future_braxton_policy.md
```

Documentos de acervo podem gerar manpages conceituais quando se tornarem estáveis.

## 4. Princípio host/container

A Toolbox será híbrida host/container. Portanto, a documentação precisa estar acessível nos dois contextos.

O host é o runtime principal para:

* diagnósticos;
* administração;
* Git;
* Docker;
* storage;
* rede;
* backup;
* curadoria de acervos vivos;
* operações sobre `/srv`.

Os containers são runtimes para:

* processamento encapsulado;
* pipelines `run-job`;
* OCR;
* PDF;
* imagem;
* áudio em staging;
* NLP futuro;
* ferramentas com dependências especializadas.

A documentação deve refletir esse modelo.

Um comando pode ser executado no host, no container ou em ambos. A manpage deve declarar isso explicitamente.

## 5. Campos obrigatórios em manpages de comandos

Toda manpage de comando estável deve indicar, quando aplicável:

```text
Nome
Sinopse
Descrição
Runtime
Tipo de automação
Domínio
Entradas
Saídas
Reports
TSVs
Logs
Snapshots
Exemplos
Notas de segurança
Ver também
```

Campos recomendados:

```text
RUNTIME
AUTOMATION TYPE
DOMAIN
OUTPUTS
SAFETY
EXAMPLES
SEE ALSO
```

## 6. Runtime documentado

Toda manpage de comando deve declarar o runtime esperado.

Valores possíveis:

```text
host-mode
container-mode
both
```

### 6.1 `host-mode`

Usar `host-mode` em manpages de scripts que precisam observar ou modificar o estado real do homelab.

Exemplos:

```text
diagnose-toolbox-host-container-tools
diagnose-toolbox-output-policy-and-lib
diagnose-toolbox-architecture-vs-practice
backup-toolbox-phase2-docs
```

### 6.2 `container-mode`

Usar `container-mode` em comandos executados dentro de perfis Docker da Toolbox.

Exemplos:

```text
ocr
pdf-text
pdf-images
img-convert
pdf-ocr
image-ocr-translate
future audio-cue-split
```

### 6.3 `both`

Usar `both` quando o comando puder funcionar nos dois contextos, desde que as dependências estejam disponíveis.

Exemplos possíveis:

```text
exif
metadata-extract
flac-verify
```

## 7. Tipo de automação documentado

Toda manpage de comando deve declarar o tipo de automação.

Valores possíveis:

```text
atomic tool
run-job pipeline
operational workflow
admin diagnostic
archive campaign
support command
```

### 7.1 `atomic tool`

Ferramenta pequena e especializada que executa uma única operação.

Exemplos:

```text
ocr
pdf-text
img-convert
audio-probe
flac-verify
```

### 7.2 `run-job pipeline`

Pipeline encapsulado executado via `run-job`.

Exemplos:

```text
pdf-ocr
image-ocr-translate
future audio-cue-split
```

### 7.3 `operational workflow`

Workflow auditável por fases.

Fluxo típico:

```text
diagnose → plan → apply → validate
```

### 7.4 `admin diagnostic`

Script de diagnóstico administrativo do homelab.

Exemplos:

```text
diagnose-toolbox-host-container-tools
diagnose-toolbox-output-policy-and-lib
diagnose-toolbox-operations-docs-policy
```

### 7.5 `archive campaign`

Workflow ou conjunto de scripts voltado a curadoria de acervo.

Exemplos:

```text
Stockhausen normalization
future Sun Ra curation
future Braxton curation
```

## 8. Domínio documentado

Toda manpage deve indicar o domínio do comando ou política.

Valores possíveis:

```text
core
document-processing
media-archive
homelab-admin
operations
future-interface
```

## 9. Acesso às manpages no host

O host deve conseguir consultar as manpages da Toolbox.

Essa é uma frente imediata da Toolbox, mas deve ser implementada com diagnóstico, plano, aplicação e validação próprios.

Possíveis estratégias:

```text
MANPATH
função tbman
wrapper toolbox man
```

### 9.1 Estratégia MANPATH

Configurar o ambiente para que `man` encontre a documentação em:

`/srv/toolbox/app/docs`

Possível direção:

```bash
export MANPATH="/srv/toolbox/app/docs:${MANPATH:-}"
```

Essa configuração não deve ser aplicada sem plano e validação, porque pode interferir na resolução padrão de manpages do sistema.

### 9.2 Estratégia `tbman`

Criar uma função ou wrapper que consulte manpages da Toolbox sem alterar globalmente o `MANPATH`.

Exemplo conceitual:

```bash
tbman() {
  MANPATH="/srv/toolbox/app/docs:${MANPATH:-}" man "$@"
}
```

Essa alternativa é menos invasiva e pode ser preferível como primeira implementação.

### 9.3 Estratégia wrapper `toolbox man`

Criar futuramente um comando público:

```bash
toolbox man <page>
```

Essa opção pode ser mais elegante quando existir uma CLI unificada da Toolbox.

## 10. Acesso às manpages nos containers

Os containers da Toolbox devem conseguir consultar a documentação em:

`/toolbox/app/docs`

Cada perfil Docker deve preservar acesso a essa documentação.

Perfis esperados:

```text
toolbox-base
toolbox-docs
toolbox-media
toolbox-nlp
```

O perfil `toolbox-base` deve incluir suporte mínimo a:

```text
man-db
groff
less
documentação
```

Os perfis derivados devem herdar esse suporte.

## 11. Relação com perfis Docker

A política de manpages deve acompanhar a política de perfis Docker.

### 11.1 `toolbox-base`

Deve fornecer:

* `man`;
* `groff`;
* `less`;
* estrutura `/toolbox/app/docs`;
* documentação comum.

### 11.2 `toolbox-docs`

Deve documentar comandos como:

* `ocr`;
* `pdf-text`;
* `pdf-images`;
* `img-convert`;
* `exif`;
* `pdf-ocr`.

### 11.3 `toolbox-media`

Deve documentar comandos futuros como:

* `audio-probe`;
* `flac-verify`;
* `cue-diagnose`;
* `audio-cue-split`;
* `artwork-convert`;
* `metadata-extract`.

### 11.4 `toolbox-nlp`

Deve documentar comandos futuros de NLP, extração textual e análise avançada.

## 12. Critérios para criar uma manpage

Criar manpage quando o comando ou conceito for:

* estável;
* reutilizável;
* relevante para uso recorrente;
* parte da interface pública ou semi-pública da Toolbox;
* útil para consulta rápida no terminal;
* suficientemente consolidado para não mudar toda semana.

Não é obrigatório criar manpage para todo script interno.

Scripts operacionais longos ou específicos podem ser documentados em `docs/operations` ou `docs/media` antes de virarem manpage.

## 13. Scripts operacionais e manpages

Nem todo script operacional deve virar manpage.

Scripts de diagnóstico, plano, apply e validação podem ser documentados em três níveis:

1. comentários internos no próprio script;
2. documentação em `docs/operations` ou `docs/media`;
3. manpage, quando o script se tornar comando recorrente e estável.

A saga Stockhausen mostrou que scripts podem funcionar como documentação operacional. Isso deve ser preservado.

## 14. Formato recomendado

Manpages devem seguir formato tradicional compatível com `man-db` e `groff`.

Seções comuns:

```text
.TH
.SH NAME
.SH SYNOPSIS
.SH DESCRIPTION
.SH RUNTIME
.SH AUTOMATION TYPE
.SH DOMAIN
.SH INPUTS
.SH OUTPUTS
.SH REPORTS
.SH LOGS
.SH SAFETY
.SH EXAMPLES
.SH SEE ALSO
```

## 15. Markdown e manpages

A Toolbox pode manter documentação em Markdown e manpages em groff ao mesmo tempo.

Uso recomendado:

* Markdown para políticas vivas, planos e documentação extensa;
* groff/manpages para comandos estáveis e consulta rápida;
* scripts para documentação operacional executável.

Não converter automaticamente todo Markdown para manpage sem revisão.

## 16. Validação de manpages

Toda manpage nova deve ser validada.

Validações possíveis:

```bash
man /srv/toolbox/app/docs/man1/<page>.1
man /srv/toolbox/app/docs/man7/<page>.7
```

ou, quando `MANPATH`/`tbman` estiver configurado:

```bash
tbman <page>
```

Também validar renderização com:

```bash
groff -man -Tutf8 /srv/toolbox/app/docs/man1/<page>.1 | less
```

## 17. Política de implementação

A implementação do acesso host às manpages deve seguir:

```text
diagnose → plan → apply → validate
```

Antes de configurar acesso host:

1. diagnosticar estrutura atual de `docs/man1` e `docs/man7`;
2. verificar `man`, `groff`, `less` no host;
3. verificar `MANPATH` atual;
4. decidir entre `MANPATH`, `tbman` ou wrapper;
5. aplicar sem quebrar manpages do sistema;
6. validar consulta no host;
7. validar consulta no container.

## 18. O que não fazer agora

Não fazer sem plano próprio:

* alterar `.bashrc`;
* alterar `.bash_aliases`;
* alterar `.bashrc.d`;
* alterar `.bash_aliases.d`;
* instalar pacotes;
* mover manpages;
* converter todos os Markdown para manpages;
* criar wrapper definitivo;
* alterar Dockerfile;
* rebuildar imagens;
* fazer commit.

## 19. Relação com FileBrowser

FileBrowser pode facilitar acesso visual a documentos e reports, mas não substitui manpages.

FileBrowser é auxiliar read-only para navegação e comunicação.

A documentação Unix da Toolbox deve continuar acessível pelo terminal.

## 20. Relação com TUI/dashboard/search

Uma futura TUI/dashboard/search pode indexar ou expor manpages, Markdown, reports e TSVs.

Isso não substitui manpages.

A política correta é preservar camadas complementares:

* manpages para consulta Unix rápida;
* Markdown para documentação extensa;
* reports para resultados operacionais;
* TSVs para dados estruturados;
* TUI/dashboard/search para navegação futura.

## 21. Próximas frentes

Frentes imediatas relacionadas a manpages:

1. consolidar esta política;
2. diagnosticar manpages atuais;
3. planejar acesso host;
4. implementar `tbman` ou estratégia equivalente;
5. validar manpages no host;
6. validar manpages nos containers;
7. documentar comandos novos conforme amadurecem.
