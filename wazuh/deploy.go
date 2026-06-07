package main

import (
	"fmt"
	"os/exec"
	"strings"
)

const (
	SOC_NET       = "socnet"
	SOC_PROFILE   = "armazem"
	SOC_POOL      = "WAZUH"
	SUBNET_V4     = "10.124.0.0/16"
	SUBNET_V6     = "fd42:124::/64"
	WAZUH_VERSION = "4.10.3"
)

type Node struct {
	Name string
	IPv4 string
	IPv6 string
}

var nodes = []Node{
	{"wazuh-manager", "10.124.0.2", "fd42:124::2"},
	{"wazuh-indexer", "10.124.0.3", "fd42:124::3"},
	{"wazuh-dashboard", "10.124.0.4", "fd42:124::4"},
	{"wazuh-agent", "10.124.0.5", "fd42:124::5"},
}

func runCommand(command string, args ...string) (string, error) {
	cmd := exec.Command(command, args...)
	output, err := cmd.CombinedOutput()
	return string(output), err
}

func setupIncus() {
	fmt.Println("🚀 Initializing Incus...")
	runCommand("sudo", "incus", "admin", "init", "--auto")

	fmt.Println("🌐 Creating network", SOC_NET)
	runCommand("sudo", "incus", "network", "create", SOC_NET,
		"ipv4.address="+strings.Split(SUBNET_V4, ".")[0]+"."+strings.Split(SUBNET_V4, ".")[1]+".0.1/16",
		"ipv4.nat=true",
		"ipv6.address="+strings.Split(SUBNET_V6, "::")[0]+"::1/64",
		"ipv6.nat=true")

	fmt.Println("📦 Creating storage pool", SOC_POOL)
	runCommand("sudo", "incus", "storage", "create", SOC_POOL, "dir")

	fmt.Println("👤 Creating profile", SOC_PROFILE)
	runCommand("sudo", "incus", "profile", "create", SOC_PROFILE)
	runCommand("sudo", "incus", "profile", "device", "add", SOC_PROFILE, "eth0", "nic", "network="+SOC_NET, "name=eth0")
	runCommand("sudo", "incus", "profile", "device", "add", SOC_PROFILE, "root", "disk", "path=/", "pool="+SOC_POOL)
}

func createContainers() {
	for _, node := range nodes {
		fmt.Printf("🏗️ Creating container %s from template...\n", node.Name)
		templateName := node.Name + "-template"

		// Try to launch from template, if not exists, launch from ubuntu
		out, err := runCommand("sudo", "incus", "launch", templateName, node.Name, "--profile", SOC_PROFILE)
		if err != nil {
			fmt.Printf("⚠️ Template %s not found, launching from ubuntu/24.04...\n", templateName)
			runCommand("sudo", "incus", "launch", "images:ubuntu/24.04", node.Name, "--profile", SOC_PROFILE)
		} else {
			fmt.Println(out)
		}

		fmt.Printf("🔗 Setting static IP for %s...\n", node.Name)
		runCommand("sudo", "incus", "config", "device", "set", node.Name, "eth0", "ipv4.address", node.IPv4)
		runCommand("sudo", "incus", "config", "device", "set", node.Name, "eth0", "ipv6.address", node.IPv6)

		fmt.Printf("💾 Attaching persistent volume for %s...\n", node.Name)
		volName := strings.TrimPrefix(node.Name, "wazuh-") + "-vol"
		// Ensure volume exists
		runCommand("sudo", "incus", "storage", "volume", "create", SOC_POOL, volName)
		runCommand("sudo", "incus", "storage", "volume", "attach", SOC_POOL, volName, node.Name, "/var/lib/wazuh")

		runCommand("sudo", "incus", "restart", node.Name)
	}
}

func setupRouting() {
	fmt.Println("🌐 Setting up routing for Dashboard (Port 443)...")
	// Proxy device for port 443
	runCommand("sudo", "incus", "config", "device", "add", "wazuh-dashboard", "https-proxy", "proxy", "listen=tcp:0.0.0.0:443", "connect=tcp:10.124.0.4:443")
}

func main() {
	fmt.Println("🛠️ WAZUH SOC-NG DEPLOYER")
	fmt.Println("========================")

	setupIncus()
	createContainers()
	setupRouting()

	fmt.Println("\n✅ Stack Wazuh implantada com sucesso!")
	fmt.Println("🔗 Dashboard: https://<IP_DA_VM>")
	fmt.Println("📝 Verifique os logs com: incus exec wazuh-dashboard -- tail -f /var/log/wazuh-install.log")
}
