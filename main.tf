# Variable and provider config
provider "azurerm" { 
}
resource "tls_private_key" "servicefabric" {
  algorithm = "RSA"
}
variable "vmusername" {
  type    = "string"
  default = "myadmin"
}
variable "cluster_name" {
  type    = "string"
  default = "ukfabric"
}
resource "random_string" "vmname" {
  length = 6
  special = false
}
resource "random_string" "vmpassword" {
  length = 16
  special = false
}
variable "sf_frontend_ip_config_name" {
  type    = "string"
  default = "PublicIPAddress-SF"
}

variable "clustersize" {
  default = 3
}

# Resource Group
resource "azurerm_resource_group" "test" {
  name     = "ukresource"
  location = "UK South"

  tags = {
    resourceType = "Service Fabric"
    clusterName = "${var.cluster_name}"
  }
}

# Network
resource "azurerm_virtual_network" "test" { # Virtual network
  name                = "${var.cluster_name}-vn"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"

  tags = {
    resourceType = "Service Fabric"
    clusterName = "${var.cluster_name}"
  }
}
resource "azurerm_subnet" "test" { # Subnet
  name                 = "${var.cluster_name}-subnet"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_public_ip" "test" { # public ip and dns allocation
  name                         = "${var.cluster_name}-public-ip"
  location                     = "${azurerm_resource_group.test.location}"
  resource_group_name          = "${azurerm_resource_group.test.name}"
  domain_name_label            = "${azurerm_resource_group.test.name}"
  allocation_method            = "Dynamic"

  tags = {
    resourceType = "Service Fabric"
    clusterName = "${var.cluster_name}"
  }
}
resource "azurerm_lb" "test" { # load balancer
  name                = "${var.cluster_name}-lb"
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"

  frontend_ip_configuration {
    name                 = "${var.sf_frontend_ip_config_name}"
    public_ip_address_id = "${azurerm_public_ip.test.id}"
  }

  tags = {
    resourceType = "Service Fabric"
    clusterName = "${var.cluster_name}"
  }
}

resource "azurerm_lb_nat_pool" "test" { # nat pool for load balancer
  name                           = "${var.cluster_name}-nat-pool"
  resource_group_name            = "${azurerm_resource_group.test.name}"
  loadbalancer_id                = "${azurerm_lb.test.id}"
  count                          = "${var.clustersize}"
  protocol                       = "Tcp"
  frontend_port_start            = 3389
  frontend_port_end              = 4500
  backend_port                   = 3389
  frontend_ip_configuration_name = "${var.sf_frontend_ip_config_name}"
}

resource "azurerm_lb_backend_address_pool" "test" { # load balancer address pool
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id     = "${azurerm_lb.test.id}"
  name                = "ServiceFabricAddressPool"
}

# Probes
resource "azurerm_lb_probe" "fabric_gateway" { # SF client endpoint port.
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id     = "${azurerm_lb.test.id}"
  name                = "${var.cluster_name}-probe-19000"
  port                = 19000
}
resource "azurerm_lb_probe" "http" { # SF client http endpoint port.
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id     = "${azurerm_lb.test.id}"
  name                = "${var.cluster_name}-probe-19080"
  port                = 19080
}
resource "azurerm_lb_probe" "app_port_0" { # http - purpose?
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id     = "${azurerm_lb.test.id}"
  name                = "${var.cluster_name}-probe-80"
  port                = 80
}
resource "azurerm_lb_probe" "app_port_1" {
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id     = "${azurerm_lb.test.id}"
  name                = "${var.cluster_name}-probe-83"
  port                = 83
}

resource "azurerm_lb_rule" "app_port_0" {
  resource_group_name            = "${azurerm_resource_group.test.name}"
  loadbalancer_id                = "${azurerm_lb.test.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.test.id}"
  probe_id                       = "${azurerm_lb_probe.app_port_0.id}"
  name                           = "AppPortLBRule0"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "${var.sf_frontend_ip_config_name}"
}
resource "azurerm_lb_rule" "app_port_1" {
  resource_group_name            = "${azurerm_resource_group.test.name}"
  loadbalancer_id                = "${azurerm_lb.test.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.test.id}"
  probe_id                       = "${azurerm_lb_probe.app_port_1.id}"
  name                           = "AppPortLBRule1"
  protocol                       = "Tcp"
  frontend_port                  = 83
  backend_port                   = 83
  frontend_ip_configuration_name = "${var.sf_frontend_ip_config_name}"
}
resource "azurerm_lb_rule" "http" {
  resource_group_name            = "${azurerm_resource_group.test.name}"
  loadbalancer_id                = "${azurerm_lb.test.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.test.id}"
  probe_id                       = "${azurerm_lb_probe.http.id}"
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 19080
  backend_port                   = 19080
  frontend_ip_configuration_name = "${var.sf_frontend_ip_config_name}"
}
resource "azurerm_lb_rule" "fabric_gateway" {
  resource_group_name            = "${azurerm_resource_group.test.name}"
  loadbalancer_id                = "${azurerm_lb.test.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.test.id}"
  probe_id                       = "${azurerm_lb_probe.fabric_gateway.id}"
  name                           = "fabric_gateway"
  protocol                       = "Tcp"
  frontend_port                  = 19000
  backend_port                   = 19000
  frontend_ip_configuration_name = "${var.sf_frontend_ip_config_name}"
}

# Service fabric
resource "azurerm_service_fabric_cluster" "test" {
  name                = "${var.cluster_name}-sf"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"
  reliability_level   = "Bronze"
  upgrade_mode        = "Manual"
  cluster_code_version = "6.5.641.9590"
  vm_image            = "Windows"
  management_endpoint = "https://${azurerm_public_ip.test.fqdn}:19080"

  add_on_features = [ "DnsService" ]
     node_type {
    name                 = "${random_string.vmname.result}"
    instance_count       = "${var.clustersize}"
    is_primary           = true
    client_endpoint_port = 19000
    http_endpoint_port   = 19080
    application_ports {
        start_port = 20000
        end_port = 30000
    }
    ephemeral_ports { # possibly open client ports
        start_port = 49152
        end_port = 65534
    }
  }
  
  fabric_settings {
    name = "Security"
    parameters = {
      "ClusterProtectionLevel" = "EncryptAndSign"    
      }
  }
  fabric_settings {
    name = "ClusterManager"
    parameters = {
      EnableDefaultServicesUpgrade = "False"
    }
  }
 
  certificate {
    thumbprint = "<thumbprint>"
    thumbprint_secondary = ">thumbprint>"
    x509_store_name = "My"
  }

  tags = {
    resourceType = "Service Fabric"
    clusterName = "${var.cluster_name}"
  }
}

# Vm Scale Set
resource "azurerm_virtual_machine_scale_set" "test" {
  name                = "uk_scale_set"
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  count               = "${var.clustersize}"
  upgrade_policy_mode = "Automatic"
  overprovision       = false

  sku {
    name     = "Standard_D3_v2"
    tier     = "Standard"
    capacity = "${var.clustersize}"
  }

  tags = {
    resourceType = "Service Fabric"
    clusterName = "${var.cluster_name}"
  }

  storage_profile_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  storage_profile_data_disk {
    lun            = 0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
  }

  os_profile {
    computer_name_prefix = "${random_string.vmname.result}"
    admin_username       = "${var.vmusername}"
    admin_password       = "Password1234!"
  }

  os_profile_secrets     {
      source_vault_id = "/<subscription string>"
      vault_certificates {
          certificate_url = "<certifiate secret URL>"
          certificate_store = "My"
          
        }
      }
  network_profile {
    name    = "uknetworkprofile"
    primary = true

    ip_configuration {
      primary = true
      name                                   = "TestIPConfiguration"
      subnet_id                              = "${azurerm_subnet.test.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.test.id}"]
      load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.test.*.id, count.index)}"]
    }
  }



  extension { # This extension connects vms to the cluster.
   name                 = "ServiceFabricNodeVmExt_vmNodeType0Name"
    publisher            = "Microsoft.Azure.ServiceFabric"
    type                 = "ServiceFabricNode"
    type_handler_version = "1.0"
    settings             = "{  \"certificate\": { \"thumbprint\": \"<ert thumbprint>\", \"x509StoreName\": \"My\" } , \"clusterEndpoint\": \"${azurerm_service_fabric_cluster.test.cluster_endpoint}\", \"nodeTypeRef\": \"${random_string.vmname.result}\", \"dataPath\": \"D:\\\\SvcFab\",\"durabilityLevel\": \"Bronze\",\"nicPrefixOverride\": \"10.0.0.0/24\"}"
  }

 }
