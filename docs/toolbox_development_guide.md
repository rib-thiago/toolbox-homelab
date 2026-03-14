# Guia de Desenvolvimento da Toolbox

Este documento descreve como desenvolver novas ferramentas, pipelines e componentes para a toolbox. Ele estabelece um fluxo de trabalho consistente para expansão do sistema e garante que novas funcionalidades respeitem a arquitetura e as convenções definidas.

O objetivo é permitir que qualquer desenvolvedor — inclusive você mesmo no futuro — consiga adicionar novos comandos sem quebrar o padrão do sistema.

---

1. Objetivo do Guia

Este guia explica como:

criar uma nova ferramenta atômica
criar um novo pipeline
adicionar um comando público
criar uma manpage
testar novas funcionalidades
manter consistência arquitetural

Ele deve ser seguido sempre que novas funcionalidades forem adicionadas à toolbox.

---

2. Tipos de Componentes da Toolbox

A toolbox possui três tipos principais de componentes.

Ferramentas atômicas
Pipelines
Infraestrutura

Cada tipo possui um fluxo de desenvolvimento específico.

---

3. Criando uma Nova Ferramenta Atômica

Ferramentas atômicas executam uma única tarefa específica.

Exemplos existentes:

ocr
translate
pdf-images
pdf-text
img-convert
exif

Essas ferramentas são implementadas em:

scripts/helpers/

---

3.1 Criar o Script da Ferramenta

Primeiro passo: criar o script de implementação.

Local:

scripts/helpers/

Exemplo:

scripts/helpers/minha-ferramenta.sh

Esse script deve conter toda a lógica real da ferramenta.

Todo script deve iniciar com:

#!/usr/bin/env bash
set -euo pipefail

Isso garante execução segura.

---

3.2 Criar o Comando Público

Depois da implementação, deve-se criar um comando público em:

bin/

Exemplo:

bin/minha-ferramenta

Esse comando deve ser um wrapper fino.

Exemplo de wrapper:

#!/usr/bin/env bash
set -euo pipefail
exec /toolbox/app/scripts/helpers/minha-ferramenta.sh "$@"

Esse padrão mantém separação entre interface pública e implementação.

---

3.3 Tornar o Script Executável

Após criar os arquivos:

chmod +x scripts/helpers/minha-ferramenta.sh
chmod +x bin/minha-ferramenta

---

4. Criando um Pipeline

Pipelines são fluxos compostos que combinam múltiplas ferramentas.

Exemplo existente:

pdf-ocr

Pipelines ficam em:

scripts/pipelines/

---

4.1 Criar Script do Pipeline

Local:

scripts/pipelines/

Exemplo:

scripts/pipelines/meu-pipeline.sh

Todo pipeline deve receber como argumento:

JOB_ROOT

Esse diretório contém toda a estrutura de execução.

---

4.2 Estrutura Básica de Pipeline

Todo pipeline deve derivar os seguintes caminhos:

INPUT_DIR
WORK_DIR
OUTPUT_DIR
LOG_FILE
STATUS_FILE

Exemplo:

JOB_ROOT="${1:?missing JOB_ROOT}"

INPUT_DIR="${JOB_ROOT}/input"
WORK_DIR="${JOB_ROOT}/work"
OUTPUT_DIR="${JOB_ROOT}/output"
LOG_FILE="${JOB_ROOT}/log.txt"
STATUS_FILE="${JOB_ROOT}/status"

---

4.3 Controle de Status

Todo pipeline deve atualizar o estado do job.

Inicialização:

echo "running" > "${STATUS_FILE}"

Erro:

echo "failed" > "${STATUS_FILE}"

Sucesso:

echo "success" > "${STATUS_FILE}"

---

4.4 Logging

Pipelines devem registrar eventos importantes.

Função recomendada:

log() {
printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}

Isso facilita debugging e rastreamento de execução.

---

4.5 Uso de Ferramentas da Toolbox

Pipelines devem utilizar comandos públicos sempre que possível.

Exemplo correto:

/toolbox/app/bin/pdf-images

Exemplo incorreto:

pdftoppm

Isso mantém desacoplamento da implementação.

---

5. Criando uma Manpage

Toda ferramenta pública deve possuir uma manpage.

As manpages ficam em:

docs/man1

---

5.1 Nome da Manpage

O nome deve seguir o padrão:

comando.1

Exemplos:

ocr.1
pdf-images.1
img-convert.1

---

5.2 Estrutura Básica da Manpage

Uma manpage normalmente possui as seções:

NAME
SYNOPSIS
DESCRIPTION
OPTIONS
EXAMPLES
SEE ALSO

Isso segue o padrão tradicional do Unix.

---

5.3 Testando a Manpage

Após criar a manpage, ela pode ser testada com:

man pdf-images

Ou diretamente:

man ./docs/man1/pdf-images.1

---

6. Testando Novas Ferramentas

Antes de considerar uma funcionalidade concluída, é necessário testar:

exibição de help
execução real
integração com outros comandos
comportamento em erros

É recomendado criar um diretório de teste em:

/srv/toolbox/shared

Exemplo:

/srv/toolbox/shared/pdf-images-test

Isso permite testar sem interferir em outros dados.

---

7. Convenções de Código

Todos os scripts devem seguir algumas regras.

Sempre usar:

set -euo pipefail

Sempre validar argumentos de entrada.

Sempre fornecer opção:

-h

Sempre produzir mensagens de erro claras.

---

8. Commits

Mudanças devem ser registradas em commits claros e descritivos.

Formato recomendado:

tipo(escopo): descrição

Exemplos:

feat(toolbox): adicionar comando pdf-images
refactor(toolbox): fazer pipeline pdf-ocr reutilizar pdf-images
docs(toolbox): adicionar manpage para img-convert

Isso facilita histórico e manutenção futura.

---

9. Fluxo Completo de Desenvolvimento

Fluxo típico ao criar uma nova ferramenta:

1. criar script em scripts/helpers
2. criar wrapper em bin
3. adicionar opção -h
4. escrever manpage
5. testar funcionalidade
6. validar comportamento
7. registrar commit

Esse fluxo garante consistência entre todas as ferramentas da toolbox.

---

10. Evolução do Sistema

À medida que a toolbox crescer, novas ferramentas e pipelines devem continuar seguindo as convenções descritas neste guia.

Isso garante que o sistema permaneça organizado, previsível e fácil de manter.

---

