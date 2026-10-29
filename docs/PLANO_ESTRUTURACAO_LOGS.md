# 📋 Plano de Estruturação e Padronização de Logs para o Elastic Stack

> **Objetivo:** Estabelecer um formato de logs estruturado (JSON) e padronizado em todas as aplicações do ecossistema, permitindo ingestão automática, indexação de alta performance e criação de **Dashboards Gerais Dinâmicos** com o filtro `service.keyword`.

---

## 🔍 1. Diagnóstico Atual das Aplicações

| Aplicação / Módulo | Linguagem / Framework | Formato Atual do Log | Suporte Atual do Logstash |
| :--- | :--- | :--- | :--- |
| **`azevedo-commons-utils`** | Java 17 (Lib) | Utilitários de MDC (`transaction.id`) e anotações `@Log` | Ideal para centralizar o encoder compartilhado |
| **`commons-security`** | Java 17 (Lib) | SLF4J padrão via Spring Security / Keycloak | Dependerá da lib commons-utils |
| **`fatura-service`** | Java 17 (Spring Boot) | Texto Puro: `[%d{ISO8601}] %-5p [%t] %-36c{1} %X{transaction.id}: %m %n` | Parseado via Grok (não estruturado nativamente) |
| **`caderneta-user-services`** | Java 17 (Spring Boot) | Texto Puro: `[%d{ISO8601}] %-5p [%t] %-36c{1} %X{transaction.id}: %m %n` | Parseado via Grok (não estruturado nativamente) |
| **`caderneta-dashboard-services`**| Java 17 (Spring Boot) | Texto Puro: `[%d{ISO8601}] %-5p [%t] %-36c{1} %X{transaction.id}: %m %n` | Parseado via Grok (não estruturado nativamente) |
| **`notification-service`** | Python 3.12 (FastAPI) | Texto Puro via `logging.basicConfig` | Parseado via Grok (não estruturado nativamente) |
| **`automacao-resgate-fatura`** | Python 3.11 (Cron/Script) | Texto Puro via `logging.info` direcionado para `/var/log/cron.log` | Parseado via Grok (não estruturado nativamente) |
| **`auth-api`** | Node.js (Express) | Texto Puro via múltiplos `console.log(...)` dispersos | Parseado como texto bruto |

---

## 🎯 2. Formato Alvo Padronizado (JSON Estruturado)

Todas as aplicações devem emitir linhas JSON em `stdout`, contendo no mínimo os campos padronizados:

```json
{
  "@timestamp": "2026-10-25T01:30:00.123Z",
  "service": "fatura-service",
  "level": "info",
  "environment": "production",
  "transaction_id": "8f8b86d9-b9d2-45a7-96a1-0e36b856b3b2",
  "logger": "com.br.azevedo.fatura.controller.FaturaController",
  "message": "Fatura processada com sucesso para o usuário usr_101",
  "stack_trace": null
}
```

---

## 🛠 3. Plano de Ação por Stack Tecnológica

### 3.1 Aplicações Java (Spring Boot) & Libs Compartilhadas

#### Fase 1: Centralizar na biblioteca `azevedo-commons-utils`
1. Adicionar no `pom.xml` de `azevedo-commons-utils`:
   ```xml
   <dependency>
       <groupId>net.logstash.logback</groupId>
       <artifactId>logstash-logback-encoder</artifactId>
       <version>7.4</version>
   </dependency>
   ```
2. Criar em `src/main/resources/logback-base-json.xml` um template reaproveitável:
   ```xml
   <included>
       <appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
           <encoder class="net.logstash.logback.encoder.LogstashEncoder">
               <customFields>{"service":"${SPRING_APPLICATION_NAME:-unknown-java-service}"}</customFields>
               <includeMdcKeyName>transaction.id</includeMdcKeyName>
               <includeMdcKeyName>transactionid</includeMdcKeyName>
               <fieldNames>
                   <timestamp>@timestamp</timestamp>
                   <levelValue>[ignore]</levelValue>
               </fieldNames>
           </encoder>
       </appender>
       <root level="INFO">
           <appender-ref ref="JSON_CONSOLE" />
       </root>
   </included>
   ```

#### Fase 2: Aplicar nos Microsserviços Java
Nos projetos `fatura-service`, `caderneta-user-services` e `caderneta-dashboard-services`:
1. No `src/main/resources/application.yml`, garantir a chave da aplicação:
   ```yaml
   spring:
     application:
       name: fatura-service # ou caderneta-user-services / caderneta-dashboard-services
   ```
2. Substituir o `src/main/resources/logback.xml` por:
   ```xml
   <configuration>
       <include resource="logback-base-json.xml" />
   </configuration>
   ```

---

### 3.2 Aplicações Python

#### `notification-service` e `automacao-resgate-fatura`
1. Adicionar dependência:
   ```bash
   pip install python-json-logger
   ```
2. Criar utilitário de logging centralizado (ex: `app/core/logging_config.py`):
   ```python
   import logging
   import sys
   from pythonjsonlogger import jsonlogger

   def setup_json_logging(service_name: str):
       logger = logging.getLogger()
       log_handler = logging.StreamHandler(sys.stdout)
       formatter = jsonlogger.JsonFormatter(
           fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
           rename_fields={"asctime": "@timestamp", "levelname": "level", "name": "logger"}
       )
       log_handler.setFormatter(formatter)
       logger.handlers = [log_handler]
       logger.setLevel(logging.INFO)
       
       # Injeta o campo fixo de serviço
       old_factory = logging.getLogRecordFactory()
       def record_factory(*args, **kwargs):
           record = old_factory(*args, **kwargs)
           record.service = service_name
           return record
       logging.setLogRecordFactory(record_factory)
   ```
3. Chamar no entrypoint (`app/main.py` e `automacao-resgate-fatura/__init__.py`):
   ```python
   setup_json_logging(service_name="notification-service")
   ```

---

### 3.3 Aplicação Node.js (`auth-api`)

1. Adicionar o logger `pino`:
   ```bash
   yarn add pino pino-http
   ```
2. Criar `src/config/logger.js`:
   ```javascript
   import pino from 'pino';

   const logger = pino({
     level: process.env.LOG_LEVEL || 'info',
     base: {
       service: 'auth-api',
       environment: process.env.NODE_ENV || 'production'
     },
     timestamp: pino.stdTimeFunctions.isoTime
   });

   export default logger;
   ```
3. Conectar ao Express com middleware para injetar o `transactionid` em todos os logs HTTP:
   ```javascript
   import pinoHttp from 'pino-http';
   import logger from './src/config/logger.js';

   app.use(pinoHttp({
     logger,
     customProps: (req) => ({
       transactionid: req.headers['transactionid'] || req.headers['transaction.id']
     })
   }));
   ```
4. Substituir chamadas de `console.log` por `logger.info`, `logger.error` e `logger.warn`.

---

## 🚀 4. Como os Logs Chegam ao Logstash Hoje e Ações no Container

1. **Como chegam:**
   - O Filebeat está escutando `/var/run/docker.sock` com Autodiscover habilitado.
   - Todo container Docker na VPS gera logs em `/var/lib/docker/containers/<id>/<id>-json.log` capturando **STDOUT** e **STDERR**.
   - O Filebeat lê esses arquivos e envia ao Logstash na porta `5044`.

2. **Necessidade de Ação no Container:**
   - **Nenhuma alteração de infraestrutura é obrigatória nos containers.**
   - O Logstash já foi configurado para extrair o nome do serviço a partir do nome do container (`--name "$APP_NAME"`), mesmo para aplicações que ainda geram logs em texto comum!
   - Portanto, a migração para JSON estruturado pode ser executada gradualmente, aplicação por aplicação, sem risco de interrupção ou perda de logs.
