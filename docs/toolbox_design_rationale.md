# Justificativa de Design da Toolbox

Este documento registra as decisões arquiteturais tomadas durante o desenvolvimento da toolbox.

Ele existe para explicar **por que certas decisões foram tomadas**, evitando perda de contexto no futuro.

---

## Por que usar um container dedicado

A toolbox executa ferramentas pesadas:

OCR
ImageMagick
PDF utilities
NLP no futuro

Isolar essas ferramentas em um container:

evita poluir o sistema principal
permite reproduzir o ambiente
facilita migração para outros hosts

---

## Por que usar ferramentas Unix

Ferramentas pequenas têm várias vantagens:

mais fáceis de testar
mais fáceis de reutilizar
mais fáceis de combinar

Isso permite criar pipelines poderosos a partir de peças simples.

---

## Por que separar helpers e pipelines

Separar essas duas coisas reduz ambiguidade:

helpers = operações simples
pipelines = orquestração

Isso facilita manutenção e evolução.

---

## Por que usar run-job

Execuções longas precisam ser rastreáveis.

run-job garante:

logs
status
estrutura consistente
reprodutibilidade

---

## Por que usar manpages

Manpages têm três vantagens:

documentação local
integração com ambiente Unix
consulta rápida no terminal

Isso reforça a ideia da toolbox como ambiente Unix real.

---

## Por que usar diretórios estruturados

A estrutura:

bin/
helpers/
pipelines/
lib/

permite crescimento sem perder organização.

---

## Evolução prevista

A toolbox deve evoluir para um ambiente completo de processamento documental.

Possíveis direções:

pipelines avançados
NLP local
extração de dados
interface HTTP
CLI unificada

---

Se quiser, no próximo passo posso também te mostrar **um padrão de estrutura de documentação ainda mais robusto usado em projetos grandes**, que tornaria esse seu homelab comparável à documentação de projetos open source profissionais.
