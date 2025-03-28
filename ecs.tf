# IAM role for ECS execution
resource "aws_iam_role" "ecs_execution" {
  name = "${var.projectName}-ecs-execution-role"
  
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

# Create two ECS clusters using count
resource "aws_ecs_cluster" "clusters" {
  count = 2
  name  = "${var.projectName}-cluster-${count.index + 1}"
}

# Create two Service Connect namespaces
resource "aws_service_discovery_http_namespace" "namespace" {
  count = 2
  name        = "${var.projectName}-namespace-${count.index + 1}"
  description = "${var.projectName} namespace for Service Connect"
}

# Update task definitions for ServiceA with custom nginx page that tests service discovery
resource "aws_ecs_task_definition" "services" {
  count                    = 2
  family                   = "${var.projectName}-service${count.index == 0 ? "A" : "B"}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  
  container_definitions = jsonencode([
    {
      name      = "${var.projectName}-service${count.index == 0 ? "A" : "B"}"
      image     = "nginx:latest"
      essential = true
      
      # Prepare custom nginx configuration with CORS headers enabled for service discovery test
      command = [
        "/bin/sh", 
        "-c", 
        "echo 'server { listen 80; server_name localhost; location / { add_header Access-Control-Allow-Origin \"*\"; root /usr/share/nginx/html; index index.html; } }' > /etc/nginx/conf.d/default.conf && echo '<html><body style=\"background-color: ${count.index == 0 ? "#e6f7ff" : "#ffe6e6"}\"><h1>This is service${count.index == 0 ? "A" : "B"} in cluster $CLUSTER_NAME</h1><p>Container ID: '$(hostname)'</p><div id=\"result\"><h2>Service Discovery Test:</h2><p>Click the button to test connection to service${count.index == 0 ? "B" : "A"}</p><button onclick=\"testServiceDiscovery()\">Test Connection</button><div id=\"response\"></div></div><script>function testServiceDiscovery() {document.getElementById(\"response\").innerHTML = \"<p>Testing connection...</p>\";fetch(\"http://service${count.index == 0 ? "b" : "a"}\", {method: \"GET\"}).then(response => response.text()).then(data => {const parser = new DOMParser();const htmlDoc = parser.parseFromString(data, \"text/html\");const title = htmlDoc.querySelector(\"h1\").textContent;document.getElementById(\"response\").innerHTML = \"<p>Connected successfully! Response: \" + title + \"</p>\";}).catch(error => {document.getElementById(\"response\").innerHTML = \"<p>Error: \" + error + \"</p>\";})}</script></body></html>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"
      ]
      
      # Environment variables to identify the cluster
      environment = [
        {
          name = "CLUSTER_NAME",
          value = "cluster${count.index == 0 ? "1" : "2"}"
        }
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

# Update ECS services with load balancer registration
resource "aws_ecs_service" "services" {
  count           = 4
  name            = "${var.projectName}-service${count.index % 2 == 0 ? "A" : "B"}"
  cluster         = aws_ecs_cluster.clusters[floor(count.index / 2)].id
  task_definition = aws_ecs_task_definition.services[count.index % 2].arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
  
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.namespace[floor(count.index / 2)].arn
    
    service {
      client_alias {
        port     = 80
        dns_name = "service${count.index % 2 == 0 ? "a" : "b"}"
      }
      port_name      = "http"
      discovery_name = "service${count.index % 2 == 0 ? "a" : "b"}"
    }
  }
  
  # Register with load balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.service_tg[count.index].arn
    container_name   = "${var.projectName}-service${count.index % 2 == 0 ? "A" : "B"}"
    container_port   = 80
  }
}
