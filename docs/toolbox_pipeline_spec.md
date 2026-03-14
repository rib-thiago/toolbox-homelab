# Especificação de Pipelines da Toolbox

Este documento define o padrão arquitetural e as convenções obrigatórias para a implementação de pipelines dentro da toolbox.

O objetivo é garantir consistência entre pipelines, facilitar manutenção futura e assegurar que todos os pipelines funcionem corretamente com o executor run-job.

---

1. O que é um Pipeline

Um pipeline é um fluxo composto de processamento que combina múltiplas ferramentas da toolbox para produzir um resultado final.

Diferentemente das ferramentas atômicas, que executam uma única operação, pipelines representam processos mais complexos e estruturados.

Exemplo de pipeline existente:

pdf-ocr

Fluxo conceitual:

PDF
↓
pdf-images
↓
ocr
↓
concatenação
↓
text.txt

Pipelines devem ser implementados como scripts Bash localizados em:

scripts/pipelines/

---

2. Execução de Pipelines

Pipelines não são executados diretamente pelo usuário.

Eles são executados através do comando:

run-job

Exemplo:

run-job pdf-ocr documento.pdf

O comando run-job é responsável por:

criar o diretório do job
copiar arquivos de entrada
registrar logs
monitorar estado da execução
armazenar resultados finais

---

3. Estrutura de um Job

Cada execução de pipeline gera um diretório em:

/toolbox/jobs/<job-id>

Estrutura típica:

input/
arquivos fornecidos como entrada

work/
arquivos intermediários

output/
resultados finais

log.txt
registro completo da execução

status
estado atual do job

meta.env
metadados da execução

---

4. Interface de um Pipeline

Todo pipeline deve receber um único argumento obrigatório:

JOB_ROOT

Esse diretório contém toda a estrutura do job.

Exemplo de inicialização padrão:

JOB_ROOT="${1:?missing JOB_ROOT}"

A partir dele são derivados os diretórios internos.

INPUT_DIR="${JOB_ROOT}/input"
WORK_DIR="${JOB_ROOT}/work"
OUTPUT_DIR="${JOB_ROOT}/output"
LOG_FILE="${JOB_ROOT}/log.txt"
STATUS_FILE="${JOB_ROOT}/status"

---

5. Controle de Status

Todo pipeline deve registrar seu estado no arquivo:

status

Estados possíveis:

running
success
failed

Inicialização típica:

echo "running" > "${STATUS_FILE}"

Em caso de erro:

echo "failed" > "${STATUS_FILE}"

Em caso de sucesso:

echo "success" > "${STATUS_FILE}"

---

6. Convenção de Logging

Pipelines devem registrar eventos importantes no arquivo:

log.txt

Função padrão recomendada:

log() {
printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}

Eventos que devem ser logados:

início do pipeline
arquivo de entrada
etapas importantes
execução de ferramentas externas
finalização

---

7. Tratamento de Erros

Pipelines devem falhar explicitamente quando algo inesperado ocorre.

Função recomendada:

fail() {
log "ERROR: $*"
echo "failed" > "${STATUS_FILE}"
exit 1
}

Exemplos de falhas detectáveis:

arquivo de entrada inexistente
ferramenta obrigatória ausente
nenhum resultado produzido

---

8. Uso de Ferramentas da Toolbox

Pipelines devem utilizar comandos públicos da toolbox sempre que possível.

Exemplo correto:

/toolbox/app/bin/pdf-images

Não é recomendado chamar diretamente ferramentas externas quando já existe um comando da toolbox.

Exemplo incorreto:

pdftoppm

Exemplo correto:

pdf-images

Isso garante desacoplamento da implementação.

---

9. Arquivos Intermediários

Arquivos temporários devem ser gravados em:

work/

Arquivos finais devem ser gravados em:

output/

Nenhum pipeline deve escrever resultados finais fora do diretório output.

---

10. Estrutura Básica de um Pipeline

Um pipeline típico segue a sequência:

inicialização
validação de dependências
detecção de entradas
execução das etapas
verificação de resultados
consolidação final

Essa estrutura deve ser mantida para garantir consistência entre pipelines.

---

11. Exemplo Simplificado

Estrutura típica:

inicializar status
validar ferramentas necessárias
identificar arquivos de entrada
executar ferramentas auxiliares
processar resultados intermediários
gerar saída final
marcar status como success

---

12. Boas Práticas

Todo pipeline deve:

usar set -euo pipefail
registrar logs relevantes
validar dependências externas
produzir saída clara e previsível
usar ferramentas públicas da toolbox sempre que possível

---

13. Evolução Futura

Pipelines futuros devem seguir este padrão para garantir compatibilidade com o sistema de jobs da toolbox.

Exemplos planejados:

image-ocr-translate
pdf-ocr-translate

Esses pipelines reutilizarão ferramentas existentes como:

ocr
translate
pdf-images
img-convert

---
