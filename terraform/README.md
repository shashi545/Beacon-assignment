

# AWS VPC + Network Firewall Terraform Assignment

## Overview
This Terraform configuration provisions a secure AWS VPC network across 3 Availability Zones in a single region, with public and private subnets, NAT Gateway, Internet Gateway and AWS Network Firewall integration. All major parameters are configurable via variables.

## Features
- VPC spanning 3 AZs (configurable)
- 3 public subnets (1 per AZ)
- 3 private subnets (1 per AZ)
- Internet Gateway for public subnet internet access
- NAT Gateway for private subnet internet access
- AWS Network Firewall deployed in its own subnets (one per AZ)
- Sample firewall rules:
  - Stateless: Allow outbound HTTP/HTTPS
  - Stateful: Deny outbound access to a specific IP (e.g., 198.51.100.1)
- Resource tagging (Name, Environment, etc.)

## How to Deploy
1. **Configure variables:** Edit `terraform/variables.tf` or use a `terraform.tfvars` file to set region, AZs, CIDR blocks, profile and tags.
2. **Create aws profile**
   - install aws cli in your local
   - Run.
   - aws configure -- profile beacon
   - pass access and secret keys having     permissions of vpc and network firewall
4. **Initialize Terraform:**
   ```bash
   cd terraform
   terraform init
   ```
5. **Review the plan:**
   ```bash
   terraform plan
   ```
6. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Key Design Decisions
- **Routing:**
  - Public subnets route traffic to the Internet Gateway.
  - Private subnets route traffic to the NAT Gateway for outbound internet access.
  - Network Firewall is deployed in dedicated subnets in each AZ.
- **Firewall Inspection:**
  - Firewall rules inspect and control outbound traffic from private subnets, but traffic is routed to the NAT Gateway by default (as implemented in main.tf).
  - Stateless and stateful rules are used to control outbound traffic as per requirements.
  - Private-subnets -> Firewall -> Nat Gateway -> Internet



## File Structure
- `main.tf`: Main resources and logic
- `variables.tf`: Configurable parameters
- `backend.tf`: (Optional) Remote state configuration

## Cleanup
To destroy all resources:
```bash
terraform destroy
```

---

## Note

- A backend configuration file is included here, which is typically used in real-time scenarios to store Terraform state files in an S3 bucket.  
- In this assignment, it is added only as an example and is **not implemented**.
- Here i shared the whole architecture in single main.tf , where we can do creating seprate modules for seprate services and we can call all services through one main.tf , where the modules can be reusable .
