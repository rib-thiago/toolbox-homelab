# Toolbox Runtime Profiles

## 1. Objetivo

Este documento define os runtimes e os perfis Docker planejados para a Toolbox.

A Toolbox será tratada como uma plataforma operacional híbrida, com dois modos principais de execução:

* `host-mode`;
* `container-mode`.

Esses modos não são definidos pelo tipo de arquivo processado. Um PDF, uma imagem, um FLAC, um CUE ou um texto podem ser processados no host ou no container. A diferença principal é o tipo de relação que o processo tem com o ambiente.

Regra geral:

* usar `host-mode` quando o script precisa observar, auditar ou modificar o estado vivo do homelab;
* usar `container-mode` quando o processo pode ser encapsulado em entrada, trabalho intermediário e saída reprodutível.

Este documento também define a direção futura dos perfis Docker da Toolbox:

* `toolbox-base`;
* `toolbox-docs`;
* `toolbox-media`;
* `toolbox-nlp`.

A criação desses perfis é uma frente prioritária futura, especialmente `toolbox-media`, mas não deve ser feita sem diagnóstico, plano, aplicação e validação próprios.

## 2. Decisão arquitetural

A decisão arquitetural aprovada é:

A Toolbox será tratada como plataforma híbrida host/container, em que o container permanece para processamento encapsulado e reprodutível, enquanto o host é o runtime principal para diagnósticos, administração e curadoria de acervos vivos.

Essa decisão preserva o racional original da Toolbox, mas incorpora a prática operacional que emergiu no homelab, especialmente durante a saga Stockhausen.

## 3. host-mode

`host-mode` é o modo de execução em que scripts rodam diretamente no host do homelab.

Esse modo deve ser usado quando o script precisa acessar o estado real do sistema.

Exemplos de estado real:

* `/srv`;
* `/srv/media`;
* `/srv/compose`;
* Docker daemon;
* UFW;
* Tailscale;
* Restic;
* Samba;
* Navidrome;
* FileBrowser;
* Git real;
* permissões reais;
* serviços reais;
* discos reais;
* paths reais da biblioteca.

## 4. Quando usar host-mode

Usar `host-mode` para:

* diagnósticos do homelab;
* auditorias de Docker;
* auditorias de rede;
* auditorias de storage;
* auditorias de firewall;
* rotinas de backup;
* inspeção de serviços;
* inventários de `/srv`;
* validação de permissões;
* validação de acervos vivos;
* scripts administrativos;
* rotina Git;
* curadoria musical sobre biblioteca canônica;
* importações reais para `/srv/media/music`;
* validações relacionadas ao Navidrome;
* validações relacionadas ao Samba;
* validações relacionadas ao FileBrowser;
* geração de reports administrativos;
* geração de snapshots do estado real.

## 5. Exemplos de host-mode

Exemplos de scripts ou famílias de scripts que pertencem naturalmente ao host-mode:

* `scripts/admin/system/*`;
* `scripts/admin/docker/*`;
* `scripts/admin/network/*`;
* `scripts/admin/storage/*`;
* `scripts/admin/backup/*`;
* `scripts/admin/firewall/*`;
* `scripts/admin/git/*`;
* diagnósticos de arquitetura da Toolbox;
* diagnósticos de outputs;
* diagnósticos de Git;
* scripts de validação do homelab;
* workflows Stockhausen que alteram ou validam `/srv/media/music`;
* workflows de importação para biblioteca canônica.

## 6. container-mode

`container-mode` é o modo de execução em que processos rodam dentro de containers da Toolbox.

Esse modo deve ser usado quando a prioridade é:

* reprodutibilidade;
* isolamento de dependências;
* portabilidade;
* execução encapsulada;
* processamento sobre cópias ou staging;
* processamento com entrada e saída bem definidas.

O container-mode deve operar preferencialmente sobre:

* input controlado;
* staging;
* cópias;
* diretórios de job;
* `/toolbox/shared`;
* `/toolbox/jobs`;
* `input/`;
* `work/`;
* `output/`.

## 7. Quando usar container-mode

Usar `container-mode` para:

* OCR;
* processamento de PDF;
* processamento de imagem;
* extração de texto;
* conversão de formatos;
* NLP;
* pipelines encapsulados;
* jobs reprodutíveis;
* processamento de áudio em staging;
* split de FLAC+CUE em cópia;
* verificação de FLAC em cópia;
* conversão de artwork em cópia;
* extração de metadados sem alterar acervo canônico.

## 8. Exemplos de container-mode

Exemplos de comandos ou pipelines adequados ao container-mode:

* `ocr`;
* `pdf-text`;
* `pdf-images`;
* `img-convert`;
* `exif`;
* `pdf-ocr`;
* `image-ocr-translate`;
* futuro `audio-probe`;
* futuro `flac-verify`;
* futuro `cue-diagnose`;
* futuro `audio-cue-split`;
* futuro `artwork-convert`;
* futuro `metadata-extract`.

## 9. A distinção não é por tipo de mídia

A distinção entre host-mode e container-mode não deve ser feita com base apenas no tipo de arquivo.

Não é correto afirmar:

* PDF sempre vai para container;
* música sempre vai para host;
* imagem sempre vai para container;
* FLAC sempre vai para host.

A distinção correta é:

* se o processo atua sobre acervo vivo, serviços reais ou estado real do homelab, tende a ser host-mode;
* se o processo atua sobre entrada controlada, cópia, staging ou job encapsulado, tende a ser container-mode.

Exemplo:

* OCR de um PDF isolado: container-mode;
* inventário de `/srv/media/pdfs`: host-mode;
* split de FLAC+CUE em staging: container-mode possível;
* importação do resultado para `/srv/media/music`: host-mode;
* conversão de artwork em cópia: container-mode possível;
* purge de `Artwork/` dentro da biblioteca canônica: host-mode.

## 10. Relação com run-job

`run-job` continua válido.

Ele deve ser usado para tarefas encapsuladas, com:

* input claro;
* output claro;
* diretório de job;
* status;
* log;
* workdir;
* baixa necessidade de decisão humana no meio.

Exemplos:

* `pdf-ocr`;
* `image-ocr-translate`;
* futuro `audio-cue-split`;
* futuro `flac-verify`;
* futuro `artwork-convert`.

`run-job` não é o padrão universal da Toolbox.

Ele é um mecanismo de execução para tarefas encapsuladas.

## 11. run-job dentro de workflows operacionais

Um workflow operacional pode chamar `run-job` como subetapa.

Modelo:

1. `diagnose`;
2. `plan`;
3. `run-job` para etapa encapsulada;
4. `validate` do output do job;
5. `apply` no estado vivo, se aprovado;
6. `validate` do estado vivo.

Exemplo futuro para áudio:

1. `diagnose-album-staging.sh`;
2. `plan-cue-split.sh`;
3. `run-job audio-cue-split`;
4. `validate-cue-split-output.sh`;
5. `plan-import.sh`;
6. `apply-import-to-library.sh`;
7. `validate-library-import.sh`.

Nesse modelo:

* `run-job` processa uma unidade encapsulada;
* o workflow operacional decide, audita, aplica e valida.

## 12. Workflow operacional

Workflow operacional é o modelo preferencial quando há risco, acervo vivo ou decisão humana entre fases.

Fluxo padrão:

diagnose → plan → apply → validate

Extensões possíveis:

* repair;
* resume;
* freeze;
* snapshot;
* purge;
* import;
* split.

Usar workflow operacional quando houver:

* risco de perda ou alteração difícil de reverter;
* biblioteca canônica;
* muitos arquivos;
* metadados complexos;
* necessidade de TSV de plano;
* snapshot antes do apply;
* validação independente;
* necessidade de revisão humana;
* possibilidade de interrupção;
* necessidade de retomar;
* necessidade de auditoria.

## 13. Perfis Docker planejados

A Toolbox deve evoluir para perfis ou imagens Docker especializadas.

Perfis planejados:

* `toolbox-base`;
* `toolbox-docs`;
* `toolbox-media`;
* `toolbox-nlp`.

Essa divisão deve facilitar:

* auditoria;
* separação de dependências;
* manutenção;
* rebuilds menores;
* clareza de runtime;
* migração futura;
* reprodutibilidade por domínio.

## 14. toolbox-base

`toolbox-base` deve ser a imagem base comum.

Conteúdo esperado:

* shell;
* coreutils;
* bash;
* git;
* curl;
* ferramentas Unix essenciais;
* man-db;
* groff;
* less;
* documentação;
* estrutura comum `/toolbox`.

Função:

* fornecer base comum para outras imagens;
* manter documentação Unix;
* preservar identidade da Toolbox;
* evitar duplicação estrutural.

`toolbox-base` não deve conter todas as ferramentas de todos os domínios.

## 15. toolbox-docs

`toolbox-docs` deve ser o perfil de documentos, PDF, OCR e imagem.

Base:

* `toolbox-base`.

Ferramentas esperadas:

* Tesseract;
* Poppler;
* ImageMagick;
* Ghostscript;
* ExifTool;
* Python documental;
* bibliotecas necessárias para OCR/PDF/imagem.

Uso esperado:

* OCR;
* extração de texto;
* extração de imagens;
* conversão de imagem;
* processamento de PDF;
* pipelines documentais.

Exemplos:

* `ocr`;
* `pdf-text`;
* `pdf-images`;
* `img-convert`;
* `exif`;
* `pdf-ocr`;
* `image-ocr-translate`.

O container atual da Toolbox se aproxima mais de `toolbox-docs` do que de uma imagem universal.

## 16. toolbox-media

`toolbox-media` deve ser o perfil de mídia, áudio e curadoria arquivística em staging.

Base:

* `toolbox-base`.

Ferramentas candidatas:

* ffmpeg;
* ffprobe;
* flac;
* metaflac;
* shntool;
* shnsplit;
* cuetools;
* cuebreakpoints;
* cueprint;
* cuetag;
* sox;
* fpcalc;
* id3v2;
* mid3v2;
* ferramentas de metadata.

Uso esperado:

* análise de áudio;
* validação de FLAC;
* split de FLAC+CUE;
* diagnóstico de CUE;
* extração de metadados;
* conversão de artwork;
* processamento de mídia em staging;
* jobs encapsulados de mídia.

`toolbox-media` é prioridade de implementação tão logo a documentação e o plano de implementação sejam aprovados.

`toolbox-media` não deve substituir automaticamente workflows host-mode que operam sobre acervos vivos.

Regra:

* processar em staging/cópia no container;
* aplicar no acervo vivo pelo host-mode, quando necessário.

## 17. toolbox-nlp

`toolbox-nlp` deve ser o perfil futuro de processamento de linguagem natural.

Base possível:

* `toolbox-base`;
* ou `toolbox-docs`, se OCR/PDF/imagem forem pré-requisitos.

Ferramentas candidatas:

* Python NLP;
* spaCy;
* modelos de idioma;
* NLTK;
* embeddings;
* ferramentas de extração estruturada;
* OCR avançado;
* componentes futuros relacionados ao CraftText.

`toolbox-nlp` fica adiado até haver demanda concreta.

## 18. Serviços existentes do homelab

A criação ou reorganização dos perfis Docker da Toolbox não deve afetar serviços existentes do homelab.

Não deve afetar:

* Navidrome;
* Samba;
* FileBrowser;
* Nginx Proxy Manager;
* Backrest;
* Jellyfin;
* Immich;
* Calibre-Web;
* Kavita;
* slskd;
* monitoramento.

`toolbox-media` não é serviço de player musical.

`toolbox-media` não substitui Navidrome.

`toolbox-media` não deve modificar `/srv/media/music` diretamente em sua fase inicial.

## 19. FileBrowser

FileBrowser não é runtime da Toolbox.

Ele pode expor `/srv/toolbox/shared` de forma read-only para facilitar:

* revisão de reports;
* acesso a TSVs;
* troca de artefatos;
* comunicação assistida.

FileBrowser deve ser tratado como ferramenta auxiliar de acesso, não como container da Toolbox.

## 20. Manpages nos runtimes

Todos os perfis Docker devem preservar acesso à documentação da Toolbox.

A documentação canônica vive no repositório:

`/srv/toolbox/app/docs`

Nos containers, deve estar acessível em:

`/toolbox/app/docs`

O host também deve conseguir consultar as manpages da Toolbox.

A política exata de `MANPATH`, `tbman` ou wrapper equivalente será definida no documento de manpages.

## 21. scripts/lib nos runtimes

`scripts/lib` deve ser compatível com host-mode e container-mode sempre que possível.

A biblioteca comum deve evitar dependências desnecessárias do host ou do container.

Funções genéricas como `log()`, `fail()`, timestamps, TSV e paths devem ser portáveis.

Funções específicas de Docker, mídia ou administração devem ficar fora da base comum até haver plano próprio.

## 22. Critérios de decisão

Para decidir runtime, responder:

1. O script precisa observar o estado real do host?
2. O script altera biblioteca canônica?
3. O processo pode rodar sobre cópia ou staging?
4. As dependências precisam ser isoladas?
5. Há necessidade de input/work/output?
6. Há decisão humana entre fases?
7. O resultado precisa ser revisado antes de apply?
8. O script deve ser reprodutível em outro servidor?
9. O script depende de serviços reais do homelab?
10. O script é ferramenta atômica, pipeline ou workflow operacional?

## 23. Implementação futura

A implementação de perfis Docker deve seguir:

diagnose → plan → apply → validate

Antes de criar ou alterar imagens:

* inventariar Dockerfiles;
* inventariar Compose;
* inventariar ferramentas host/container;
* mapear scripts por domínio;
* mapear dependências;
* decidir nomes de imagens;
* decidir mounts;
* decidir manpaths;
* validar que serviços existentes não serão afetados.

## 24. Estado atual

Estado atual conhecido:

* host-mode já é usado para administração e curadoria Stockhausen;
* container atual sustenta OCR/PDF/imagem/documentos;
* `toolbox-media` ainda não existe;
* `toolbox-nlp` ainda não existe;
* `scripts/lib` existe como estrutura, mas está em processo de ser transformado em base comum real;
* política de outputs ainda está em consolidação;
* manpages devem ser tornadas acessíveis também no host.

## 25. Próximas frentes

Frentes imediatas relacionadas a runtime:

1. consolidar documentação;
2. criar `scripts/lib` mínimo;
3. implementar acesso host às manpages;
4. planejar `toolbox-base`;
5. planejar `toolbox-docs`;
6. planejar `toolbox-media`;
7. adiar `toolbox-nlp`;
8. validar que serviços existentes não serão afetados.
