# Desafio Técnico — Fullstack | Tickteira

Você vai construir, do zero, o núcleo do nosso fluxo de venda: **da confirmação do
pagamento até o ingresso na mão do comprador** — e a tela que o time de suporte usa
quando algo falha.

Não há código de partida. O desenho é seu, inteiro.

Leia este arquivo inteiro **e a documentação do PagFácil (seção 4)** antes de começar.

---

## 1. Como entregar

1. Crie um repositório **público** na sua conta (ou faça fork deste, que contém apenas
   este enunciado).
2. Faça commits pequenos, com mensagens legíveis — vamos ler o histórico.
3. Escreva o **`README.md`** conforme a seção 7. Ele pesa na avaliação tanto quanto o código.
4. Envie o **link do repositório** para `[e-mail]` com o assunto
   "Desafio Fullstack — seu nome". Confirme antes que ele abre numa janela anônima —
   se estiver privado, não conseguimos avaliar.

---

## 2. O produto

A **Tickteira** vende ingressos para shows e eventos. O fluxo é:

1. O comprador monta o pedido no site → pedido criado, aguardando pagamento.
2. Ele paga no **PagFácil** (gateway terceiro).
3. O PagFácil nos avisa por **webhook**.
4. Confirmamos o pedido, emitimos os ingressos com QR code e enviamos por e-mail.

O passo 2 **não é escopo**. Você não vai integrar com gateway nenhum: nada de criar conta
no PagFácil (ele não existe), sandbox de gateway real, ngrok ou URL pública. Para exercitar
o fluxo, você mesmo dispara os webhooks — ver seção 5.

---

## 3. Kickoff (transcrição resumida)

> **Carla (Produto)** — o próximo grande é o show do dia 28. São 8 mil ingressos e a
> venda inteira acontece em uns 5 minutos. Depois o sistema fica praticamente ocioso até
> o próximo show. É esse o perfil de carga: platô e pico brutal.

> **Marcos (CTO)** — duas coisas que eu preciso que fiquem claras. Primeira: o PagFácil
> corta a conexão em 5 segundos, está na doc deles. Segunda: **leia a documentação deles
> inteira**, tem uma seção lá que já nos mordeu em outro projeto e ninguém tinha lido.

> **Financeiro** — o requisito inegociável do meu lado: compra estornada não pode ter
> ingresso válido na catraca. Já perdemos dinheiro com isso. E capacidade é capacidade:
> se o setor tem 400 lugares, saem 400 ingressos, nem um a mais. A gente responde
> judicialmente por isso.

> **João (Suporte)** — o meu é mais simples: quando o e-mail do comprador falha, eu
> preciso conseguir ver e reenviar sozinho, por uma tela. Hoje, em outro sistema nosso,
> eu abro chamado pro dev rodar na mão. Não quero isso de novo.

> **Carla** — ah, e o marketing quer o e-mail do ingresso saindo no ato da aprovação.
> O financeiro acha que é cedo demais. Vocês dois resolvem — decide você e escreve o porquê.

> **Marcos** — a gente roda com **múltiplos workers** de fila em produção. Não é
> negociável, é o que o pico exige. Constrói pensando nisso.

---

## 4. Documentação do PagFácil

**Endpoint que você expõe:** `POST /webhooks/pagfacil`

**Headers:**

| Header | Descrição |
|---|---|
| `X-PagFacil-Event-Id` | Identificador do evento (ex: `evt_9f2a3c1b`) |
| `X-PagFacil-Timestamp` | Unix timestamp de quando o evento **ocorreu** |
| `X-PagFacil-Signature` | `HMAC-SHA256(raw_body, secret)` em hexadecimal |

**Corpo:**

```json
{
  "event_id": "evt_9f2a3c1b",
  "event_type": "payment.approved",
  "created_at": "2026-03-14T10:00:41Z",
  "data": {
    "payment_id": "pay_77c1",
    "order_reference": "TKT-000412",
    "amount_cents": 24000,
    "method": "credit_card"
  }
}
```

**Tipos de evento:** `payment.approved`, `payment.refused`, `payment.refunded`,
`payment.chargeback`.

**4.1 — Autenticação.** Toda requisição é assinada. Requisições sem assinatura válida
devem ser rejeitadas pelo integrador.

**4.2 — Timeout.** Consideramos a entrega bem-sucedida se recebermos um status HTTP 2xx
em até **5 segundos**. Após esse prazo, encerramos a conexão.

**4.3 — Garantias de entrega.** A entrega é *at-least-once*. Em caso de falha ou timeout,
reenviamos o mesmo evento em até **6 tentativas**, com backoff exponencial. O `event_id`
é estável entre reenvios. **Não garantimos a ordem de entrega** entre eventos distintos
do mesmo pagamento, nem entre pagamentos.

---

## 5. Escopo

Construa o que for necessário para que estas afirmações sejam verdadeiras:

1. Existe uma forma de criar um pedido (pode ser mínima — não é o foco).
2. O PagFácil consegue nos notificar e considera a entrega bem-sucedida.
3. Um pagamento aprovado vira pedido confirmado, com ingressos emitidos e QR code.
4. O comprador recebe seus ingressos por e-mail.
5. Um setor nunca emite mais ingressos do que sua capacidade.
6. Um pagamento estornado ou com chargeback nunca resulta em ingresso válido.
7. Uma falha no provedor de e-mail não invalida uma venda já paga.
8. O João consegue **ver os envios que falharam e reenviar por uma tela**, sem terminal
   e sem ajuda de dev.

O item 8 é a parte de front-end. Escopo pequeno de propósito: funcional e honesta, não
precisa ser bonita — precisa ser usável por quem não é dev.

**Como você exercita esse fluxo**

Não existe gateway do outro lado. Quem dispara os webhooks é você, com **um script de
payloads fixos** (ou um teste automatizado, ou um serviço simples no Compose — o formato
é seu). Nada sofisticado: um arquivo que monta o corpo, assina com o secret e faz o POST
no seu endpoint já resolve.

O mesmo vale para o e-mail: use um mock, um log ou um servidor SMTP falso — nada de
provedor real.

O que avaliamos aqui não é o capricho do script, e sim **quais cenários você escolheu
disparar**. Rodar o caminho feliz uma vez prova pouco sobre um sistema que vai receber
8 mil pagamentos em 5 minutos.

**Não é escopo:** integração com gateway de pagamento real ou sandbox, criação de conta em
serviço externo, URL pública/ngrok, envio de e-mail por provedor real, autenticação de
usuário, deploy, CI, design system, checkout completo com carrinho.

Sim, o escopo está descrito em termos de negócio de propósito. As decisões técnicas são
o que estamos avaliando.

---

## 6. Stack e ambiente

**Obrigatório:**

| Camada | Tecnologia |
|---|---|
| Front-end | **React com Next.js** |
| Back-end | **NestJS** |
| Fila / mensageria | **RabbitMQ** ou **BullMQ** (sua escolha — justifique no README) |
| Banco de dados | **PostgreSQL** |
| Cache / suporte a fila | **Redis** |
| Ambiente | **Docker Compose** |

Bibliotecas dentro dessa stack ficam a seu critério — ORM, validação, geração de QR code,
framework de teste, o que for. Só justifique cada escolha no README.

**Requisito não negociável: o projeto inteiro precisa subir com um comando.**

```bash
docker compose up --build
```

Depois disso, tudo de pé — API, front, worker(s), Postgres, Redis, broker — com migrations
e seeds aplicados automaticamente. Se o avaliador precisar rodar `npm install` na mão,
abrir três terminais ou criar banco manualmente, o requisito não foi atendido.

---

## 7. O `README.md` que você vai escrever

**a) Como executar.** Do zero até o sistema rodando: variáveis de ambiente, comando,
portas, como acessar cada serviço, como rodar os testes e como disparar os webhooks do
gateway. Escreva para alguém que nunca viu o projeto.

**b) Tecnologias e o porquê de cada uma.** Por que RabbitMQ ou BullMQ? Qual ORM e por quê?
Cada biblioteca que você adicionou. "É a mais usada" não é justificativa — queremos o
critério que você aplicou.

**c) Desenho da solução.** Como você modelou: tabelas, estados do pedido, o que é síncrono
e o que é assíncrono, quais filas existem e por quê. Um diagrama simples ajuda.

**d) Modos de falha.** Liste os cenários de falha que você identificou neste fluxo e, para
cada um, como tratou — **ou por que decidiu não tratar**. Inclua os que você conhece mas
deixou de fora por tempo. Queremos ver o que você enxerga, não só o que coube no prazo.

**e) Trade-offs.** Onde havia mais de um caminho, qual escolheu e o que perdeu com a
escolha. Inclua o custo da sua solução no pico de 8 mil ingressos em 5 minutos.

**f) Testes realizados.** O que testou, em que nível (unitário, integração, e2e, carga),
como rodar cada um e — principalmente — **o que ficou sem cobertura e por quê**.

**g) A decisão do e-mail.** Marketing quer no ato; financeiro acha cedo. Você decidiu o
quê, e por quê?

**h) O que faria diferente com mais tempo.**

---

## 8. Regras

- **Prazo: 2 dias corridos** a partir do recebimento deste enunciado. O esforço esperado
  é de **8 a 10 horas** — o prazo é folgado de propósito, para você encaixar na sua
  rotina, não para virar noite. Ninguém aqui vai avaliar melhor quem gastou 20 horas.
- Se 2 dias não couberem na sua semana, **peça mais prazo antes de começar**. A gente
  combina outra data sem prejuízo nenhum na avaliação — preferimos isso a receber uma
  entrega corrida.
- Se não der tempo de tudo, priorize e escreva no README o que ficou de fora — cortar
  escopo com critério é parte da avaliação.
- IA é permitida. Só não entregue nada que você não consiga defender linha a linha na
  conversa técnica — a decisão acontece lá.
- Dúvidas sobre o enunciado: pergunte em `[e-mail/contato]`. No dia a dia você perguntaria.
