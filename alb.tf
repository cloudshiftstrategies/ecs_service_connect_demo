# Create load balancer
resource "aws_lb" "cluster_lb" {
  name               = "${var.projectName}-${var.clusterName}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = aws_subnet.public[*].id
  
  tags = {
    Name = "${var.projectName}-${var.clusterName}-lb"
  }
}

# Create target groups for each service
resource "aws_lb_target_group" "service_tg" {
  for_each    = toset(["A", "B"])
  name        = "${var.projectName}-${var.clusterName}-tg-s${lower(each.key)}"
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

# Create listener - routing to different services based on path
resource "aws_lb_listener" "cluster_listener" {
  load_balancer_arn = aws_lb.cluster_lb.arn
  port              = 80
  protocol          = "HTTP"
  
  # Default action routes to ServiceA
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_tg["A"].arn
  }
}

# Add listener rule for ServiceB on path /serviceb
resource "aws_lb_listener_rule" "serviceb_rule" {
  listener_arn = aws_lb_listener.cluster_listener.arn
  priority     = 100
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_tg["B"].arn
  }
  
  condition {
    path_pattern {
      values = ["/serviceb*"]
    }
  }
}

# Output load balancer URL
output "public_endpoint" {
  value = aws_lb.cluster_lb.dns_name
  description = "Public URL for the cluster's load balancer (default path for ServiceA, /serviceb for ServiceB)"
}
