# LXC Hub - Wazuh SOC-NG Stack

Repositório central para imagens (templates) e scripts de deploy automatizado para a stack Wazuh em containers Incus (LXC).

## 🚀 Arquitetura VDC-SOC

A stack é composta por 4 containers rodando em uma rede isolada (`socnet` 10.124.0.0/16):

| Container | Função | IP Estático |
|-----------|--------|-------------|
| `wazuh-manager` | Servidor central de gerenciamento e alertas | 10.124.0.2 |
| `wazuh-indexer` | Indexação e busca de dados (OpenSearch) | 10.124.0.3 |
| `wazuh-dashboard` | Interface web (HTTPS/443) | 10.124.0.4 |
| `wazuh-agent` | Agente de teste/monitoramento | 10.124.0.5 |

## 📦 Estrutura do Repositório

- `/wazuh`: Templates e arquivos de configuração específicos da stack Wazuh.
- `deploy.go`: Script de deploy automatizado em Go Lang para produção.
- `WAZUH.md`: Documentação técnica detalhada da infraestrutura.

## 🛠️ Como Deployar (Produção)

O script `deploy.go` automatiza toda a criação da infraestrutura (Rede, Storage, Profile, Containers e Volumes).

### Pré-requisitos
- Ubuntu 24.04 LTS
- Incus instalado e configurado
- Go Lang instalado

### Execução
```bash
sudo go run deploy.go
```

## 🔐 Segurança e Acesso
- O Dashboard é exposto via proxy do Incus na porta 443 do host.
- Certificados SSL são gerenciados internamente ou via Certbot no host.
- Integração com Discord configurada para alertas críticos via Webhook.

## 📄 Licença
Este projeto é para uso interno no ecossistema VDC-SOC.
