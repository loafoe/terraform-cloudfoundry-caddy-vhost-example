locals {
  vhost_count = 4
}

data "cloudfoundry_space" "space" {
  name = "test"
  org  = data.cloudfoundry_org.org.id
}

data "cloudfoundry_org" "org" {
  name = var.cf_org_name
}

data "cloudfoundry_domain" "domain" {
  name = data.hsdp_config.cf.domain
}

resource "random_pet" "deploy" {
}

resource "random_pet" "vhosts" {
  count = local.vhost_count
}

resource "cloudfoundry_app" "caddy" {
  name         = "caddy-${random_pet.deploy.id}"
  space        = data.cloudfoundry_space.space.id
  memory       = 128
  disk_quota   = 512
  #strategy     = "blue-green"

  docker_image = var.caddy_image
  docker_credentials = {
    username = var.docker_username
    password = var.docker_password
  }

  environment = merge({
    CADDYFILE_BASE64 = base64encode(templatefile("${path.module}/templates/Caddyfile", {
      vhosts = [for i, v in cloudfoundry_route.vhosts : v.endpoint]
    }))
  }, {})

  command           = "echo $CADDYFILE_BASE64 | base64 -d > /etc/caddy/Caddyfile && cat /etc/caddy/Caddyfile && caddy run --config /etc/caddy/Caddyfile"
  health_check_type = "process"

  dynamic "routes" {
    for_each = {for i, j in random_pet.vhosts : i => j}
    content {
      route = cloudfoundry_route.vhosts[tonumber(routes.key)].id
    }
  }
}

resource "cloudfoundry_route" "vhosts" {
  count = local.vhost_count
  domain   = data.cloudfoundry_domain.domain.id
  space    = data.cloudfoundry_space.space.id
  hostname = random_pet.vhosts[count.index].id
}
