# Create one load balancer per cluster
resource "aws_lb" "cluster_lb" {
  count              = 2  # One for each cluster
  name               = "${var.projectName}-lb-cluster-${count.index + 1}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = aws_subnet.public[*].id
  
  tags = {
    Name = "${var.projectName}-lb-cluster-${count.index + 1}"
  }
}

# Create target groups for each service in each cluster
resource "aws_lb_target_group" "service_tg" {
  count       = 4  # One for each service in each cluster
  name        = "${var.projectName}-tg-c${floor(count.index / 2) + 1}-s${count.index % 2 == 0 ? "a" : "b"}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Create listeners for each load balancer - routing to different services based on path
resource "aws_lb_listener" "cluster_listener" {
  count             = 2  # One for each cluster
  load_balancer_arn = aws_lb.cluster_lb[count.index].arn
  port              = 80
  protocol          = "HTTP"
  
  # Default action routes to ServiceA
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_tg[count.index * 2].arn  # ServiceA for this cluster
  }
}

# Add listener rule for ServiceB on path /serviceb
resource "aws_lb_listener_rule" "serviceb_rule" {
  count        = 2  # One for each cluster
  listener_arn = aws_lb_listener.cluster_listener[count.index].arn
  priority     = 100
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_tg[count.index * 2 + 1].arn  # ServiceB for this cluster
  }
  
  condition {
    path_pattern {
      values = ["/serviceb*"]
    }
  }
}

# Output load balancer URLs
output "public_endpoints" {
  value = {
    cluster1 = aws_lb.cluster_lb[0].dns_name
    cluster2 = aws_lb.cluster_lb[1].dns_name
  }
  description = "Public URLs for each cluster's load balancer (default path for ServiceA, /serviceb for ServiceB)"
}
