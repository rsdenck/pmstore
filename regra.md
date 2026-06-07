# ESTÁ PROIBIDO DELETAR OS SEGUINTES LXC CONTAINERS QUE JÁ EXISTEM!
- ATENÇÃO: PROIBIDO DELETAR:
- 101 -> PMO
- 102 -> PMO
- 120 -> VM-01
- 200 -> RT-VS-01
- 300 -> LXC-APP-L 
----------
TODOS ESSES LXC ACIMA ESTÃO COMPLETAMENTE PROIBIDOS DE SEREM DELETADOS!
- NÃO PODE SEQUER EXECUTAR COMANDO NELES! SE ATENHA UNICA E EXCLUSIVAMENTE A CRIAÇÃO DOS CONTAINERS LXC DO: HAZUH COM O REPO INFORMADO!

--------------------------------------------------------------------------------------------------------------------------------------------
1 step 
- TODO O LXCHUB SERÁ INSPIRADO NO: https://github.com/community-scripts/ProxmoxVE/
- SENDO ASSIM: ESSE ATUAL AMBIENTE DE PROXMOX SERÁ USADO PARA -> CRIAR OS LXC DA LXCHUB (PMSTORE: https://pmoflow.pro/store/ )
- OS CONTAINERS LXC DEVEM SER COMPLETAMENTE PERSONALIZADOS! TODOS DEVEM ORBIGATÓRIAMENTE TER AS TAGS: pmstack e rsdenck
- TODOS OS CONTAINERS LXC DEVEM USAR COMO PADRÃO A PMTUI ( O USUÁRIO DEVERÁ TER ACESSO SOMENTE A PMTUI) E DENTRO DA PMTUI ELE DEVE ESCOLHER SE QUER ACESSO AO BASH!
- TODOS OS CONTAINERS LXC DEVEM ESTAR DENTRO DO REPO: https://github.com/rsdenck/pmstore
- DENTRO DO REPO: https://github.com/rsdenck/pmstore - DEVE ESTAR ORGANIZADO EM: pmstore/ct -> PARA OS CONTAINERS | pmstore/vm -> PARA AS VMS!
- DENTRO DO REPO DEVE TER UM README PRICIPAL FOCADO NO PMSTORE E PMSTACK: https://pmoflow.pro/
- VAMOS COMEÇAR PELOS CONTAINERS LXC DO HAZUH -> INSTALANDO APENAS A PMTUI -> AJUSTANDO A PMTUI PARA CONFIGURAR O LXC: IP, DNS, ETC!
- PMTUI: https://github.com/rsdenck/pmo/tree/main/pmtui -> clonar o repo, mas iremos usar apenas a PMTUI!
- TODOS OS LXC CONTAINERS DEVEM TER A PMTUI COMO BINÁRIO PADRÃO DO SISTEMA OPERACIONAL! 
- TODOS OS LXC CONTAINERS DEVEM SER ROCKY LINUX 9 OU SUPERIOR! NUNCA DEBIAN OU (.DEB)
- A PMTUI DEVE SER O PADRÃO DE LOGIN: TANTO VIA CONSOLE  NO PVE -> CONSOLE LXC (PMTUI) QUANTO VIA SSH DIRETO PARA O: SSH LXC
- A PMTUI DEVE SER MANTIDO SUAS CORES E ESTILOS! MAS AJUSTE, PARA TER ( PMSTACK CONSOLE ) NO TOPO DA PMTUI, BEM COMO rsdenck ABAIXO DO PMSTACK CONSOLE
- AVANCE!
- CADA CONTAINER LXC E VM DEVEM TER AS TAGS! TODOS DEVEM TER A PMTUI, COMO DEFINIDO!
- TODOS OS LXC CONTAINER QUE FOREM CRIADOS DEVERÃO SER VERSIONADOS, PARA: rsdenck/pmstore/ct/_nome_do_ct_.sh (DEVE TER O SCRIPT BASH PARA SER USADO NO: https://pmoflow.pro/store/
- EXEMPLOS DE COMO SERÃO USADOS OS SCRIPTS NO: https://pmoflow.pro/store/ -> var_cpu="2" var_ram="2048" var_disk="8" bash -c "$(curl -fsSL https://pmoflow.pro/proxmox-ve.sh)"
- DE MODO QUE O: curl -fsSL https://pmoflow.pro/proxmox-ve.sh ( proxmox-ve.sh ) SEMPRE SERÁ O .RAW DO GITHUB | O BASH DEVE SEMPRE INICIALIZAR O PMTUI E INICIALIZAR O DEPLOY DO LXC SEGUINDO O MESMO PADRÃO DO: bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/all-templates.sh)"
- ESSE PADRÃO DE DEPLOY AUTOMATIZADO: bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/all-templates.sh)" DEVE SER FEITO TAMBEM, MAS PARA O: var_cpu="2" var_ram="2048" var_disk="8" bash -c "$(curl -fsSL https://pmoflow.pro/proxmox-ve.sh)" - USANDO AS CORES E ESTILOS DO PMTUI
--------------------------------------------------
# TESTAR ACESSAR VIA SSH OS LXC CONTAINERS!
root@pve3:/opt/lxchub# ssh root@192.168.130.10
The authenticity of host '192.168.130.10 (192.168.130.10)' can't be established.
ED25519 key fingerprint is SHA256:t2RJixk1WhSVrSpRP8EdtYBQsBbnwE8VyNKMbgf8pPY.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.130.10' (ED25519) to the list of known hosts.
root@192.168.130.10's password:
Permission denied, please try again.
root@192.168.130.10's password:
Permission denied, please try again.
root@192.168.130.10's password:
root@192.168.130.10: Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).
root@pve3:/opt/lxchub#
-------------------------------------------------- O USER: root, e senha: lxchub não passaram!
# DEVE EXISTIR APENAS UM CONTAINER DO HAZUH E NÃO 3 CONTAINERS TEMPLATES! APENAS UM!
- DEVE SER CRIADO O SCRIPT BASH, O TEMPLATE DEVE SER COMPLETAMENTE HARDENIZADO, PARA SOC, E DEVE SER ATUALIZADO O REPOSITÓRIO REMOTO: rsdenck/pmstore
- criando o: ct/ | vm/ etc... 
--------------------------------------------------
2 step 
- TODOS OS CONTAINERS LXC DEVEM TER O NOME COM LETRAS MAIUSCULAS! EXEMPLO: HAZUH | ZABBIX | DOCKER | ETC... 
- TODOS OS CONTAINER LXC DEVEM TER AS DUAS TAGS OBRIGATÓRIAMENTE!
- TODOS OS CONTAINERS LXC DEVEM TER O SEU SCRIPT BASH DEFINIDO PARA DEPLOY AUTOMATICO, USANDO O (.RAW) DO GITHUB
- TODO VERSIONAMENTO FEITO PARA O REPO: rsdenck/pmstore - DEVE SER FEITO USANDO: piptr@protonmail.com | rsdenck
- DEVE SER CRIADO UM WORKFLOW COMPLETO PARA ACTIONS CI
