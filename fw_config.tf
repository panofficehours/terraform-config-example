/* Ethernet Interfaces ---------------------------------------------------- */

resource "panos_ethernet_interface" "wan" {
  name                      = "ethernet1/1"
  mode                      = "layer3"
  vsys                      = "vsys1"
  enable_dhcp               = true
  create_dhcp_default_route = true
}

resource "panos_ethernet_interface" "dmz" {
  name       = "ethernet1/2"
  mode       = "layer3"
  vsys       = "vsys1"
  static_ips = ["192.168.1.1/24"]
}

/* Virtual Routers -------------------------------------------------------- */

resource "panos_virtual_router" "default_vr" {
  name       = "default"
  interfaces = [panos_ethernet_interface.wan.name, panos_ethernet_interface.dmz.name]
  depends_on = [panos_ethernet_interface.wan, panos_ethernet_interface.dmz]
}

/* Security Zones --------------------------------------------------------- */

resource "panos_zone" "wan" {
  name       = "WAN"
  mode       = "layer3"
  interfaces = [panos_ethernet_interface.wan.name]
}

resource "panos_zone" "dmz" {
  name       = "DMZ"
  mode       = "layer3"
  interfaces = [panos_ethernet_interface.dmz.name]
}

/* Service Objects -------------------------------------------------------- */

resource "panos_service_object" "service_tcp_221" {
  name             = "service-tcp-221"
  vsys             = "vsys1"
  protocol         = "tcp"
  description      = "Service object to map port 22 to 221"
  destination_port = "221"
}

resource "panos_service_object" "service_tcp_222" {
  name             = "service-tcp-222"
  vsys             = "vsys1"
  protocol         = "tcp"
  description      = "Service object to map port 22 to 222"
  destination_port = "222"
}

resource "panos_service_object" "http-81" {
  name             = "http-81"
  vsys             = "vsys1"
  protocol         = "tcp"
  description      = "Service object to map port 22 to 222"
  destination_port = "81"
}

/* NAT Policies ----------------------------------------------------------- */

resource "panos_nat_rule_group" "test" {
  rule {
    name          = "DMZ-WAN-out"
    audit_comment = "Initial config"
    original_packet {
      source_zones          = [panos_zone.dmz.name]
      destination_zone      = panos_zone.wan.name
      destination_interface = panos_ethernet_interface.wan.name
      source_addresses      = ["any"]
      destination_addresses = ["any"]
    }
    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = panos_ethernet_interface.wan.name
          }
        }
      }
      destination {}
    }
  }
}

/* Security Policies ------------------------------------------------------ */

resource "panos_security_policy" "DMZ-to-WAN-allow" {
  rule {
    name                  = "DMZ-to-WAN-allow"
    audit_comment         = "Initial config"
    source_zones          = [panos_zone.dmz.name]
    source_addresses      = ["any"]
    source_users          = ["any"]
    destination_zones     = [panos_zone.wan.name]
    destination_addresses = ["any"]
    applications          = ["any"]
    services              = ["application-default"]
    categories            = ["any"]
    action                = "allow"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    panos_zone.dmz,
    panos_zone.wan
  ]
}
