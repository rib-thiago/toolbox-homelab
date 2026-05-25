# Stockhausen Metadata Policy

## 1. Objetivo

Este documento define a política arquivística, operacional e semântica utilizada para organização da coleção Karlheinz Stockhausen no homelab Toolbox.

A política busca equilibrar simultaneamente:

- fidelidade musicológica;
- preservação arquivística;
- ergonomia de navegação;
- compatibilidade com Navidrome, Feishin e Amperfy;
- padronização de metadata;
- enriquecimento futuro;
- estabilidade estrutural da biblioteca.

O objetivo NÃO é apenas “organizar arquivos FLAC”, mas construir uma coleção semanticamente consistente, operacionalmente utilizável e arquivisticamente sustentável.

---

# 2. Escopo da Coleção

## 2.1 Corpus principal

O corpus principal corresponde à coleção editorial Stockhausen-Verlag.

Este corpus é tratado como:

- coleção arquivística prioritária;
- referência canônica de organização;
- eixo principal de normalização;
- base para futuras automações.

Exemplos:

- Stockhausen-Verlag No. 1
- Stockhausen-Verlag No. 32
- Licht
- Klang
- Elektronische Musik
- Sirius
- Opern aus Licht

---

## 2.2 Materiais relacionados

Discos relacionados ao universo Stockhausen, mas que NÃO pertencem à coleção Stockhausen-Verlag, são tratados separadamente.

Exemplos:

- interpretações contemporâneas;
- gravações acadêmicas;
- tributos;
- performers especializados;
- coletâneas externas;
- gravações históricas independentes.

Exemplo concreto:

```text
Cosmic Clarinets (Michele Marelli, Gianluca Cascioli)
```

Esses materiais podem coexistir na biblioteca geral, mas NÃO devem interferir nas políticas do corpus principal Stockhausen-Verlag.

---

# 3. Estrutura Arquivística

## 3.1 Hierarquia da coleção

A estrutura arquivística oficial é:

```text
Coleção
→ período/era
→ release Stockhausen-Verlag
→ CD/disco
→ faixa
```

Exemplo:

```text
1977-95: Licht pt. 1
→ 032 Stockhausen - Musik für Klarinette, Baßklarinette, Bassetthorn
→ CD1
→ faixa
```

---

## 3.2 Estrutura filesystem

A estrutura atual do filesystem é considerada semanticamente válida e próxima do modelo canônico.

Ela NÃO é arbitrária.

A divisão por períodos foi inspirada principalmente em:

- The Stockhausen Edition CD Series;
- Stockhausen Space blog;
- documentação oficial da Stockhausen-Verlag.

Essa estrutura também funciona como:

- guia de escuta;
- agrupamento histórico;
- categorização musicológica;
- organização operacional da biblioteca.

---

## 3.3 Multi-CDs

Releases multi-CD devem preservar explicitamente a estrutura de discos.

Exemplo:

```text
CD1
CD2
CD3
```

A separação física dos discos é considerada semanticamente relevante e NÃO deve ser colapsada automaticamente.

---

# 4. Modelo Semântico

## 4.1 Distinção entre compositor e performer

A coleção diferencia explicitamente:

- compositor;
- performers;
- ensembles;
- regentes;
- intérpretes;
- formações históricas.

Entretanto, essa distinção NÃO deve prejudicar a ergonomia operacional dos players utilizados.

---

## 4.2 Eixo principal de navegação

Para compatibilidade operacional com:

- Navidrome;
- Feishin;
- Amperfy;

o campo:

```text
AlbumArtist
```

é tratado como eixo principal de navegação da coleção.

Para o corpus principal:

```text
AlbumArtist = Karlheinz Stockhausen
```

---

## 4.3 Política de Artist

Para evitar fragmentação excessiva da biblioteca nos players, o campo:

```text
Artist
```

também utilizará:

```text
Karlheinz Stockhausen
```

como valor principal no corpus Stockhausen-Verlag.

O objetivo é evitar:

- multiplicação artificial de artistas;
- poluição da lista de navegação;
- fragmentação do catálogo;
- inconsistência operacional entre players.

---

## 4.4 Política de Composer

O campo:

```text
Composer
```

deve utilizar:

```text
Karlheinz Stockhausen
```

como valor padrão da coleção.

Co-autorias futuras poderão ser adicionadas posteriormente durante fases de enriquecimento semântico, mediante validação documental.

---

## 4.5 Política de performers

Performers NÃO devem ser descartados.

Informações de performance devem ser preservadas semanticamente.

Exemplos:

- Suzanne Stephens;
- Kathinka Pasveer;
- Collegium Vocale Köln;
- Markus Stockhausen;
- Majella Stockhausen-Riegelbauer.

Essas informações poderão existir em:

- Performer;
- Ensemble;
- Comment;
- campos auxiliares futuros;
- enriquecimento posterior.

---

## 4.6 Filosofia operacional

A política geral da coleção é:

```text
navegação simplificada
+
metadata rica preservada
```

Ou seja:

```text
AlbumArtist = entidade intelectual principal
Artist      = entidade intelectual principal
```

sem perda das informações performáticas.

---

# 5. Política de Obras e Faixas

## 5.1 Filosofia geral

As subdivisões internas das obras são consideradas semanticamente importantes.

A coleção NÃO deve colapsar movimentos, atos, tomadas, seções ou subdivisões relevantes.

---

## 5.2 Política de títulos de faixa

A política adotada é:

```text
Track Title = movimento/subdivisão real
```

Exemplos válidos:

```text
Bar 1. Glocke und Eingang
Bar 2. Gruppensoli
```

Esses elementos são considerados parte essencial da estrutura musicológica da obra.

---

## 5.3 Obras completas

O nome completo da obra deve permanecer preservado em:

- Album;
- Work;
- metadata auxiliar futura;
- estrutura do release.

---

# 6. Política de Nomenclatura

## 6.1 Diretórios

A estrutura atual dos diretórios é considerada próxima do modelo oficial.

Exemplo:

```text
032 Stockhausen - Musik für Klarinette, Baßklarinette, Bassetthorn (1994) {3CD Set Stockhausen-Verlag No. 32}
```

Essa estrutura preserva simultaneamente:

- número editorial;
- compositor;
- título;
- ano;
- identificação da coleção;
- cardinalidade do release.

---

## 6.2 Filosofia de filenames

A política adotada é híbrida:

```text
filesystem simples
+
metadata semanticamente expressiva
```

Os filenames devem preservar:

- numeração;
- movimento;
- subdivisão relevante;
- legibilidade.

Sem redundância excessiva.

Exemplo desejado:

```text
01 - Bar 1. Glocke und Eingang.flac
02 - Bar 2. Gruppensoli.flac
```

---

# 7. Política de Grouping e Genre

## 7.1 Grouping

O campo:

```text
Grouping
```

deve representar:

```text
período/ciclo histórico
```

Exemplo:

```text
1977-95: Licht pt. 1
```

---

## 7.2 Genre

A coleção NÃO adotará imediatamente uma taxonomia rígida de gêneros.

A política atual é:

- preservar metadata existente;
- evitar normalização prematura;
- evitar taxonomias simplistas.

---

## 7.3 Taxonomia futura

Uma taxonomia própria poderá ser construída futuramente com base em:

- PDF/discografia;
- documentação oficial;
- musicologia;
- organização da coleção;
- ciclos composicionais;
- períodos históricos;
- técnicas composicionais.

---

# 8. Política de Artwork

## 8.1 Filosofia geral

Artworks possuem alto valor arquivístico e NÃO devem ser descartados.

A coleção preserva:

- scans;
- capas;
- encartes;
- booklets;
- materiais visuais raros;
- documentação gráfica associada.

---

## 8.2 Estratégia operacional

A política adotada é:

```text
camada operacional
+
camada arquivística
```

---

## 8.3 Camada operacional

Para uso cotidiano nos players:

- capas leves;
- imagens otimizadas;
- cover.jpg;
- artwork embutido mínimo.

---

## 8.4 Camada arquivística

Materiais completos permanecem preservados em:

```text
Artwork/
```

como acervo arquivístico independente.

---

## 8.5 Política de embedding

A coleção NÃO pretende embedar massivamente booklets e artworks completos nos arquivos FLAC.

Isso evitará:

- duplicação excessiva;
- aumento desnecessário de armazenamento;
- lentidão operacional;
- degradação de performance dos players.

---

## 8.6 Pipeline futuro de artwork

A coleção poderá futuramente implementar pipeline específico para:

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
- preparar integração futura com sistemas de preservação visual.

---

# 9. Política de Metadata

## 9.1 Fonte de verdade

A prioridade semântica das fontes é:

1. filesystem;
2. documentação oficial Stockhausen-Verlag;
3. PDF/discografia auxiliar;
4. MusicBrainz;
5. tags existentes.

---

## 9.2 Filesystem como fonte primária

O filesystem possui prioridade elevada porque:

- foi manualmente curado;
- incorpora decisões arquivísticas conscientes;
- preserva agrupamentos históricos;
- preserva organização editorial;
- já representa trabalho humano consolidado.

O filesystem NÃO deve ser tratado como mero detalhe técnico.

---

## 9.3 MusicBrainz

MusicBrainz é considerado:

```text
fonte auxiliar de enriquecimento
```

e NÃO autoridade absoluta.

Ausência de MBIDs NÃO implica baixa qualidade arquivística.

O corpus Stockhausen-Verlag possui particularidades que frequentemente não são bem representadas em bancos de metadata populares.

---

## 9.4 Tags existentes

Tags atuais devem ser tratadas com cautela.

Elas podem conter:

- metadata útil;
- metadata parcial;
- inconsistências;
- diferenças de filosofia catalográfica;
- resultados de múltiplos processos anteriores.

Nenhuma tag deve ser considerada automaticamente canônica sem validação contextual.

---

# 10. Política de Normalização

## 10.1 Princípio geral

Normalizações futuras devem ser:

- não destrutivas;
- reproduzíveis;
- auditáveis;
- reversíveis;
- registradas em relatórios.

---

## 10.2 Proibições

É proibido:

- sobrescrever metadata em massa sem backup;
- colapsar performers indiscriminadamente;
- apagar tags sem auditoria;
- alterar filesystem sem snapshot/relatório;
- aplicar MusicBrainz cegamente.

---

## 10.3 Estratégia operacional

A normalização ocorrerá em etapas:

1. inventário;
2. política canônica;
3. análise;
4. modelo ouro;
5. normalização controlada;
6. enriquecimento.

---

## 10.4 Grau de automação

A coleção utilizará:

```text
automação supervisionada
```

Toda automação futura deverá incluir:

- dry-run;
- relatórios;
- diffs;
- snapshots;
- confirmação manual.

---

## 10.5 Interface operacional futura

A Toolbox poderá futuramente implementar interface interativa/TUI para:

- visualizar metadata atual;
- visualizar metadata proposta;
- aprovar mudanças;
- rejeitar alterações;
- comparar diffs;
- aplicar normalizações controladas.

---

# 11. Estado Atual da Coleção

## 11.1 Situação geral

Análises automatizadas indicam que:

- o corpus NÃO apresenta corrupção sistêmica;
- a estrutura filesystem está consistente;
- títulos e releases estão majoritariamente íntegros;
- a coleção já possui significativa curadoria manual;
- parte relevante do acervo já passou por MusicBrainz/Picard.

---

## 11.2 Interpretação dos resultados

Os principais problemas detectados atualmente são:

- ausência de AlbumArtist;
- ausência de MBIDs;
- metadata parcial;
- diferenças performáticas legítimas.

Esses problemas NÃO caracterizam destruição ou caos arquivístico.

---

## 11.3 Conclusão operacional

A coleção encontra-se em estado estruturalmente saudável.

O desafio principal não é reconstrução de metadata, mas:

```text
refinamento arquivístico e enriquecimento semântico
```

---

# 12. Perspectivas Futuras

Etapas futuras poderão incluir:

- enriquecimento performático;
- modelagem de obras;
- identificação de ciclos composicionais;
- integração SQLite;
- dashboards;
- busca semântica;
- integração Toolbox;
- relatórios musicológicos;
- automação controlada de metadata;
- pipelines de artwork;
- políticas equivalentes para outros corpus (ex.: Sun Ra).

---

# 13. Filosofia Geral

A coleção deve ser tratada como:

```text
acervo arquivístico vivo
```

e NÃO apenas como biblioteca casual de arquivos de áudio.

O objetivo final é construir simultaneamente:

- coleção musicologicamente consistente;
- experiência operacional agradável;
- preservação semântica;
- navegabilidade eficiente;
- base sustentável para automação futura.
