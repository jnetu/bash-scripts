#!/bin/bash

#        =================================================================
#                  SCRIPT DE CONFIGURAÇÃO DE IP ESTÁTICO E DNS
# joao@joao
# Versão: 1.0
# Funções: Seleção de Interface, Validação de IP, IP Fixo via interfaces, DNS Fixo.
# ========

# Variaveis de Configuracao (EXEMPLOS****)
##ALTERAR DE ACORDO COM CONFIG DO ROTEADOR
GATEWAY="192.168.18.1" 

NETMASK="255.255.255.0"
DNS1="1.1.1.1"
DNS2="8.8.8.8"

# Funcao de Log e Saida
log() {
    echo -e "\n[INFO] $1"
}

# -----------------------------------------------------------------
#                  FUNÇÕES DE VALIDAÇÃO E INTERAÇÃO
# ----------

# Valida o formato IPv4
validar_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Seleciona a Interface e Pede o IP
selecionar_rede() {
    log "1. SELEÇÃO DA INTERFACE DE REDE E IP ESTÁTICO"
    echo "Interfaces de rede ativas (Nome e IP Atual):"
    ip a | awk '/^[0-9]:/ {interface=$2} /inet /{print "  " interface " (" $2 " - ATUAL)"}' | grep -v 'lo:'

    while true; do
        read -r -p "Digite o nome da interface de rede (ex: enp6s0, eth0): " INTERFACE
        if ip a | grep -q "$INTERFACE"; then
            break
        else
            echo "[ERRO] Interface '$INTERFACE' não encontrada. Tente novamente."
        fi
    done

    while true; do
        read -r -p "Digite o NOVO IP ESTÁTICO desejado ---- LIMITE SEU ROTEADOR DCHP PARA EVITAR CONFLITO E USE IPs FORA DA BANDA(Ex: 192.168.18.202): " NOVO_IP
        
        #chama função de verificar formato digitado
        if validar_ip "$NOVO_IP"; then
        
            break
        else
            echo "[ERRO] Formato de IP inválido. Use o formato X.X.X.X."
        fi
    done
}

# -------------------------------------------------------------------------------
#                                  FUNÇÕES DE CONFIGURAÇÃO
# -----

configurar_rede() {
    log "2. CONFIGURANDO IP ESTÁTICO ($NOVO_IP) e DNS"

    # 2.1 Desabilitar NetworkManager
    # Evita que o NetworkManager sobrescreva /etc/resolv.conf
    systemctl stop NetworkManager &>/dev/null
    systemctl disable NetworkManager &>/dev/null
    log "NetworkManager desativado para evitar conflitos."

    # 2.2 Configurar /etc/network/interfaces
    # Adiciona a configuração estática ao final do arquivo, mantendo o que já existia.
    cat << EOF >> /etc/network/interfaces

# Configuracao Estatica automatica via script
auto $INTERFACE
iface $INTERFACE inet static
    address $NOVO_IP
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS1 $DNS2
EOF
    log "Configuração estática em /etc/network/interfaces concluída."

    # 2.3 Configurar /etc/resolv.conf (DNS fixo)
    # Limpa o arquivo e insere os DNSs fixos para garantir a resolução de nomes.
    echo "# Configurado via script (DNS fixo)" > /etc/resolv.conf
    echo "nameserver $DNS1" >> /etc/resolv.conf
    echo "nameserver $DNS2" >> /etc/resolv.conf

    # 2.4 Aplicar e verificar a nova rede
    systemctl restart networking
    sleep 5 # Espera o serviço de rede reiniciar
    
    if ip a | grep "$INTERFACE" | grep -q "$NOVO_IP"; then
        log "IP Estático $NOVO_IP aplicado com sucesso na interface $INTERFACE!"
    else
        log "[ERRO GRAVE] Falha ao aplicar IP Estático. Verifique a rede manualmente."
    fi
}

# -----------------------------------------------------------------
#                            EXECUÇÃO PRINCIPAL
# ----------

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then
  echo "[ERRO] Este script deve ser rodado como root. Use 'sudo bash $0'"
  exit 1
fi

selecionar_rede
configurar_rede

log "================================================================="
log "CONFIGURAÇÃO DE IP ESTÁTICO CONCLUÍDA."
log "O servidor agora está no IP: $NOVO_IP"
log "================================================================="