# Convenções da CLI da Toolbox

Este documento define as regras de criação de comandos.

---

## Tipos de Comando

Existem três categorias.

Ferramentas atômicas
Pipelines
Comandos de infraestrutura

---

## Ferramentas Atômicas

Executam uma única tarefa.

Exemplos:

ocr
translate
pdf-images
pdf-text
img-convert
exif

---

## Pipelines

Fluxos compostos.

Exemplo:

pdf-ocr

Pipelines utilizam run-job.

---

## Infraestrutura

Comandos responsáveis por execução estruturada.

Exemplo:

run-job

---

## Estrutura de Diretórios

bin/ — interface pública
scripts/helpers/ — implementação de ferramentas
scripts/pipelines/ — pipelines
scripts/lib/ — funções compartilhadas

---

## Padrão de Wrapper

Comandos em bin/ devem ser wrappers finos.

Exemplo:

bin/pdf-images chama scripts/helpers/pdf-images.sh

---

## Padrão de Pipeline

Pipelines devem ser wrappers para run-job.

Exemplo:

bin/pdf-ocr chama run-job pdf-ocr

---

## Convenção de Nome

Comandos devem seguir o padrão:

verbo-objeto

Exemplos:

pdf-images
img-convert
text-translate

---

## Segurança de Scripts

Todos os scripts devem iniciar com:

set -euo pipefail

---

## Logging

Pipelines devem registrar logs no diretório do job.

log.txt

---

## Documentação

Cada comando público deve possuir:

help via -h
manpage em docs/man1

Documentação sistêmica fica em docs/man7.

---

