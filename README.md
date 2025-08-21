# Gitflow Versioning Action

Ação do GitHub para versionamento semântico automatizado baseada em uma estratégia simples no estilo Gitflow.

Esta ação composta ajuda você a:
- Gerar tags de desenvolvimento (pré-release) a partir de main/master com um padrão previsível.
- Manter branches de manutenção no formato `MAJOR.x`.
- Criar releases de patch a partir de branches `MAJOR.x`.
- Finalizar um ciclo de desenvolvimento promovendo a versão de desenvolvimento atual para uma tag estável.
- Gerar e atualizar automaticamente o arquivo `CHANGELOG.md` quando aplicável.

Importante: Esta ação empurra tags e também pode realizar commits no branch (para atualizar o `CHANGELOG.md`) dependendo do fluxo. Certifique-se de conceder as permissões corretas no workflow.

## Estratégia de Tagging

- Em main/master:
  - Detecta a última tag estável do repositório (padrão numérico, ex: `1.4.2`).
  - Calcula a próxima base de minor para a nova linha de release como `MAJOR.(MINOR+1).0`.
  - Garante que o branch de manutenção `MAJOR.x` exista (cria e faz push se estiver ausente).
  - Cria e faz push de uma tag de desenvolvimento: `dev-<BASE_VERSION>-<N>-rc`, onde `<BASE_VERSION>` é `MAJOR.(MINOR+1).0` e `<N>` é uma sequência incremental iniciando em 0.

- Em branches `MAJOR.x` (ex: `1.x`):
  - Encontra a última tag que corresponda a `MAJOR.*`.
  - Incrementa o número de patch e cria uma nova tag de patch: `MAJOR.MINOR.<next_patch>`.
  - Gera/atualiza o `CHANGELOG.md` com as mudanças desde a última tag estável e realiza um commit automático nesse branch antes de criar a nova tag.

- Quando executada com `mode: package` (Finalizar pacote):
  - Recalcula a base atual de desenvolvimento como em main/master.
  - Mantém apenas a tag `dev-<BASE_VERSION>-*-rc` mais recente para aquela base, removendo tags de dev mais antigas para a mesma linha `MAJOR.MINOR` (local e no remoto).
  - Gera/atualiza o `CHANGELOG.md` e cria uma tag estável `MAJOR.MINOR.PATCH` baseada na base atual.

Observações:
- A ação depende das tags existentes no seu repositório para determinar as próximas versões.
- Tags e commits do `CHANGELOG.md` são enviados para `origin`. Garanta que o workflow tenha permissões e que o checkout seja feito com histórico completo.

## Inputs

- `mode` (obrigatório, padrão: `auto`)
  - `auto`: comportamento normal (main/master cria tags de dev; `MAJOR.x` cria tags de patch e atualiza o changelog)
  - `package`: finaliza o ciclo atual e cria uma tag estável (também atualiza o changelog)

## Requisitos

- Faça checkout do repositório antes de usar esta ação, com histórico completo (para obter todas as tags):
  - `uses: actions/checkout@v4` com `fetch-depth: 0`.
- O workflow deve ter permissão para push de tags e commits:
  - `permissions: contents: write`.
- O repositório precisa permitir a criação de branches `MAJOR.x` a partir do fluxo em main/master (a ação criará e fará push se não existirem).

## Exemplos de Uso

### Workflow único para Auto e Finalizar

Use um workflow para lidar com o tagging de desenvolvimento/patch (em push) e a finalização manual (workflow_dispatch).

```yaml
name: Versionamento - All-in-One

on:
  push:
    branches:
      - main
      - master
      - "[0-9]+.x"  # ex.: 1.x, 2.x
  workflow_dispatch:

permissions:
  contents: write

jobs:
  version-auto:
    if: ${{ github.event_name == 'push' }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Versioning Action (auto)
        uses: bhcosta90/gitflow-versioning-action@1.0.0
        with:
          mode: auto

  finalize:
    if: ${{ github.event_name == 'workflow_dispatch' }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Versioning Action (package)
        uses: bhcosta90/gitflow-versioning-action@1.0.0
        with:
          mode: package
```

Dica: ao testar localmente no próprio repositório, você também pode referenciar a ação via caminho relativo `uses: .` dentro de um workflow neste mesmo repositório.

## Como Funciona (Internos)

A ação (action.yaml) executa:
- Configuração do Git para o usuário bot (`github-actions`).
- Busca todas as tags e detecta o branch atual.
- Em main/master:
  - Encontra a última tag estável numérica (`[0-9]*`), calcula a próxima base minor, garante `MAJOR.x` e cria a tag `dev-<BASE>-<seq>-rc`.
- Em `MAJOR.x`:
  - Calcula o próximo patch `MAJOR.MINOR.<next_patch>`, gera/atualiza `CHANGELOG.md` com `scripts/generate_changelog.sh` e faz commit/push, depois cria e envia a nova tag.
- Com `mode: package`:
  - Mantém apenas a dev tag mais recente da base atual, limpa as antigas, gera/atualiza `CHANGELOG.md`, cria a tag estável `MAJOR.MINOR.PATCH` e envia tudo.

## Solução de Problemas

- Nenhuma tag encontrada: a ação começará a partir de `0.0.0` como base.
- Permissão negada ao enviar: verifique `permissions: contents: write` e se o token possui direitos no branch alvo.
- Tags ausentes ou detecção incorreta: garanta `fetch-depth: 0` no checkout para que todas as tags fiquem disponíveis localmente.
- Conflito ao atualizar CHANGELOG: se houver proteção de branch ou exigência de PR, ajuste o fluxo (por exemplo, execute em `MAJOR.x` com permissões adequadas) pois a ação faz commits diretos para atualizar o `CHANGELOG.md`.

## Licença

MIT (ou a licença deste repositório, se diferente).
