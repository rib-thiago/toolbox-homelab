# MODELO OURO FINAL — STOCKHAUSEN EDITION NO. 12: STIMMUNG

## 1. Objetivo

Este documento define o modelo ouro operacional e arquivístico utilizado como referência para futuras normalizações da coleção Stockhausen-Verlag.

O álbum escolhido como baseline canônico é:

```text
012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}
```

Localização:

```text
/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form/012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}
```

O objetivo deste modelo é transformar a política abstrata definida em:

```text
stockhausen_metadata_policy.md
```

em estrutura concreta de filesystem, metadata e organização.

---

# 2. Estrutura Arquivística

## 2.1 Estrutura canônica

```text
1967-79: Live Electronics - Intuitive Music - Formula Form/
└── 012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}/
    ├── cover.jpg
    ├── Artwork/
    ├── CD1/
    └── CD2/
```

---

## 2.2 Filosofia da estrutura

A estrutura deve preservar simultaneamente:

- período histórico;
- agrupamento musicológico;
- estrutura editorial;
- separação física dos discos;
- organização operacional dos players.

---

# 3. Política de Diretórios

## 3.1 Diretório principal

Formato:

```text
NNN Stockhausen - Título (Ano) {Informação editorial}
```

Exemplo:

```text
012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}
```

---

## 3.2 Estrutura multi-CD

A separação física dos discos é semanticamente relevante.

Portanto:

```text
CD1
CD2
```

devem permanecer explicitamente separados.

---

# 4. Política de Filenames

## 4.1 Filosofia geral

A política adotada é:

```text
filesystem simples
+
metadata semanticamente rica
```

O filesystem NÃO deve duplicar excessivamente informações já preservadas nas tags.

---

## 4.2 Estrutura final dos filenames

Formato:

```text
NN - Movimento/Subdivisão.flac
```

Exemplos:

```text
01 - Einstimmen und 1. Kombination B.flac
02 - Kombination A: Vishnu.flac
03 - Kombination SII: 'moon's day'/'Mond-Tag' Tangaroa.flac
```

---

## 4.3 Remoção de prefixos redundantes

Quando o campo:

```text
Title
```

contiver:

```text
Obra: subdivisão
```

o filename deve preservar apenas:

```text
subdivisão
```

Exemplo:

### Tag Title

```text
Stimmung (Pariser Version 1969): Einstimmen und 1. Kombination B
```

### Filename

```text
01 - Einstimmen und 1. Kombination B.flac
```

A obra permanece preservada em:

- Album;
- metadata;
- contexto do release.

---

# 5. Política de Metadata

# 5.1 AlbumArtist

Valor canônico:

```text
Karlheinz Stockhausen
```

Objetivo:

- navegação limpa;
- compatibilidade com Navidrome;
- compatibilidade com Feishin;
- compatibilidade com Amperfy;
- evitar fragmentação da biblioteca.

---

## 5.2 Artist

Valor canônico:

```text
Karlheinz Stockhausen
```

Objetivo:

- evitar multiplicação artificial de artistas;
- evitar poluição da navegação;
- manter coerência operacional.

---

## 5.3 Composer

Valor canônico:

```text
Karlheinz Stockhausen
```

A coleção Stockhausen-Verlag é tratada como corpus composicional primário do compositor.

Co-autorias futuras poderão ser adicionadas mediante validação documental.

---

## 5.4 Performer

Performers devem ser preservados semanticamente.

Exemplo:

```text
Collegium Vocale Köln
```

Essas informações devem ser movidas para:

```text
Performer
```

e NÃO permanecer em:

```text
AlbumArtist
```

---

## 5.5 Album

Valor canônico:

```text
Stockhausen Edition, no. 12: Stimmung
```

O valor atual proveniente do MusicBrainz é considerado semanticamente adequado e editorialmente consistente.

---

## 5.6 Title

A política adotada é:

```text
Track Title = subdivisão/movimento real
```

Exemplos:

```text
Kombination A: Vishnu
Kombination SI: Usi-afu
Kombination TII: Uranos
```

Essas subdivisões são consideradas semanticamente importantes e NÃO devem ser simplificadas.

---

## 5.7 Grouping

Valor canônico:

```text
1967-79: Live Electronics - Intuitive Music - Formula Form
```

Objetivo:

- preservar agrupamento histórico;
- preservar organização musicológica;
- facilitar futuras navegações temáticas.

---

## 5.8 Genre

A coleção NÃO definirá inicialmente taxonomia rígida de gênero.

Política atual:

- preservar se existir;
- evitar simplificações prematuras;
- evitar taxonomias populares inadequadas.

Taxonomia futura poderá ser construída posteriormente.

---

## 5.9 Datas

Valores atuais:

```text
Date = 1993
OriginalDate = 1993
```

mantidos até enriquecimento musicológico posterior.

---

# 6. Política de Artwork

## 6.1 Estrutura em camadas

A política adotada é:

```text
camada operacional
+
camada arquivística
```

---

## 6.2 Camada operacional

Para players:

```text
cover.jpg
```

leve e otimizado.

---

## 6.3 Camada arquivística

Materiais completos preservados em:

```text
Artwork/
```

incluindo:

- scans;
- encartes;
- booklets;
- imagens históricas;
- material gráfico raro.

---

## 6.4 Embedding

A coleção NÃO pretende embedar integralmente o acervo gráfico nos arquivos FLAC.

Apenas capas operacionais mínimas deverão ser utilizadas.

---

## 6.5 Pipeline futuro de artwork

Pipeline futuro previsto:

```text
Artwork/
→ compressão inteligente
→ WebP/JPEG otimizado
→ preservação archival
```

Objetivos:

- reduzir uso de disco;
- preservar qualidade visual;
- manter acervo gráfico;
- preparar preservação futura.

---

# 7. Política de MusicBrainz

## 7.1 Papel do MusicBrainz

MusicBrainz é tratado como:

```text
fonte auxiliar de enriquecimento
```

e NÃO autoridade absoluta.

---

## 7.2 Preservação de MBIDs

Todos os:

- MusicBrainzAlbumId;
- MusicBrainzTrackId;
- MusicBrainzReleaseTrackId;
- MusicBrainzReleaseGroupId;

devem ser preservados integralmente.

---

# 8. Política Operacional

## 8.1 Normalização supervisionada

Toda normalização deve ser:

- auditável;
- reversível;
- não destrutiva;
- baseada em relatórios;
- baseada em dry-run.

---

## 8.2 Ordem de normalização

Ordem recomendada:

1. filenames;
2. AlbumArtist;
3. Artist;
4. Composer;
5. Grouping;
6. Performer;
7. artwork;
8. enriquecimento futuro.

---

## 8.3 Filosofia geral

O modelo ouro busca equilibrar:

```text
navegação simples
+
metadata rica
+
preservação arquivística
```

sem sacrificar:

- ergonomia;
- musicologia;
- estrutura editorial;
- consistência operacional.
