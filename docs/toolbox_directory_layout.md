# Layout de Diretórios da Toolbox

Este documento descreve a organização estrutural do ambiente da toolbox dentro do homelab. O objetivo é explicar o papel de cada diretório, quais dados são armazenados em cada local e quais são persistentes.

Compreender essa estrutura é importante para manutenção, backup, troubleshooting e evolução futura do sistema.

---

## Visão Geral

A toolbox ocupa o diretório raiz:

/srv/toolbox

Esse diretório contém tanto o código da aplicação quanto os dados produzidos durante sua operação.

Estrutura geral:

/srv/toolbox
├── app
├── jobs
├── models
├── shared
└── secrets

Cada diretório possui uma função específica dentro do sistema.

---

### Diretório app

/srv/toolbox/app

Este diretório contém todo o código versionado da toolbox.

Ele é montado dentro do container em:

/toolbox/app

Estrutura interna:

/srv/toolbox/app
├── bin
├── scripts
├── docs
├── docker
├── compose
└── requirements

Esse diretório é mantido sob controle de versão com Git.

---

#### bin

/srv/toolbox/app/bin

Contém os comandos públicos da toolbox.

Tudo que o usuário executa diretamente deve estar aqui.

Exemplos:

ocr
translate
pdf-images
pdf-text
img-convert
exif
run-job

Os arquivos em bin normalmente são wrappers finos que delegam a execução para scripts em outros diretórios.

---

#### scripts

/srv/toolbox/app/scripts

Contém a implementação real das ferramentas da toolbox.

Estrutura:

scripts/helpers
scripts/pipelines
scripts/lib

---

##### scripts/helpers

/srv/toolbox/app/scripts/helpers

Implementação das ferramentas atômicas.

Cada script executa uma única operação específica.

Exemplos:

ocr.sh
translate.sh
pdf-images.sh
pdf-text.sh
img-convert.sh
exif.sh

Esses scripts são chamados pelos comandos públicos em bin/.

---

#### scripts/pipelines

/srv/toolbox/app/scripts/pipelines

Contém pipelines compostos de processamento.

Esses pipelines são executados através do comando run-job.

Exemplo atual:

pdf-ocr.sh

Pipelines normalmente utilizam ferramentas definidas em helpers.

---

#### scripts/lib

/srv/toolbox/app/scripts/lib

Contém funções compartilhadas entre helpers e pipelines.

Esse diretório é destinado a código reutilizável.

Exemplos possíveis:

funções de logging
validação de argumentos
utilidades de manipulação de arquivos

Atualmente esse diretório pode estar vazio ou conter poucas funções, mas ele existe para facilitar evolução futura.

---

### docs

/srv/toolbox/app/docs

Contém a documentação da toolbox.

Estrutura:

docs/man1
docs/man7

---

docs/man1

Contém manpages de comandos da toolbox.

Exemplos:

ocr.1
translate.1
pdf-images.1
pdf-text.1
img-convert.1
exif.1
run-job.1

Essas páginas são acessíveis com:

man ocr
man pdf-images

---

docs/man7

Contém páginas de documentação conceitual.

Exemplo:

toolbox.7

Esse tipo de documentação descreve arquitetura e funcionamento do sistema.

---

### docker

/srv/toolbox/app/docker

Contém arquivos necessários para construir a imagem Docker da toolbox.

Exemplos:

Dockerfile
manpath.config

Esse diretório define o ambiente de execução da toolbox.

---

### compose

/srv/toolbox/app/compose

Contém a configuração Docker Compose responsável por iniciar o container da toolbox.

Arquivo principal:

docker-compose.yml

Esse arquivo define:

imagem
volumes
rede
usuário do container
variáveis de ambiente

---

### requirements

Arquivos relacionados a dependências Python da toolbox.

Exemplo:

requirements.txt

Essas dependências são instaladas durante o build da imagem Docker.

---

## Diretório jobs

/srv/toolbox/jobs

Armazena execuções estruturadas de pipelines.

Cada execução cria um diretório próprio.

Exemplo:

/srv/toolbox/jobs/2026-03-14-033632-pdf-ocr

Estrutura interna típica:

input
work
output
log.txt
status

Esse diretório é persistente e pode crescer com o tempo.

---

## Diretório models

/srv/toolbox/models

Armazena modelos grandes utilizados pela toolbox.

Exemplos possíveis:

modelos de NLP
modelos de OCR customizados
modelos de machine learning

Esse diretório existe para evitar que arquivos grandes sejam armazenados dentro do repositório Git.

---

## Diretório shared

/srv/toolbox/shared

Diretório de troca de arquivos entre o host e o container.

Esse é o local recomendado para colocar arquivos que serão processados pela toolbox.

Exemplo de uso:

copiar PDF para shared
executar pipeline
obter resultado

Exemplo de fluxo:

/srv/toolbox/shared/documento.pdf
↓
run-job pdf-ocr documento.pdf

---

## Diretório secrets

/srv/toolbox/secrets

Armazena credenciais e arquivos sensíveis utilizados pela toolbox.

Esse diretório é montado como read-only dentro do container.

Exemplos:

credenciais do Google Translate
chaves de API
tokens de acesso

Arquivos nesse diretório nunca devem ser versionados em Git.

---

## Persistência de Dados

Os diretórios persistentes da toolbox são:

/srv/toolbox/jobs
/srv/toolbox/models
/srv/toolbox/shared
/srv/toolbox/secrets

O diretório app contém código versionado e pode ser reconstruído a partir do repositório.

---

## Resumo da Estrutura

Estrutura consolidada:

/srv/toolbox
├── app (código e documentação)
├── jobs (execuções de pipelines)
├── models (modelos grandes)
├── shared (troca de arquivos)
└── secrets (credenciais)

Essa organização garante separação clara entre código, dados e configurações sensíveis.

---
