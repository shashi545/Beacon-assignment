
# AWS VPC + Network Firewall Terraform Assignment

## Overview
This Terraform configuration provisions a secure AWS VPC network across 3 Availability Zones in a single region, with public and private subnets, NAT Gateway, Internet Gateway, and AWS Network Firewall integration. All major parameters are configurable via variables.

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
1. **Configure variables:** Edit `terraform/variables.tf` or use a `terraform.tfvars` file to set region, AZs, CIDR blocks, and tags.
2. **Initialize Terraform:**
   ```bash
   cd terraform
   terraform init
   ```
3. **Review the plan:**
   ```bash
   terraform plan
   ```
4. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Key Design Decisions
- **Routing:**
  - Public subnets route traffic to the Internet Gateway.
  - Private subnets route traffic to the NAT Gateway for outbound internet access.
  - Network Firewall is deployed in dedicated subnets in each AZ.
- **Firewall Inspection:**
  - Firewall rules inspect and control traffic, but due to AWS limitations, Terraform cannot directly route private subnet traffic to the firewall endpoint ENI. By default, private subnet traffic is routed to the NAT Gateway. For full inspection, you must manually update the private subnet route table after deployment to point to the firewall endpoint ENI.
  - Stateless and stateful rules are used to control outbound traffic as per requirements.

## Manual Step for Full Traffic Inspection
After deploying with Terraform, manually update the private subnet route table:
- Set the default route (`0.0.0.0/0`) to the Network Firewall endpoint ENI in the firewall subnet (find the ENI in the AWS Console after deployment).
- Ensure the firewall subnet route table has a default route to the NAT Gateway.

## Assumptions & Limitations
- The configuration assumes 3 AZs are available in the selected region.
- AWS Network Firewall incurs additional costs.
- CIDR ranges must not overlap and should be chosen carefully.
- The sample firewall rules are basic and can be extended as needed.
- Full traffic inspection requires a manual route table update post-deployment.

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

For any issues or questions, please refer to the official AWS and Terraform documentation.
