# Roadmap da Toolbox

Este documento descreve a evolução planejada da toolbox.

---

## Fase 1 — Ferramentas Fundamentais

Objetivo: estabelecer uma base sólida de ferramentas Unix para processamento documental.

Ferramentas implementadas:

ocr
translate
pdf-images
pdf-text
img-convert
exif

Pipeline:

pdf-ocr

Infraestrutura:

run-job
estrutura de jobs
documentação via manpages
container dedicado

Status: concluída.

---

## Fase 2 — Pipelines Compostos

Objetivo: demonstrar composição de ferramentas existentes.

Pipeline planejado:

image-ocr-translate

Fluxo:

imagem
↓
ocr
↓
translate
↓
texto traduzido

Outro pipeline planejado:

pdf-ocr-translate

Fluxo:

PDF
↓
pdf-images
↓
ocr
↓
translate

---

## Fase 3 — Toolkit de NLP

Objetivo: adicionar processamento linguístico local.

Possíveis ferramentas:

text-tokenize
text-language-detect
text-summary
text-keywords

Possíveis bibliotecas:

spaCy
HuggingFace
modelos locais

---

## Fase 4 — Utilidades Avançadas

Expansão da toolbox como ambiente geral de processamento.

Ferramentas possíveis:

file-detect
batch-run
dataset-normalize
metadata-extract

---

## Fase 5 — Interface HTTP

Possível exposição da toolbox como serviço.

Funcionalidades:

API REST
submissão de jobs
consulta de status
download de resultados

---

## Fase 6 — CLI Unificada

Introdução de um comando principal:

toolbox

Exemplos:

toolbox ocr imagem.png
toolbox pdf text arquivo.pdf
toolbox translate texto.txt

---

