# Guia Técnico: Elastic Stack Avançado

> **Referência Técnica:** Engenharia de Observabilidade & DevOps  
> **Componentes:** Filebeat Autodiscover | Index Lifecycle Management (ILM) | Logstash Optimization | Alertas Kibana

---

## 1. Filebeat Autodiscover Avançado

O recurso de Autodiscover do Filebeat permite monitorar infraestruturas dinâmicas em containers (Docker e Kubernetes). Ele escuta eventos do daemon do Docker para criar e encerrar dinamicamente as configurações de coleta de logs.

### 1.1 Templates vs Hints-based Autodiscover

- **Autodiscover baseado em Templates:** centraliza todas as regras no arquivo de configuração do Filebeat.
- **Autodiscover baseado em Hints:** permite que os próprios microsserviços definam o comportamento de coleta através de labels no container (`docker-compose.yml` ou `docker run`).

### 1.2 Configuração Dinâmica com Docker Labels (Hints)

Exemplo de configuração no container do microsserviço:

```yaml
labels:
  co.elastic.logs/enabled: "true"
  co.elastic.logs/json.keys_under_root: "true"
  co.elastic.logs/json.add_error_key: "true"
  co.elastic.logs/pipeline: "microservices-pipeline"
  co.elastic.logs/multiline.pattern: '^\['
  co.elastic.logs/multiline.negate: "true"
  co.elastic.logs/multiline.match: "after"
```

### 1.3 Appenders Avançados

Permite injetar configurações condicionais no momento da descoberta do container:

```yaml
filebeat.autodiscover:
  providers:
    - type: docker
      hints.enabled: true
      appenders:
        - type: config
          condition.contains:
            docker.container.image: "nginx"
          config:
            fields:
              service_type: "webserver"
            fields_under_root: true
```

---

## 2. Retenção e Ciclo de Vida de Índices (ILM)

O **Index Lifecycle Management (ILM)** automatiza a transição de dados entre diferentes níveis de armazenamento (*Data Tiers*), reduzindo custos e mantendo alta performance de busca nos dados recentes.

| Data Tier | Perfil de Hardware | Ações ILM Principais | Frequência de Uso |
| :--- | :--- | :--- | :--- |
| **Hot** | SSDs de Alta Performance (NVMe) | Rollover por tamanho (50GB) ou idade (30d) | Escrita ativa & busca intensa |
| **Warm** | SSDs Padrão / HDDs Rápidos | ForceMerge (1 segment), Shrink shards | Apenas leitura / consultas ocasionais |
| **Cold** | HDDs de Baixo Custo / Object Store | Searchable Snapshots, Redução de réplicas | Consultas raras / auditoria |
| **Delete** | N/A | Deleção definitiva do índice | Expiração da retenção (ex: 90 dias) |

### 2.1 Aplicando a Política ILM no Elasticsearch

```bash
curl -X PUT "http://localhost:9200/_ilm/policy/microservices-logs-policy" \
  -H 'Content-Type: application/json' \
  -d @config/elasticsearch/ilm-policy.json
```

---

## 3. Otimização do Logstash

O Logstash executa filtros e saídas em threads paralelas. Para atingir máxima eficiência sem sobrecarregar a JVM:

### 3.1 Parâmetros do `logstash.yml`
- **`pipeline.workers`**: Ajuste para o número de núcleos físicos de CPU (ou até 1.5x vCPUs para I/O intenso).
- **`pipeline.batch.size`**: Entre 250 e 1000 em ambientes de alto débito para otimizar chamadas Bulk ao Elasticsearch.
- **`queue.type: persisted`**: Cria fila persistente em disco (absorve picos de tráfego sem perder dados).

### 3.2 Dimensionamento de Heap JVM
- **Regra dos 50%**: Nunca aloque mais de 50% da memória RAM total do servidor para o Logstash (`-Xms` e `-Xmx` idênticos). Deixe o restante da RAM para o cache do SO. Mantenha o heap abaixo de 31GB.

### 3.3 Otimização de Filtros: Dissect vs Grok
Sempre que os logs possuírem delimitadores fixos, substitua `grok` por `dissect` (até 10x mais rápido sem uso de regex pesada).
