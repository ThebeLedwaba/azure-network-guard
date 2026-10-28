# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 2. Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-network-guard"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# 3. Subnet for the App Service (Web API)
resource "azurerm_subnet" "snet_app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  
  delegation {
    name = "appservice-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# 4. Subnet for the SQL Private Endpoint
resource "azurerm_subnet" "snet_private_endpoint" {
  name                 = "snet-private-endpoint"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 5. Azure SQL Server
resource "azurerm_mssql_server" "sql_server" {
  name                         = "sql-network-guard-219119007" # Must be globally unique!
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password
  public_network_access_enabled = false # LOCKS PUBLIC ACCESS
}

# 6. Azure SQL Database
resource "azurerm_mssql_database" "sql_db" {
  name           = "db-network-guard"
  server_id      = azurerm_mssql_server.sql_server.id
  sku_name       = "Basic" 
  max_size_gb    = 2
}

# 7. SQL Private Endpoint 
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "pe-sql-network-guard"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_private_endpoint.id

  private_service_connection {
    name                           = "psc-sql-network-guard"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

# 8. Private DNS Zone (Required so the API can find the DB)
resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "sql-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "sql_dns_a" {
  name                = "sql-network-guard-219119007"
  zone_name           = azurerm_private_dns_zone.sql_dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address]
}
# 9. App Service Plan (B1 tier - required for VNet Integration)
resource "azurerm_service_plan" "asp" {
  name                = "asp-network-guard"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1" 
}

# 10. App Service (The Web API)
resource "azurerm_linux_web_app" "api" {
  name                = "app-network-guard-api-219119007" # Must be unique
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  # Connect the App Service to your VNet so it can reach the private SQL DB
  virtual_network_subnet_id = azurerm_subnet.snet_app.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  # Pass the database connection string as an environment variable
  app_settings = {
    "DATABASE_URL" = "mssql+pyodbc://sqladmin:${var.sql_admin_password}@sql-network-guard-219119007.database.windows.net:1433/db-network-guard?driver=ODBC+Driver+18+for+SQL+Server"
  }
}