# IAM role for ECS execution
resource "aws_iam_role" "ecs_execution" {
  name = "${var.projectName}-${var.clusterName}-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add CloudWatch logs policy
resource "aws_iam_role_policy" "ecs_cloudwatch_logs" {
  name = "${var.projectName}-${var.clusterName}-cloudwatch-logs"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

# Create ECS cluster
resource "aws_ecs_cluster" "cluster" {
  name = "${var.projectName}-${var.clusterName}"
}

# Create Service Connect namespace
resource "aws_service_discovery_http_namespace" "namespace" {
  name        = "${var.projectName}-${var.clusterName}-namespace"
  description = "${var.projectName} namespace for ${var.clusterName}"
}

# Create task definitions for ServiceA and ServiceB
resource "aws_ecs_task_definition" "services" {
  for_each                = toset(["A", "B"])
  family                  = "${var.projectName}-${var.clusterName}-service${each.key}"
  network_mode           = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                    = "256"
  memory                 = "512"
  execution_role_arn     = aws_iam_role.ecs_execution.arn
  
  container_definitions = jsonencode([
    {
      name      = "${var.projectName}-service${each.key}"
      image     = "nginx:latest"
      essential = true
      
      # Add CloudWatch logging configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.projectName}-${var.clusterName}-service${each.key}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
      
      # Prepare custom nginx configuration with CORS headers enabled for service discovery test
      command = [
        "/bin/sh",
        "-c",
        join(" && ", [
          "cat > /etc/nginx/conf.d/default.conf << 'EOL'\n${file("nginx.conf")}\nEOL",
          "cat > /usr/share/nginx/html/index.html << \"EOL\"\n${templatefile("index.html.tpl", {
            service_type = each.key,
            cluster_name = "${var.projectName}-${var.clusterName}",
            other_service = each.key == "A" ? "B" : "A",
            other_service_lower = each.key == "A" ? "b" : "a"
          })}\nEOL",
          "nginx -g 'daemon off;'"
        ])
      ]
      
      portMappings = [
        {
          name = "http"
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# Create ECS services
resource "aws_ecs_service" "services" {
  for_each        = toset(["A", "B"])
  name            = "${var.projectName}-${var.clusterName}-service${each.key}"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
  
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.namespace.arn
    
    service {
      client_alias {
        port     = 80
        dns_name = "service${lower(each.key)}"
      }
      port_name      = "http"
      discovery_name = "service${lower(each.key)}"
    }
  }
  
  # Register with load balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.service_tg[each.key].arn
    container_name   = "${var.projectName}-service${each.key}"
    container_port   = 80
  }
}
