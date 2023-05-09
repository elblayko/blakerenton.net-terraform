####################################################################
# Terraform Configuration

terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

####################################################################
# Terraform Variables

# Set Digital Ocean API token
variable "do_token" {
  description = "DigitalOcean API token"
  type = string
  sensitive = true
}

# Set CloudFlare API key
variable "cf_key" {
  description = "CloudFlare API key"
  type = string
  sensitive = true
}

variable "cf_email" {
  description = "CloudFlare account e-mail address"
  type = string
}

variable "cf_zone_id" {
  description = "CloudFlare DNS zone ID"
  type = string
}

####################################################################
# Provider Configuration

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Configure the CloudFlare Provider
provider "cloudflare" {
  email   = var.cf_email
  api_key = var.cf_key
}

####################################################################
# DigitalOCean Configuration

# Create an Ubuntu droplet
resource "digitalocean_droplet" "blakerenton-net" {
  image       = "ubuntu-22-04-x64"
  name        = "blakerenton-net"
  region      = "nyc1"
  size        = "s-1vcpu-1gb"
  monitoring  = true
  ssh_keys    = [ "75:1c:b4:af:e1:70:dc:25:1c:93:0a:7f:e7:ba:70:7c", "a6:26:73:cc:49:12:5f:d3:79:17:ba:9c:30:66:16:33" ]
}

# Create DigitalOcean firewall
# IP Address reference: https://www.cloudflare.com/ips/
resource "digitalocean_firewall" "blakerenton-net" {
  name = "cloudflare"

  droplet_ids = [digitalocean_droplet.blakerenton-net.id]

  # HTTP Configuration
  inbound_rule {
    protocol = "tcp"
    port_range = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # SSH Configuration
  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Outbound Configuration
  outbound_rule {
    protocol = "tcp"
    port_range="1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol = "udp"
    port_range = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

####################################################################
# CloudFlare Configuration

# Create root record
resource "cloudflare_record" "blakerenton-net-a" {
  zone_id = var.cf_zone_id
  name    = "blakerenton.net"
  value   =  digitalocean_droplet.blakerenton-net.ipv4_address
  type    = "A"
  ttl     = 1 # auto
  proxied = true
}

# Create www cname record
resource "cloudflare_record" "blakerenton-net-www" {
  zone_id = var.cf_zone_id
  name    = "www"
  value   = "blakerenton.net"
  type    = "CNAME"
  ttl     = 1 # auto
  proxied = true
}

resource "cloudflare_record" "blakerenton-net-spf" {
  zone_id = var.cf_zone_id
  name    = "blakerenton.net"
  value   = "v=spf1 -all"
  type    = "TXT"
  ttl     = 1 # auto
}

resource "cloudflare_record" "blakerenton-net-dmarc" {
  zone_id = var.cf_zone_id
  name    = "_dmarc"
  value   = "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
  type    = "TXT"
  ttl     = 1 # auto
}

resource "cloudflare_record" "blakerenton-net-dkim" {
  zone_id = var.cf_zone_id
  name    = "*._domainkey"
  value   = "v=DKIM1; p="
  type    = "TXT"
  ttl     = 1 # auto
}

####################################################################
# After completion

# Output the IP address
output "droplet_ipv4_address" {
  value = digitalocean_droplet.blakerenton-net.ipv4_address
}
