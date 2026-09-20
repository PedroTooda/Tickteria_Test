#!/usr/bin/env bash
# Falha se o domínio/aplicação importar framework ou infraestrutura.
set -euo pipefail
if grep -rEn "from '(@nestjs|@prisma|bullmq|ioredis|nodemailer|@tickteira/infra)" packages/core/src; then
  echo "ERRO: packages/core não pode depender de framework ou infra." >&2
  exit 1
fi
echo "Arquitetura OK: core está isolado."
