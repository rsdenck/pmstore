#### WAZUH
- USANDO Incus (LXC/LXD)
- Criar REDE IPV4 SOC - 10.124.0.0/16
- Criar REDE IPV6 SOC - IP FIXO POR CONTAINER LXC - USAR ULA (RFC 4193) -> fd42:124::/64
### RESUMO DE REDE:
| Container       | IPv4       | IPv6        |
| --------------- | ---------- | ----------- |
| wazuh-manager   | 10.124.0.2 | fd42:124::2 |
| wazuh-indexer   | 10.124.0.3 | fd42:124::3 |
| wazuh-dashboard | 10.124.0.4 | fd42:124::4 |
| wazuh-agent     | 10.124.0.5 | fd42:124::5 |


### ADCIONAR DESCRIPTION:
- ADCIONAR DESCRIPTION POR REDE
- ADCIONAR DESCRIPTION POR POOL
- ADCIONAR DESCRIPTION POR LXC
- ADCIONAR DESCRIPTION POR PROFILE
- ADCIONAR DESCRIPTION POR STORAGE
- CONSTRUIR CONTAINER LXC em UBUNTU

### Criar LXC WAZUH SERVER - WAZUH MANAGER
- USAR IP FIXO: 10.124.0.2


### Criar LXC WAZUH INDEXER
- USAR IP FIXO: 10.124.0.3


### Criar LXC WAZUH DASHBOARD
- USAR IP FIXO: 10.124.0.4
- DEVE TER IP PUBLICO: para acessar via BROWSER
- IP interno container: 10.124.0.4:IP-virtual-machine -> IP externo-> Firewall

### Criar LXC WAZUH AGENT
- USAR IP FIXO: 10.124.0.5

### TODOS OS CONTAINERS DEVEM ESTAR CRIADOS NA MESMA REDE.
- VOLUMES PERSISTENTES
- INTEGRADOS
- PRONTO PARA PRODUÇÃO
- IMAGEM UBUNTU


- AMBIENTE DE DESENVOLVIMENTO: CRLF (Windows 11) com WSL -> UBUNTU
- INSTALAR INCUS, Configurar o incus, criar a rede, e o profile!
- TUDO EM UMA ÚNICA VM: UBUNTU 24.04(PROD)
- AMBIENTE: SOC-NG
- PROGILE: armazem
- REDE: socnet
- STORAGE: CRIAR UM POOL CHAMADO: WAZUH, e um VOLUME PARA CADA COMPONENTE


### Quero um prompt completo, conduzindo o Agent da IA, da IDE da TRAE.
- O prompt deve ser para a criação e homologação, e teste do ambiente!
- APENAS O: LXC WAZUH DASHBOARD -> terá roteamento para IP:PORTA do HOST -> e do HOST para o EDGE -> EDGE VCLOUD DIRECTOR
- PORTA: 443
- SSL: CERTBOT

### ARQUITETURA
- VDC-SOC
```bash
┌────────────────────────────────────┐
│        VM Ubuntu (Wazuh AIO)       │
│                                    │
│  ┌────────────┐                    │
│  │ Dashboard  │  ← Browser (HTTPS) │
│  └────────────┘                    │
│         │                          │
│  ┌────────────┐                    │
│  │  Manager   │                    │
│  └────────────┘                    │
│         │                          │
│  ┌────────────┐                    │
│  │  Indexer   │                    │
│  └────────────┘                    │
│                                    │
└────────────────────────────────────┘
```
## Objetivo:
- Criar os containers, visando a instalação em PRODUÇÃO, em ambiente UBUNTU, dentro do VCDLOU DIRECTOR com EDGE com Apenas um IP publico
- INTEGRAÇÕES: DISCORD
- DEFINIR UMA INTEGRAÇÃO, USANDO WEBHOOK DISCORD: https://discord.com/api/webhooks/1466797719422242916/lzgGx9O_bzDZomG_8p1cZk0M3yj_FkRyo91Iua0KrFhv7qaTa-aZ2mj7gRDosDSRNjp_
- ALERTAS DO WAZUH DEVEM SER ENVIADOS PARA O CANEL DO DISCOD, PADRÃO:
```bash
🚨 WAZUH ALERTA CRÍTICO

Regra: SSH brute force attempt
Severidade: 🔴 12
Agente: server-web-01
IP Origem: 185.220.101.45
Usuário: root
MITRE: T1110 – Brute Force
Horário: 2026-01-30 14:22:10 UTC
```

---
### FINALIZAÇÃO:
- Criar UM README CONDIZENTE COM O PROPOSITO DO REPO REMOTO:
- LXC HUB DE IMAGENS
- REPOSITORIO: https://github.com/rsdenck/lxchub
- CRIAR TEMPLATES< COM SETUP DE INSTALAÇÃO EM GO LANG -> EXEMPLOS:: https://community-scripts.github.io/ProxmoxVE/scripts
- Versionar para o repo remoto as imagens do wazuh, DOCUMENTAR tudo que tem.
- Criar Script: Go Lang para deploy da Stack completa! 
- O script deve criar tudo que tem, pronto apenas para PRODUÇÃO!
- SCRIPT GO FUNCIONAL!
- cada stack, devera ter um sub diretório dentro do lxchub/ como por exemplo: lxchub/hazuh -> imagens da stack atual.
- Atualizar completamente versionando e enviando para o repositório remoto tudo!