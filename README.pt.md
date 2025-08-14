# Gitflow Versioning Action

Automatiza versionamento no estilo Git Flow com criação incremental de tags e atualização opcional do CHANGELOG.md.

Esta Action cria tags para ciclos de desenvolvimento (dev), séries de release e finalização de pacotes, além de manter branches auxiliares (develop/{major}x, release/{major}x) conforme necessário.

## Sumário
- O que esta Action faz
- Pré‑requisitos e permissões
- Entradas (inputs)
- Modos de execução (mode)
- Exemplos de uso (workflows)
- Convenções de branches e tags
- Dicas e resolução de problemas

## O que esta Action faz
- Gera automaticamente tags com base no histórico de tags existente.
- Mantém o padrão de versionamento semântico (MAJOR.MINOR.PATCH) para releases.
- Cria tags de desenvolvimento pré‑release no formato dev-MAJOR.MINOR.PATCH.
- Cria/garante branches auxiliares develop/{major}x e release/{major}x quando aplicável.
- Atualiza o arquivo CHANGELOG.md ao finalizar um pacote (opcional, via input).
- Remove tags dev-* quando uma release é finalizada.

## Pré-requisitos e permissões
- O repositório deve usar tags semânticas para releases no formato X.Y.Z (apenas números e pontos) para que a detecção da "última release" funcione.
- Esta Action usa git para:
  - criar e empurrar tags;
  - criar e empurrar branches;
  - commitar alterações no CHANGELOG.md (quando aplicável).
- Garanta que o GITHUB_TOKEN (ou token de checkout) tenha permissão de escrita em conteúdos:
  
  permissions:
    contents: write

- Esta Action já inclui um passo de checkout com fetch-depth: 0 para acessar todo o histórico, o que é necessário para ler tags antigas. Se você sobreescrever o checkout em seu workflow, mantenha fetch-depth: 0.

## Entradas (inputs)
- mode (obrigatório): define o modo de execução. Valores suportados: 
  - dev, dev-branch, release-branch, finalize-package, finalize-release, release-patch, develop-patch
- branch (opcional): nome base usado em dev-branch e release-branch (por exemplo: "feature/login" ou "release/1x").
- changelog_entry (opcional): texto a ser adicionado no CHANGELOG.md ao usar finalize-package.

Não há outputs definidos por esta Action.

## Modos de execução (mode)
A seguir, um resumo do comportamento de cada modo.

1) dev
- Calcula a próxima tag de desenvolvimento com base na última tag de release X.Y.Z.
- Regras:
  - Se não houver release anterior, assume 0.0 como base.
  - Incrementa o MINOR da última release e gerencia PATCH sequencial para dev.
  - Formato: dev-MAJOR.MINOR.PATCH
- Exemplo: se última release for 1.4.2, próxima dev será dev-1.5.0 (ou dev-1.5.N conforme existentes).

2) dev-branch
- Cria tags incrementais baseadas no valor de "branch" informado.
- Formato: {branch}.{patch}
- Exemplo: branch=feature/login → feature/login.0, feature/login.1, ...

3) release-branch
- Similar ao dev-branch, mas tipicamente usado para branches de release.
- Formato: {branch}.{patch}
- Exemplo: branch=release/1x → release/1x.0, release/1x.1, ...

4) finalize-package
- Define a próxima tag de release final:
  - Se não existir release anterior: 0.0.0
  - Caso exista: mantém o MAJOR, incrementa MINOR e zera PATCH → MAJOR.(MINOR+1).0
- Se changelog_entry for fornecido:
  - Adiciona seção "## X.Y.Z (YYYY-MM-DD)" no CHANGELOG.md, com o conteúdo informado.
  - Faz commit e push dessa alteração na branch atual.
- Cria/garante a branch develop/{major}x correspondente ao MAJOR da release.
- Remove todas as tags dev-* (local e remoto).

5) finalize-release
- Cria a primeira tag de uma nova série de MAJOR:
  - Se não existir release anterior: cria 1.0.0
  - Caso exista: new_major = último MAJOR + 1 → new_major.0.0
- Cria a branch de release release/{branch_major}x, onde branch_major é o MAJOR da série anterior.
- Garante a branch develop/{new_major}x para a nova série.
- Remove todas as tags dev-* e apaga branches remotas antigas develop/*, exceto a nova develop/{new_major}x.

6) release-patch
- Para ser usado em branches release/{major}x.
- Lê o MAJOR a partir do nome da branch (ex.: release/1x → 1).
- Encontra a última tag 1.*.* e incrementa o PATCH.
- Cria e empurra a nova tag 1.MINOR.PATCH.

7) develop-patch
- Para ser usado em branches develop/{major}x.
- Incrementa PATCH dentro da série do MAJOR atual, baseando-se na última tag encontrada para essa série.
- Observação: o script tenta inferir a série pela última tag  {series}.*. Caso seja a primeira vez, ele inicia do patch 0.

Nota: Alguns comportamentos dependem do histórico de tags e da branch atual do checkout.

## Exemplos de uso (workflows)
Início rápido: workflow mínimo integrando esta Action (espelha .github/workflows/gitflow.yaml)

```yaml
name: Git Flow Automation
on:
  push:
    branches: [main, master, 'hotfix/*', 'release/*']
  workflow_dispatch:
    inputs:
      mode:
        description: 'Choose Action mode'
        required: true
        type: choice
        options: [finalize-package, finalize-release]
        default: finalize-package

jobs:
  gitflow:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: {fetch-depth: 0}
      - name: Run Gitflow Versioning
        uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.mode || github.ref == 'refs/heads/main' && 'dev' || startsWith(github.ref, 'refs/heads/hotfix') && 'hotfix-patch' || startsWith(github.ref, 'refs/heads/release') && 'release-patch' }}
          changelog_entry: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.changelog_entry || '' }}
```

Abaixo um workflow completo que cobre cenários comuns:

name: Git Flow Automation

on:
  push:
    branches:
      - main
      - 'develop/*'
      - 'release/*'
  workflow_dispatch:
    inputs:
      mode:
        description: 'Choose Action mode'
        required: true
        type: choice
        options:
          - finalize-package
          - finalize-release
        default: finalize-package
      changelog_entry:
        description: 'Notas para CHANGELOG'
        required: false

jobs:
  dev-tag:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: dev

  develop-patch:
    if: contains(github.ref, 'refs/heads/develop/')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: develop-patch

  release-patch:
    if: contains(github.ref, 'refs/heads/release/')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: release-patch

  workflow-dispatch:
    if: github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: ${{ github.event.inputs.mode }}
          changelog_entry: ${{ github.event.inputs.changelog_entry }}

### Outros exemplos
- Gerar tag para uma branch arbitrária (dev-branch):

jobs:
  tag-feature:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: dev-branch
          branch: feature/login

- Gerar tag para uma branch de release específica (release-branch):

jobs:
  tag-release-branch:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: release-branch
          branch: release/1x

- Finalizar pacote com atualização de changelog (finalize-package):

jobs:
  finalize:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: bhcosta90/gitflow-versioning-action@v1
        with:
          mode: finalize-package
          changelog_entry: |
            - feat: novo endpoint /metrics
            - fix: corrige NPE em OrderService

## Convenções de branches e tags
- Releases: tags no formato X.Y.Z (apenas dígitos e pontos).
- Dev tags: dev-MAJOR.MINOR.PATCH.
- Branches de desenvolvimento: develop/{major}x (ex.: develop/1x, develop/2x).
- Branches de release: release/{major}x (ex.: release/1x, release/2x).

## Dicas e resolução de problemas
- Permissões insuficientes:
  - Erros ao empurrar tags/commits normalmente indicam falta de permissions.contents: write.
- Histórico de tags não encontrado:
  - Garanta fetch-depth: 0 no checkout (já configurado internamente por esta Action).
- Conflitos no CHANGELOG.md:
  - Se múltiplos jobs tentarem escrever no CHANGELOG simultaneamente, serialize as execuções ou restrinja o gatilho.
- "tag already exists":
  - Indica que a tag foi criada por outro job/execução. Re-rodar pode gerar o próximo patch automaticamente, dependendo do modo.
- Branch atual não corresponde ao modo:
  - release-patch deve rodar em release/{major}x, develop-patch em develop/{major}x. Ajuste as condições do workflow.

## Desenvolvimento
- Makefile inclui alvos auxiliares:
  - make date: grava data/hora no arquivo version e faz commit/push.
  - make delete-tag version=MAJOR.MINOR: remove todas as tags que iniciam com esse prefixo (ex.: 1.2.*).

## Licença
Este repositório segue a licença definida pelo autor. Consulte o arquivo LICENSE se disponível.

## Autor
- bhcosta90