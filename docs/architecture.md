# Arquitetura da Toolbox

## Visão Geral

A Toolbox é um subsistema do homelab projetado para funcionar como um ambiente Unix remoto especializado em processamento de documentos, imagens e texto.

A ideia central é criar um conjunto de ferramentas de linha de comando pequenas, reutilizáveis e combináveis, executadas dentro de um container Docker, evitando poluir o ambiente principal do sistema.

A toolbox segue explicitamente a filosofia Unix:

* ferramentas pequenas e especializadas
* composição de comandos
* transparência de execução
* reprodutibilidade dos processos

O sistema foi projetado para permitir tanto o uso interativo quanto a execução estruturada de pipelines de processamento.

---

## Princípios Arquiteturais

### Filosofia Unix

Cada comando deve fazer uma única tarefa bem definida.

Os comandos devem ser combináveis entre si para formar fluxos maiores de processamento.

Exemplo de composição:

pdf-images → img-convert → ocr → translate

---

### Separação de Responsabilidades

A arquitetura separa claramente:

* interface pública
* implementação das ferramentas
* pipelines compostos
* infraestrutura de execução

Essa separação reduz acoplamento e facilita evolução do sistema.

---

## Estrutura da CLI

A CLI da toolbox segue a seguinte organização:

bin/
Contém os comandos públicos executados diretamente pelo usuário.

scripts/helpers/
Implementação real das ferramentas atômicas.

scripts/pipelines/
Implementação de pipelines compostos.

scripts/lib/
Funções reutilizáveis compartilhadas.

---

## Ferramentas Atômicas

Ferramentas atômicas executam uma única operação.

Exemplos atuais:

ocr
Executa OCR em uma imagem usando Tesseract.

translate
Traduz texto usando a API do Google Translate.

pdf-images
Extrai páginas de um PDF como imagens.

pdf-text
Extrai texto existente de um PDF pesquisável.

img-convert
Converte e redimensiona imagens usando ImageMagick.

exif
Inspeciona ou remove metadados de imagens.

---

## Pipelines

Pipelines são fluxos compostos que orquestram múltiplas ferramentas.

Eles ficam em scripts/pipelines.

Exemplo atual:

pdf-ocr

Fluxo interno:

PDF
↓
pdf-images
↓
ocr
↓
concatenação de texto
↓
text.txt

---

## Execução Estruturada com Jobs

Pipelines são executados através do comando run-job.

Cada execução cria um diretório estruturado:

/toolbox/jobs/<job-id>/

Estrutura típica:

input/
work/
output/
log.txt
status
meta.env

Isso garante rastreabilidade e reprodutibilidade.

---

## Ambiente de Execução

A toolbox roda em um container Docker contendo ferramentas especializadas:

Tesseract — OCR
ImageMagick — manipulação de imagens
Poppler — utilidades de PDF
ExifTool — manipulação de metadados
man-db — sistema de manpages
groff — renderização de manpages

---

## Documentação

A documentação segue o padrão Unix de manpages:

docs/man1 — comandos de usuário
docs/man7 — visão geral do sistema

Exemplos:

man ocr
man pdf-images
man toolbox

---

## Evolução Futura

A toolbox deverá evoluir para incluir:

pipelines compostos mais avançados
ferramentas de NLP
extração estruturada de dados
automação de pipelines
interface HTTP opcional

---

