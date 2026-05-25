# Toolbox Shell Environment Policy

## Objetivo

Este documento define a política oficial do ambiente shell operacional da Toolbox e do homelab.

O objetivo é:

- melhorar ergonomia operacional;
- reduzir atrito;
- padronizar aliases;
- padronizar funções;
- melhorar observabilidade;
- melhorar produtividade em SSH/Tailscale;
- evitar drift do ambiente shell;
- preservar simplicidade operacional.

---

# Filosofia Geral

O ambiente shell da Toolbox é:

- shell-first;
- terminal-first;
- SSH-friendly;
- mobile-friendly;
- Unix-oriented;
- operacionalmente simples.

Prioridades:

1. velocidade operacional;
2. previsibilidade;
3. legibilidade;
4. compatibilidade remota;
5. baixo atrito.

---

# Shell Oficial

Shell principal:

```text
bash
```

A Toolbox NÃO assume:

- zsh;
- fish;
- oh-my-zsh;
- frameworks pesados.

---

# Arquitetura Modular

O ambiente shell utiliza arquitetura modular baseada em:

```text
~/.bashrc.d/
~/.bash_aliases.d/
```

Objetivos:

- organização;
- separação de responsabilidades;
- crescimento incremental;
- redução de drift;
- facilidade de manutenção.

A modularização é:

- simples;
- shell-native;
- sem frameworks externos.

---

# Estrutura Oficial

## ~/.bashrc

Responsável por:

- bootstrap;
- compatibilidade Ubuntu;
- sourcing modular;
- inicialização do shell interativo.

O `.bashrc` NÃO deve conter longos blocos operacionais diretamente.

---

## ~/.bashrc.d/

Configurações modulares do shell.

### Estrutura atual

```text
10-toolbox-helpers.sh
20-path.sh
30-ergonomics.sh
40-modern-cli.sh
```

---

## Responsabilidades

### 10-toolbox-helpers.sh

Funções operacionais:

- tb()
- tbox()

---

### 20-path.sh

Responsável por:

- PATH Toolbox;
- path_append();
- PATH idempotente.

---

### 30-ergonomics.sh

Responsável por:

- history;
- less;
- MANPAGER;
- shell options;
- ergonomia geral.

---

### 40-modern-cli.sh

Responsável por:

- zoxide;
- starship.

---

# ~/.bash_aliases

O arquivo `~/.bash_aliases` funciona apenas como:

```text
índice + bootstrap
```

Ele:

- documenta módulos;
- explica responsabilidades;
- carrega `~/.bash_aliases.d/*.sh`.

---

# ~/.bash_aliases.d/

Responsável pelos aliases e funções modulares.

---

# Estrutura Atual

```text
10-basic.sh
20-listing.sh
30-network.sh
40-system.sh
50-dev.sh
60-docker.sh
70-git.sh
80-services.sh
80-functions.sh
90-homelab.sh
95-jobs.sh
99-misc.sh
```

---

# Responsabilidades

## 10-basic.sh

Aliases básicos:

- navegação;
- datas;
- fc;
- reload;
- edição de config.

---

## 20-listing.sh

Listagem:

- exa;
- ll;
- lt;
- la.

---

## 30-network.sh

Rede e segurança:

- ips;
- ss;
- tailscale;
- ufw.

---

## 40-system.sh

Sistema:

- df;
- du;
- storage.

---

## 50-dev.sh

Ferramentas de desenvolvimento:

- python;
- venv;
- mkx.

---

## 60-docker.sh

Docker e compose.

---

## 70-git.sh

Git.

---

## 80-services.sh

Systemd.

---

## 80-functions.sh

Funções reutilizáveis gerais.

---

## 90-homelab.sh

Navegação e helpers do homelab.

---

## 95-jobs.sh

Jobs/background:

- j;
- tf;
- nf;
- psg;
- k9;
- kj().

---

## 99-misc.sh

Diversos:

- journalctl;
- starship-theme;
- misc helpers.

---

# Filosofia de PATH

## Objetivo

Evitar:

- caminhos absolutos excessivos;
- wrappers desnecessários;
- duplicações no PATH;
- drift operacional.

---

# Política de PATH

Scripts operacionais da Toolbox devem preferencialmente ser executáveis diretamente.

---

# PATH Idempotente

O shell utiliza:

```bash
path_append()
```

para evitar duplicações durante:

```bash
source ~/.bashrc
```

ou:

```bash
reload
```

Objetivo:

```text
múltiplos reloads não devem duplicar PATH
```

---

# Filosofia de Aliases

Aliases devem:

- reduzir atrito operacional;
- acelerar tarefas repetitivas;
- preservar clareza;
- preservar muscle memory operacional.

Evitar aliases:

- excessivamente obscuros;
- criptográficos;
- incompatíveis com scripts.

---

# Alias vs Função

## Alias

Usado para:

```text
substituição textual simples
```

Exemplo:

```bash
alias mkx='chmod +x'
```

---

## Função

Usada quando há:

- parâmetros;
- lógica;
- múltiplas etapas.

Exemplo:

```bash
bashcheck() {
    bash -n "$1"
    echo $?
}
```

---

## Script Toolbox

Usado para:

- pipelines;
- automações maiores;
- geração de relatórios;
- tarefas reutilizáveis;
- workflows completos.

Local oficial:

```text
/srv/toolbox/app/scripts/
```

---

# Jobs e Background

O shell deve facilitar:

- nohup;
- jobs;
- tail -f;
- background execution;
- long-running tasks.

---

# Convenções de Jobs

## Execução background

Padrão:

```bash
nf script.sh > live.log 2>&1 &
```

---

## Monitoramento

Preferência:

```bash
tf logfile
```

---

## Jobs ativos

Preferência:

```bash
j
```

---

# Filosofia de Observabilidade

O shell deve permitir rapidamente observar:

- espaço em disco;
- jobs;
- containers;
- rede;
- memória;
- carga;
- logs.

Preferência por:

- aliases simples;
- funções leves;
- comandos Unix padrão.

---

# Filosofia de Nano

Nano é considerado:

```text
editor operacional oficial
```

para:

- SSH;
- Tailscale;
- mobile;
- manutenção rápida;
- scripts.

---

# Política de Nano

Preferências:

- line numbers;
- mouse support;
- softwrap;
- syntax highlighting;
- backups;
- UTF-8.

---

# Política de Starship

Starship deve:

- melhorar legibilidade;
- indicar contexto operacional;
- indicar diretório;
- indicar jobs;
- indicar status.

Evitar:

- excesso visual;
- poluição;
- lentidão.

---

# Política de History

Histórico shell é considerado ferramenta operacional importante.

Preferências:

- timestamps;
- append history;
- history grande;
- fc ergonomics.

---

# Política de fc

O comando:

```bash
fc -s
```

é considerado parte importante da ergonomia operacional.

Especialmente para:

- substituições rápidas;
- reruns;
- correções;
- workflows shell.

---

# Política de Mobile SSH

O ambiente shell deve funcionar bem em:

- Termius;
- SSH móvel;
- Tailscale;
- terminais pequenos.

Evitar:

- dependência excessiva de TUI;
- layouts gigantes;
- outputs excessivamente decorativos.

---

# Política de Simplicidade

O shell environment NÃO deve evoluir para:

- frameworks shell pesados;
- plugin managers complexos;
- abstrações enterprise;
- dependências frágeis.

Prioridade:

```text
shell operacional simples e robusto
```

---

# Política de toolbox-dev

Existe intenção futura de evolução para:

```text
toolbox-dev
```

como camada operacional shell/dev/admin.

Mas:

- incrementalmente;
- sem ruptura;
- sem complexidade prematura.

---

# Filosofia Final

O ambiente shell da Toolbox existe para:

- reduzir atrito;
- acelerar operações;
- facilitar automação;
- melhorar observabilidade;
- tornar o homelab operacionalmente confortável.

O objetivo NÃO é:

```text
transformar o shell em brinquedo visual
```

O objetivo é:

```text
criar um ambiente operacional eficiente, previsível e agradável para trabalho contínuo
```
