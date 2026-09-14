resource "azurerm_storage_account" "acafileshare" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "dfy" {
  name                  = "dfy"
  storage_account_id    = azurerm_storage_account.acafileshare.id
  container_access_type = "private"
}


module "nginx_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/nginx"
  share_name         = "nginx"
}

module "sandbox_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/sandbox"
  share_name         = "sandbox"
}

module "ssrf_proxy_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/ssrfproxy"
  share_name         = "ssrfproxy"
  exclude_files      = ["squid.conf"]
}

# squid.conf is templated separately so the allowed nginx domain always matches the deployed FQDN
resource "local_file" "ssrfproxy_squid_conf_rendered" {
  filename = "${path.module}/.rendered/ssrfproxy/squid.conf"
  content = templatefile("mountfiles/ssrfproxy/squid.conf", {
    nginx_fqdn = azurerm_container_app.nginx.ingress[0].fqdn
  })
}

resource "azurerm_storage_share_file" "ssrfproxy_squid_conf" {
  name              = "squid.conf"
  storage_share_url = module.ssrf_proxy_fileshare.share_url
  content_type      = "text/plain"
  source            = local_file.ssrfproxy_squid_conf_rendered.filename
  content_md5       = md5(local_file.ssrfproxy_squid_conf_rendered.content)
}

module "agent_ssrf_proxy_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/agent-ssrfproxy"
  share_name         = "agentssrfproxy"
}

module "plugin_daemon_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/plugin_daemon"
  share_name         = "plugindaemon"
}

# API storage share for persistent data
resource "azurerm_storage_share" "api_storage" {
  name               = "api-storage"
  storage_account_id = azurerm_storage_account.acafileshare.id
  quota              = 50
}

