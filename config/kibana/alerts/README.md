# Configuração de Alertas Automatizados via Telegram no Kibana

Este guia detalha a integração de notificações em tempo real para o **Telegram (Webhook)** utilizando o **Kibana Alerting** (*Stack Management > Rules and Connectors*).

Todas as credenciais sensíveis do Telegram são injetadas com segurança através do GitHub Secret `APP_SECRETS` no arquivo `.env` da VPS durante o pipeline de deploy.

---

## 1. Conector do Telegram (Webhook)

1. No Kibana, navegue até: **Stack Management** > **Rules and Connectors** > **Connectors** > **Create connector**.
2. Selecione o tipo **Webhook**.
3. Parâmetros do conector:
   - **Name:** `Telegram Alerts Bot`
   - **Method:** `POST`
   - **URL:** `${TELEGRAM_ENDPOINT}/bot${TELEGRAM_BOT_TOKEN}/sendMessage`  
     *(Exemplo direto: `https://api.telegram.org/bot<SEU_BOT_TOKEN>/sendMessage`)*
   - **Headers:**  
     - `Content-Type`: `application/json`
4. No campo **Body**, utilize o template definido em [`telegram_webhook_payload.json`](telegram_webhook_payload.json):
   ```json
   {
     "chat_id": "${TELEGRAM_CHAT_ID}",
     "text": "🚨 *[ALERTA DE INFRAESTRUTURA - MICROSERVIÇOS]* 🚨\n\n*Serviço Afetado:* `{{context.service}}`\n*Regra:* {{context.rule.name}}\n*Severidade:* CRITICAL\n*Filtro:* `service.keyword: * AND level: error`\n*Total de Erros Detectados:* {{context.hits}}\n*Janela de Análise:* Últimos 5 minutos\n\n📌 *Resumo do Log:* {{context.message}}\n\n🔗 [Abrir no Kibana Discover](http://localhost:5601/app/r/s/discover)",
     "parse_mode": "Markdown"
   }
   ```
5. Clique em **Test** para enviar uma mensagem de teste para o seu grupo/canal e salve o conector.

---

## 2. Criando a Regra de Alerta Dinâmica por Microsserviço

1. No Kibana, acesse: **Stack Management** > **Rules and Connectors** > **Create rule**.
2. **Rule details:**
   - **Name:** `Surto de Erros por Microserviço`
   - **Rule type:** `Elasticsearch query`
3. **Query details:**
   - **Index:** `microservices-logs-*`
   - **Query (KQL):** `level: "error"`
   - **Check every:** `1 minute`
   - **For the last:** `5 minutes`
   - **Condition:** `WHEN document count IS ABOVE 5`
4. **Action:**
   - Selecione o conector `Telegram Alerts Bot`.
   - Adicione o payload com as variáveis de contexto (`{{context.hits}}`, `{{context.service}}`, `{{context.message}}`).
5. Salve a regra. Sempre que qualquer microsserviço emitir mais de 5 logs de nível `error` em uma janela de 5 minutos, um alerta será enviado instantaneamente ao Telegram.
