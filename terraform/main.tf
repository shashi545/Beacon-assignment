provider "aws" {
  profile = var.profile
  region  = var.region
    default_tags {
    tags = {
      Environment = var.environment_name
    }
  }
}

# Data source to get available AZs in the selected region
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "beacon_vpc" {
  cidr_block = var.production_vpc_cidr
  tags = {
    Name = var.vpc_name
  }
}

locals {
  az_suffixes = ["a", "b", "c"]
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.beacon_vpc.id
  tags = {
    Name = "beacon-internet-gateway"
  }
}

resource "aws_subnet" "beacon_public" {
  count             = 3
  vpc_id            = aws_vpc.beacon_vpc.id
  cidr_block        = "10.1.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "beacon_public-subnet-1${local.az_suffixes[count.index]}"
    type = "public"
  }
}

resource "aws_subnet" "beacon_private" {
  count             = 3
  vpc_id            = aws_vpc.beacon_vpc.id
  cidr_block        = "10.1.${count.index + 100}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "beacon_private-subnet-1${local.az_suffixes[count.index]}"
    type = "private"
  }
}

resource "aws_eip" "nat" {
  count = 1
  tags = {
    Name = "beacon-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  depends_on    = [aws_internet_gateway.gw]
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.beacon_public[0].id
  tags = {
    Name = "beacon-nat-gateway"
  }
}

resource "aws_route_table" "beacon_public" {
  vpc_id = aws_vpc.beacon_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "beacon_public-route-table"
  }
}

resource "aws_route_table_association" "beacon_public" {
  count          = 3
  subnet_id      = aws_subnet.beacon_public[count.index].id
  route_table_id = aws_route_table.beacon_public.id
}

resource "aws_route_table" "beacon_private" {
  vpc_id = aws_vpc.beacon_vpc.id

  # Route all outbound traffic from private subnets to the NAT Gateway
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "beacon_private-route-table"
  }
}

resource "aws_route_table_association" "beacon_private" {
  count          = 3
  subnet_id      = aws_subnet.beacon_private[count.index].id
  route_table_id = aws_route_table.beacon_private.id
}




# Network Firewall Subnet
resource "aws_subnet" "beacon_firewall" {
  count             = 3
  vpc_id            = aws_vpc.beacon_vpc.id
  cidr_block        = "10.1.${count.index + 200}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "beacon_firewall-subnet-1${local.az_suffixes[count.index]}"
    type = "firewall"
  }
}


resource "aws_networkfirewall_rule_group" "stateless_http_https" {
  name     = "beacon-allow-http-https"
  capacity = 100
  type     = "STATELESS"

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:pass"]
            match_attributes {
              protocols = [6]
              destination_port {
                from_port = 80
                to_port   = 80
              }
              destination_port {
                from_port = 443
                to_port   = 443
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              source {
                address_definition = "10.1.0.0/16"
              }
            }
          }
        }
      }
    }
  }

  tags = {
    Name = "stateless-allow-http-https"
  }
}

resource "aws_networkfirewall_rule_group" "stateful_deny_ip" {
  name     = "beacon-deny-to-ip"
  capacity = 100
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
drop tcp any any -> 198.51.100.1 any (msg: "Deny outbound to 198.51.100.1"; sid:1000001;)
EOF
    }
  }

  tags = {
    Name = "stateful-deny-specific-ip"
  }
}

resource "aws_networkfirewall_firewall_policy" "beacon_policy" {
  name = "beacon-fw-policy"

  firewall_policy {
    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.stateless_http_https.arn
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_deny_ip.arn
    }

    stateless_default_actions            = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions    = ["aws:forward_to_sfe"]
  }

  tags = {
    Name = "beacon-firewall-policy"
  }
}

resource "aws_networkfirewall_firewall" "beacon_firewall" {
  name                = "beacon-fw"
  vpc_id              = aws_vpc.beacon_vpc.id
  firewall_policy_arn = aws_networkfirewall_firewall_policy.beacon_policy.arn

  dynamic "subnet_mapping" {
    for_each = aws_subnet.beacon_firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = {
    Name = "beacon-network-firewall"
  }
}


# GATEWAY LOAD BALANCER VPC ENDPOINT
resource "aws_vpc_endpoint" "network_firewall_gwlb" {
  vpc_id            = aws_vpc.beacon_vpc.id
  service_name      = "com.amazonaws.${var.region}.network-firewall"
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [for subnet in aws_subnet.beacon_firewall : subnet.id]

  tags = {
    Name = "beacon-network-firewall-gwlb-endpoint"
  }
}

# PRIVATE ROUTE TABLES TO FIREWALL
resource "aws_route_table" "private_to_firewall" {
  count  = 3
  vpc_id = aws_vpc.beacon_vpc.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.network_firewall_gwlb.id
  }

  tags = {
    Name = "private-fw-route-table-${count.index}"
  }
}

resource "aws_route_table_association" "private_fw_assoc" {
  count          = 3
  subnet_id      = aws_subnet.beacon_private[count.index].id
  route_table_id = aws_route_table.private_to_firewall[count.index].id
}

7. FIREWALL TO NAT ROUTING (if firewall needs outbound internet)
resource "aws_route_table" "firewall_to_nat" {
  vpc_id = aws_vpc.beacon_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "fw-to-nat-route"
  }
}

resource "aws_route_table_association" "fw_assoc" {
  count          = 3
  subnet_id      = aws_subnet.beacon_firewall[count.index].id
  route_table_id = aws_route_table.firewall_to_nat.id
}


















