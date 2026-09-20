# Tickteira — Desafio Fullstack

## a) Como executar

```bash
docker compose up --build
```

| Serviço | URL |
|---|---|
| Web (suporte) | http://localhost:3000 |
| API | http://localhost:3001 (`GET /health`) |
| Mailpit (e-mails) | http://localhost:8025 |
| Postgres (host) | localhost:5433 (`tickteira`/`tickteira`) |

Migrations e seed rodam sozinhos (serviço `migrate`). O `.env` é opcional: os defaults
estão no `docker-compose.yml`.

## b) Tecnologias e o porquê
## c) Desenho da solução
## d) Modos de falha
## e) Trade-offs
## f) Testes realizados
## g) A decisão do e-mail
## h) O que faria diferente com mais tempo
