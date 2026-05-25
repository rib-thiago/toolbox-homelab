# Toolbox Architecture Reconciliation

## 1. Objetivo

Este documento registra a reconciliação entre a arquitetura originalmente projetada da Toolbox e a prática operacional que emergiu durante o uso real do homelab, especialmente na saga Stockhausen.

A Toolbox não deve mais ser entendida apenas como um container de processamento documental. Ela passa a ser documentada como uma plataforma operacional híbrida do homelab, organizada por domínios internos, com múltiplos runtimes possíveis e diferentes tipos de automação.

Este documento não aplica mudanças em diretórios, Dockerfiles, scripts ou outputs. Ele estabelece a base conceitual para patches e implementações posteriores.

## 2. Arquitetura original

A arquitetura original da Toolbox foi concebida como um ambiente Unix remoto, especializado em processamento de documentos, imagens e texto, executado em container Docker.

Princípios originais:

- ferramentas pequenas e especializadas;
- composição de comandos;
- transparência de execução;
- reprodutibilidade;
- ambiente isolado;
- menor poluição do host;
- facilidade de migração para outro servidor;
- documentação local via manpages;
- pipelines estruturados com `run-job`.

Estrutura conceitual original:

```text
bin/
scripts/helpers/
scripts/pipelines/
scripts/lib/
docs/man1/
docs/man7/
jobs/
shared/
models/
secrets/
````

Essa arquitetura continua válida como base conceitual, mas não descreve sozinha toda a prática operacional atual.

## 3. Prática emergente

Durante o uso real da Toolbox, especialmente na curadoria Stockhausen-Verlag, emergiu uma prática operacional mais ampla:

* scripts administrativos do homelab;
* scripts de diagnóstico;
* scripts de curadoria de mídia;
* workflows por fases;
* reports humanos;
* TSVs;
* snapshots;
* freezes;
* logs live externos;
* validações explícitas;
* scripts como documentação operacional;
* execução host-mode para acervos vivos;
* necessidade de rotina Git;
* necessidade de política de outputs por domínio.

Fluxo operacional consolidado:

```text
diagnose → plan → apply → validate
```

Extensões observadas:

```text
repair
resume
freeze
snapshot
purge
import
split
```

## 4. Decisão arquitetural

A Toolbox será tratada como uma plataforma operacional híbrida host/container.

Definição aprovada:

```text
A Toolbox será tratada como plataforma híbrida host/container, em que o container permanece para processamento encapsulado e reprodutível, enquanto o host é o runtime principal para diagnósticos, administração e curadoria de acervos vivos.
```

Essa decisão não elimina o container. Ela redefine seu papel.

## 5. Domínios internos

A Toolbox passa a ser compreendida por domínios internos:

```text
core
document-processing
media-archive
homelab-admin
operations
future-interface
```

### 5.1 core

Responsável por:

* estrutura comum;
* comandos públicos;
* documentação Unix;
* manpages;
* convenções;
* políticas;
* biblioteca comum em `scripts/lib`.

### 5.2 document-processing

Responsável por:

* OCR;
* PDF;
* imagens;
* texto;
* NLP futuro;
* pipelines documentais.

Runtime preferencial atual:

```text
container-mode
```

### 5.3 media-archive

Responsável por:

* música;
* metadados;
* FLAC;
* CUE;
* artwork;
* imports;
* validações;
* snapshots;
* cold archive;
* acervos como Stockhausen, Sun Ra e futuros projetos.

Runtime atual predominante:

```text
host-mode
```

Runtime prioritário a implementar tão logo possível:

```text
container-mode via toolbox-media
```

A criação de `toolbox-media` deve permitir processamento reprodutível de áudio/mídia em staging ou jobs encapsulados, sem substituir automaticamente workflows host-mode sobre acervos vivos.

### 5.4 homelab-admin

Responsável por:

* Docker;
* rede;
* storage;
* firewall;
* backup;
* Git;
* sistema;
* auditorias;
* diagnósticos.

Runtime preferencial:

```text
host-mode
```

### 5.5 operations

Responsável por:

* padrões de scripts;
* logs;
* reports;
* TSVs;
* snapshots;
* jobs;
* Git routine;
* políticas;
* validações.

Os padrões operacionais devem ser convertidos em funções comuns dentro de `scripts/lib/` e importados gradualmente pelos scripts.

### 5.6 future-interface

Responsável futuramente por:

* TUI;
* dashboard;
* busca;
* navegação de reports;
* navegação de TSVs;
* inspeção de jobs;
* validações;
* acervos;
* snapshots.

Essa camada deve nascer da prática real, não de abstração genérica.

## 6. host-mode

`host-mode` é o runtime usado quando o script precisa observar, auditar ou modificar o estado vivo do homelab.

Usar host-mode quando for necessário acessar:

```text
/srv
/srv/media
/srv/compose
Docker daemon
UFW
Tailscale
Restic
Samba
Navidrome
FileBrowser
Git real
permissões reais
serviços reais
```

Exemplos:

* diagnósticos de Docker;
* auditorias de storage;
* backup reports;
* diagnóstico de Navidrome;
* import para biblioteca canônica;
* validação de acervo real;
* rotina Git;
* scripts administrativos.

## 7. container-mode

`container-mode` é o runtime usado quando a prioridade é reprodutibilidade, isolamento de dependências e processamento encapsulado.

Usar container-mode quando o trabalho puder operar sobre:

```text
input/
work/
output/
job directory
staging copy
shared controlled input
```

Exemplos:

* OCR de PDF;
* conversão de imagem;
* NLP;
* split de áudio em staging;
* verificação de FLAC em cópia;
* conversão de artwork em cópia;
* extração de metadados em staging.

## 8. Perfis Docker

A Toolbox deve evoluir para perfis/imagens especializadas.

### 8.1 toolbox-base

Camada comum:

```text
shell
coreutils
bash
git
curl
man-db
groff
less
documentação
estrutura comum /toolbox
```

### 8.2 toolbox-docs

Processamento documental:

```text
Tesseract
Poppler
ImageMagick
Ghostscript
ExifTool
Python documental
```

### 8.3 toolbox-media

Processamento de mídia/áudio:

```text
ffmpeg
ffprobe
flac
metaflac
shntool
shnsplit
cuetools
cuebreakpoints
cueprint
cuetag
sox
fpcalc
id3v2
mid3v2
ferramentas de metadata
```

`toolbox-media` é uma frente prioritária posterior à documentação-base e ao plano de implementação.

### 8.4 toolbox-nlp

Processamento de linguagem natural:

```text
Python NLP
spaCy
modelos
OCR avançado
embeddings
ferramentas futuras de análise textual
```

## 9. run-job e workflows operacionais

`run-job` continua válido, mas não é padrão universal.

Usar `run-job` quando houver:

* input claro;
* output claro;
* execução encapsulada;
* status simples;
* baixa necessidade de decisão humana intermediária;
* artefatos contidos em um diretório de job.

Usar workflow operacional quando houver:

* risco;
* acervo vivo;
* decisão humana;
* plano antes de aplicação;
* snapshot;
* validação independente;
* possibilidade de repair/resume;
* necessidade de auditoria.

Um workflow operacional pode chamar `run-job` como subetapa.

Exemplo:

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

## 10. scripts/lib

`scripts/lib` deixa de ser tratado apenas como placeholder futuro. Ele deve ser criado agora como base comum mínima.

Objetivo:

* reduzir repetição;
* padronizar `log()`;
* padronizar `fail()`;
* padronizar timestamps;
* padronizar paths;
* padronizar escrita de TSV;
* padronizar criação de nomes de reports;
* preparar scripts mais auditáveis.

A adoção deve ser gradual. Scripts existentes não devem ser migrados em massa sem plano e validação.

## 11. Manpages e groff

Manpages e groff são parte central da identidade Unix da Toolbox.

A documentação canônica deve viver no repositório:

```text
/srv/toolbox/app/docs
```

E deve ser acessível:

```text
host:
  /srv/toolbox/app/docs

container:
  /toolbox/app/docs
```

Objetivo imediato:

* manter manpages para ferramentas estáveis;
* tornar manpages acessíveis do host;
* preservar manpages dentro dos containers;
* documentar runtime de cada comando.

Categorias:

```text
man1 = comandos de usuário
man7 = conceitos, arquitetura e políticas estáveis
docs/operations = políticas vivas
docs/media = documentação de acervos
```

## 12. Outputs

A política de outputs ainda está em elaboração.

Princípios já definidos:

* `reports/media` não é destino universal;
* `library-db/raw` não é destino universal;
* logs live não pertencem sempre a `reports/media`;
* outputs legados não devem ser movidos sem plano;
* outputs devem ser organizados por domínio e finalidade.

## 13. Serviços existentes

A evolução da Toolbox não deve afetar serviços existentes:

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

`toolbox-media` não deve modificar o funcionamento do Navidrome. Ele deve operar inicialmente sobre staging, cópias ou jobs encapsulados.

## 14. Frentes imediatas

Frentes imediatas após aprovação documental:

1. criar `scripts/lib` mínimo;
2. implementar acesso host às manpages;
3. planejar perfis Docker;
4. priorizar `toolbox-media`;
5. documentar política de outputs;
6. documentar rotina Git.

## 15. Frentes adiadas

Adiadas:

* TUI/dashboard;
* pyenv/Python hygiene;
* reorganização física de outputs;
* migração massiva de scripts;
* import 089;
* NLP avançado;
* commits grandes sem classificação.

