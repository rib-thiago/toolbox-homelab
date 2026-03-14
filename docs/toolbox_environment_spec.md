# Especificação do Ambiente da Toolbox

Este documento descreve o ambiente de execução necessário para a toolbox funcionar corretamente. Seu objetivo é registrar, de forma explícita, as dependências de sistema, as convenções de ambiente e os componentes obrigatórios para operação da toolbox dentro do homelab.

Ele existe para facilitar reconstrução do ambiente, troubleshooting, portabilidade futura e compreensão das dependências reais do sistema.

---

1. Objetivo do Documento

A toolbox depende de um conjunto específico de ferramentas instaladas no container Docker. Embora essas dependências estejam refletidas no Dockerfile, este documento registra seu papel conceitual dentro do sistema.

Este documento responde perguntas como:

quais ferramentas são obrigatórias
quais ferramentas são usadas por cada comando
quais variáveis de ambiente são necessárias
quais diretórios precisam existir
quais componentes fazem parte da experiência Unix da toolbox

---

2. Ambiente Base

A toolbox roda em um container Docker construído a partir de:

python:3.11-slim

Essa imagem base foi escolhida por:

ser leve
oferecer ambiente Python moderno
facilitar instalação de bibliotecas e ferramentas de processamento

O container é executado com volumes persistentes montados a partir do host e faz parte da rede Docker do homelab.

---

3. Dependências de Sistema Obrigatórias

A toolbox depende das seguintes ferramentas de sistema instaladas via apt.

### bash

Usado como shell principal para scripts e wrappers da toolbox.

Necessário para:

execução de helpers
execução de pipelines
wrappers em bin/

---

### tesseract-ocr

Motor de OCR principal da toolbox.

Necessário para:

ocr
pdf-ocr

Pacotes de idioma atualmente instalados:

tesseract-ocr-eng
tesseract-ocr-por
tesseract-ocr-rus

---

### poppler-utils

Conjunto de utilitários para manipulação de PDFs.

Necessário para:

pdf-images
pdf-text
pdf-ocr

Ferramentas relevantes:

pdftoppm
pdftotext

---

### imagemagick

Utilitário de manipulação e conversão de imagens.

Necessário para:

img-convert

Também poderá ser usado futuramente em pipelines de limpeza de imagem para OCR.

---

### ghostscript

Dependência útil para processamento de documentos e compatibilidade com certos fluxos envolvendo PDF e imagem.

Pode ser usada em evoluções futuras da toolbox.

---

### libimage-exiftool-perl

Pacote que fornece o comando:

exiftool

Necessário para:

exif

---

### libmagic1

Biblioteca para detecção de tipos de arquivo.

Atualmente é uma dependência útil para futuras evoluções e integrações Python.

---

### man-db

Fornece o comando:

man

Necessário para:

visualização local das manpages da toolbox

---

### groff

Ferramenta de renderização de manpages.

Necessário para:

renderização das páginas em formato roff/groff

---

### git

Utilizado para versionamento do repositório da toolbox dentro do ambiente de desenvolvimento.

---

### curl

Ferramenta de rede genérica útil para diagnósticos e automações futuras.

---

### ca-certificates

Necessário para conexões seguras com serviços externos, especialmente integrações HTTP e APIs.

---

4. Dependências Python

A toolbox utiliza dependências Python instaladas a partir de:

docker/requirements.txt

Essas dependências suportam principalmente:

integração com serviços externos
scripts auxiliares
evoluções futuras da toolbox

Em especial, a integração de tradução depende de bibliotecas Python relacionadas ao Google Translate.

---

5. Variáveis de Ambiente Relevantes

O ambiente da toolbox utiliza variáveis de ambiente para comportamento e integração.

### PATH

A imagem define:

/toolbox/app/bin

dentro do PATH.

Isso permite executar os comandos públicos diretamente no shell do container.

Exemplos:

ocr
pdf-images
pdf-text
img-convert
exif
pdf-ocr

---

### MANPATH

A imagem define um MANPATH apontando para a documentação local da toolbox.

Isso permite usar:

man ocr
man pdf-images
man toolbox

sem precisar passar o caminho completo do arquivo.

---

### GOOGLE_APPLICATION_CREDENTIALS

Define o caminho da credencial utilizada para integração com Google Translate.

Essa variável é necessária para:

translate

---

### GOOGLE_TRANSLATE_TARGET_LANG

Define o idioma de destino padrão usado pelo comando translate.

---

6. Diretórios Obrigatórios no Container

A toolbox assume a existência dos seguintes diretórios montados no container:

/toolbox/app
código versionado da toolbox

/toolbox/jobs
diretórios de execução de pipelines

/toolbox/models
modelos e artefatos grandes

/toolbox/shared
área de troca de arquivos entre host e container

/toolbox/secrets
credenciais e segredos montados como somente leitura

---

7. Integração entre Ferramentas e Comandos

A seguir estão as dependências principais por comando.

### ocr

Dependência principal:

tesseract-ocr

---

### translate

Dependência principal:

bibliotecas Python do Google Translate
credencial em /toolbox/secrets
variáveis de ambiente associadas

---

### pdf-images

Dependência principal:

pdftoppm
fornecido por poppler-utils

---

### pdf-text

Dependência principal:

pdftotext
fornecido por poppler-utils

---

### img-convert

Dependência principal:

ImageMagick
comando magick

---

### exif

Dependência principal:

exiftool
fornecido por libimage-exiftool-perl

---

### pdf-ocr

Combina:

pdf-images
ocr

E, indiretamente, depende de:

poppler-utils
tesseract-ocr

---

8. Suporte à Documentação Unix

A toolbox incorpora um ambiente local de documentação em estilo Unix.

As manpages ficam organizadas em:

docs/man1
docs/man7

O suporte a documentação local depende de:

man-db
groff
MANPATH configurado corretamente

Isso faz parte da proposta da toolbox como ambiente operacional de linha de comando, e não apenas como coleção de scripts.

---

9. Reprodutibilidade do Ambiente

Para que a toolbox possa ser reconstruída corretamente, os seguintes elementos são essenciais:

Dockerfile atualizado
requirements.txt atualizado
volumes corretamente montados
variáveis de ambiente configuradas
segredos disponíveis em /toolbox/secrets

Sem esses componentes, comandos podem deixar de funcionar mesmo que o código da toolbox esteja presente.

---

10. Considerações Finais

Este ambiente deve ser tratado como parte fundamental da arquitetura da toolbox.

A toolbox não é apenas um conjunto de scripts Bash: ela depende de um ecossistema técnico específico, instalado e configurado dentro do container.

Documentar esse ambiente é importante para:

reconstrução futura
migração para outro host
manutenção
debugging
continuidade do projeto

---
