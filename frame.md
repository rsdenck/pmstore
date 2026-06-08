pmstore/
│
├── lib/
│   ├── pmstack.func
│   ├── network.func
│   ├── storage.func
│   ├── wizard.func
│   ├── branding.func
│   ├── hardening.func
│   └── deploy.func
│
├── ct/
│   ├── hazuh.sh
│   ├── vault.sh
│   ├── suricata.sh
│   ├── zeek.sh
│   └── wazuh.sh


- além do containers lxc prontos -> analisar o padrão: https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func
- eles como exemplo tem: https://github.com/community-scripts/ProxmoxVE -> dentro disso eles tem:
.github/
.vscode/
ct/
install/
misc/ -> vamos nos atentar! -> https://github.com/community-scripts/ProxmoxVE/tree/main/misc -> eles tem: alpine-install.func | alpine-tools.func | api.func | build.func | cloud-init.func |  core.func | error_handler.func | install.func | tools.func | vm-core.func -> analise tudo! quero algo que deixe mais rapido o deploy, e que os bashs fiquem mais simples!
tools/
turnkey/
vm/

