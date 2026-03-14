# Guia de Operação da Toolbox

Este documento explica como operar o ambiente da toolbox.

---

## Acessando o Container

Para entrar no ambiente da toolbox:

docker exec -it toolbox bash

---

## Executando Comandos

Os comandos públicos estão em:

/toolbox/app/bin

Exemplo:

ocr imagem.png

---

## Execução de Pipelines

Pipelines utilizam execução estruturada via run-job.

Exemplo:

run-job pdf-ocr documento.pdf

Isso cria um diretório de execução em:

/toolbox/jobs/<job-id>

---

## Estrutura de um Job

Cada job contém:

input/ — arquivos de entrada
work/ — arquivos intermediários
output/ — resultados finais
log.txt — log completo da execução
status — estado da execução

---

## Consultando Resultados

Texto extraído:

cat /toolbox/jobs/<job-id>/output/text.txt

Verificar log:

cat log.txt

Verificar status:

cat status

Estados possíveis:

running
success
failed

---

## Diretório Compartilhado

Arquivos podem ser colocados em:

/toolbox/shared

Esse diretório é montado do host para dentro do container.

---

## Atualizando o Container

Para reconstruir a imagem:

docker compose build
docker compose up -d

---

## Consultando Documentação

man ocr
man pdf-images
man pdf-text
man toolbox

---

