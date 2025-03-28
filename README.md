# AWS ECS Service Connect Demo

This project demonstrates AWS ECS Service Connect functionality by deploying two services (A and B) that can communicate with each other within their cluster's namespace. The infrastructure is designed to be deployed multiple times, creating separate and isolated clusters.

## Architecture

Each cluster deployment includes:

- ECS Cluster with Fargate tasks
- Service Connect namespace for service discovery
- Two services (A and B) running nginx containers
- Application Load Balancer for external access
- VPC with public subnets
- Security groups for ALB and ECS tasks

## Prerequisites

1. AWS CLI installed and configured
2. Terraform installed (v1.0.0 or newer)
3. An AWS account with appropriate permissions

## Project Structure

```text
.
├── README.md
├── variables.tf      # Variable definitions
├── aws.tf           # AWS provider configuration
├── vpc.tf           # VPC and networking resources
├── alb.tf           # Load balancer configuration
├── ecs.tf           # ECS cluster, services, and task definitions
├── nginx.conf       # Nginx configuration template
└── index.html.tpl   # HTML template for service pages
```

## Configuration

The following variables can be configured:

| Variable      | Description                                    | Default         |
|--------------|------------------------------------------------|----------------|
| projectName  | Base name for all resources                    | "SvcCxDemo"    |
| clusterName  | Name of the cluster (e.g., cluster-1)         | Required       |
| region       | AWS region to deploy resources                 | "us-west-2"    |
| cidr         | CIDR block for the VPC                        | "10.0.0.0/16"  |

## Deployment

### Initial Setup

1. Clone the repository
2. Initialize Terraform:

   ```bash
   terraform init
   ```

### Deploying Multiple Clusters

You can deploy multiple clusters using Terraform workspaces. Each cluster will be completely isolated with its own networking, services, and service discovery namespace.

1. Create and switch to a workspace for the first cluster:

   ```bash
   terraform workspace new cluster1
   terraform apply -var="clusterName=cluster-1"
   ```

2. Create and switch to a workspace for the second cluster:

   ```bash
   terraform workspace new cluster2
   terraform apply -var="clusterName=cluster-2"
   ```

### Testing Service Discovery

1. Access ServiceA through the ALB URL (output as `public_endpoint`)
2. Click the "Test Connection" button to verify service discovery between ServiceA and ServiceB
3. Access ServiceB by appending `/serviceb` to the ALB URL

## Service Discovery Details

- Each service can discover and communicate with other services in the same cluster using the service name
- Service discovery names follow the pattern: `servicea` and `serviceb`
- Services in different clusters cannot communicate with each other, demonstrating proper isolation

## Cleanup

To destroy a specific cluster's resources:

1. Switch to the appropriate workspace:

   ```bash
   terraform workspace select cluster1  # or cluster2
   ```

2. Destroy the resources:

   ```bash
   terraform destroy -var="clusterName=cluster-1"  # or cluster-2
   ```

## Security Considerations

- Services are deployed in public subnets with public IPs for demonstration
- ALB security group allows inbound HTTP traffic from anywhere
- For production use, consider:
  - Using private subnets for ECS tasks
  - Restricting ALB access to specific IPs
  - Enabling HTTPS with ACM certificates
  - Implementing more restrictive security group rules

## Troubleshooting

1. **Service Discovery Issues**
   - Verify the services are in the same cluster and namespace
   - Check ECS service logs in CloudWatch
   - Verify security group rules allow inter-service communication

2. **ALB Connection Issues**
   - Verify target group health checks are passing
   - Check security group rules
   - Verify services are running with correct task counts

3. **Task Startup Issues**
   - Check ECS task logs in CloudWatch
   - Verify IAM roles and permissions
   - Check container definition and nginx configuration
