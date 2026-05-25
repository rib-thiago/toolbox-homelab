# Toolbox Storage Policy

## Objetivo

Este documento define a política oficial de armazenamento da Toolbox e do homelab.

O objetivo é:

- controlar crescimento;
- reduzir desperdício;
- separar camadas operacionais;
- preservar material importante;
- evitar saturação do storage principal;
- facilitar backup e archival.

---

# Filosofia Geral

A arquitetura de storage da Toolbox é baseada em:

- separação por camadas;
- storage quente/frio;
- staging;
- archival;
- curadoria incremental;
- preservação racional.

A Toolbox NÃO assume:

```text
todo dado precisa permanecer online
```

A Toolbox assume:

```text
dados possuem temperaturas diferentes
```

---

# Camadas de Storage

## Hot Storage

Dados acessados frequentemente.

Características:

- baixo tempo de acesso;
- online permanentemente;
- usados por serviços ativos;
- utilizados por players e automações.

Exemplos:

```text
FLACs principais
cover.jpg
configs Docker
scripts
bancos SQLite ativos
```

---

## Warm Storage

Dados usados ocasionalmente.

Exemplos:

```text
relatórios antigos
datasets intermediários
exports TSV
manifests
```

---

## Cold Storage

Dados raramente acessados.

Exemplos:

```text
artwork otimizado
archives .7z
snapshots antigos
exports históricos
```

Cold storage pode residir:

- localmente;
- em HDD externo;
- em pendrive;
- em cloud;
- em backup Restic.

---

## Archival Storage

Dados preservados por valor histórico/curatorial.

Características:

- acesso raro;
- retenção longa;
- não necessariamente online;
- organizados para preservação.

---

# Política de Música

## Filosofia

A biblioteca musical é considerada:

```text
acervo curado
```

e não apenas coleção casual de arquivos.

---

# Política de FLAC

## FLAC master

Manter apenas:

```text
uma cópia canônica
```

Evitar:

- duplicação de formatos;
- múltiplos transcodes persistentes;
- mirrors desnecessários.

---

## Transcoding

Preferência por:

```text
transcoding sob demanda
```

Exemplo:

- Navidrome;
- ffmpeg;
- Opus;
- AAC;
- MP3 temporário.

---

# Política de Artwork

## Hot layer

Apenas:

```text
cover.jpg
```

Objetivo:

- Navidrome;
- Feishin;
- Amperfy;
- players.

---

## Artwork scans

Booklets/scans completos NÃO devem permanecer no hot storage.

---

## Cold Artwork Archive

Artwork completo deve ser:

- otimizado;
- convertido;
- compactado;
- movido para cold storage.

Formato preferencial:

```text
WebP
```

Empacotamento preferencial:

```text
7z
```

---

# Política de Compressão

Compressão agressiva é aceitável quando:

- o objetivo é consulta eventual;
- não há valor patrimonial extremo;
- não há necessidade de preservation master.

---

## Filosofia

A Toolbox prioriza:

```text
eficiência operacional
```

sobre:

```text
preservação maximalista irracional
```

---

# Política de Diretórios

## Mídia principal

```text
/srv/media/
```

---

## Toolbox operacional

```text
/srv/toolbox/
```

---

## Compose/services

```text
/srv/compose/
```

---

# Política de Crescimento

O homelab assume crescimento contínuo de:

- mídia;
- artwork;
- relatórios;
- snapshots;
- backups;
- SQLite;
- metadata.

Portanto:

- tiering é obrigatório;
- cold archive é obrigatório;
- pruning ocasional é esperado.

---

# Política de Snapshots

Snapshots devem:

- ser baratos;
- textuais;
- compactáveis;
- versionáveis.

Evitar snapshots binários gigantes.

---

# Política de Backup

## Filosofia

Backup prioriza:

- configuração;
- metadata;
- curadoria;
- manifests;
- estrutura.

Não necessariamente:

```text
todas as mídias brutas
```

---

# Política de Storage Externo

Storage externo é considerado parte oficial da arquitetura.

Exemplos:

- HDD USB;
- pendrive archival;
- cloud storage;
- Restic repository.

---

# Política de Temporary Data

Dados temporários devem preferencialmente viver em:

```text
/srv/toolbox/jobs/
```

ou:

```text
/tmp
```

---

# Política de Jobs

Jobs longos devem:

- evitar explosão de storage;
- evitar duplicação desnecessária;
- produzir manifests;
- permitir cleanup posterior.

---

# Política de Deduplicação

Deduplicação é útil apenas quando:

- ganho real é significativo;
- complexidade adicional compensa.

Evitar overengineering de dedupe.

---

# Política de Storage Pressure

Uso acima de:

```text
85%
```

já deve ser tratado como alerta operacional.

Ações preferenciais:

1. cold archive;
2. compressão;
3. pruning;
4. externalização;
5. cleanup;
6. expansão física.

---

# Política de Formats

## Preferências gerais

| Tipo | Preferência |
|---|---|
| áudio master | FLAC |
| áudio streaming | Opus/AAC |
| artwork archive | WebP |
| relatórios | TXT |
| datasets | TSV |
| archives | 7z |

---

# Política de Simplicidade

Evitar:

- NAS complexos;
- storage distribuído prematuro;
- dedupe enterprise;
- sistemas enterprise desnecessários.

Prioridade:

```text
simplicidade operacional
```

---

# Filosofia Final

Storage não é infinito.

A Toolbox assume:

- curadoria;
- hierarquia;
- temperatura;
- archival;
- compressão racional;
- externalização gradual.

O objetivo não é:

```text
guardar tudo online para sempre
```

O objetivo é:

```text
manter um acervo sustentável, auditável e operacionalmente saudável
```
