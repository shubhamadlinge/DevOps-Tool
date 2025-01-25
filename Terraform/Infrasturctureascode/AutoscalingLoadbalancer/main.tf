resource "aws_launch_template" "example" {
  name = "example-launch-template"

  image_id      = "ami-id"  # Replace with your appropriate AMI ID
  instance_type = "t2.micro"  # Adjust instance type as needed
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Base64 encode the user_data
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              mkdir -p /var/www/html/mobile-app
              mkdir -p /var/www/html/laptop-app

              # Mobile app index.html
              cat <<EOF1 > /var/www/html/mobile-app/index.html
              <html>
              <head><title>Mobile App</title></head>
              <body>
                <h1>Welcome to the Mobile App!</h1>
                <p>This is a simple page for the mobile app.</p>
              </body>
              </html>
              EOF1

              # Laptop app index.html
              cat <<EOF2 > /var/www/html/laptop-app/index.html
              <html>
              <head><title>Laptop App</title></head>
              <body>
                <h1>Welcome to the Laptop App!</h1>
                <p>This is a simple page for the laptop app.</p>
              </body>
              </html>
              EOF2

              chown -R apache:apache /var/www/html
              systemctl restart httpd

              # Home page with instructions
              echo "<h1>HOME PAGE add /mobile-app /laptop-app" > /var/www/html/index.html
              EOF
            )

  lifecycle {
    create_before_destroy = true
  }
}



# Auto Scaling Group with Target Groups
resource "aws_autoscaling_group" "example_asg" {
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  vpc_zone_identifier = ["subnet-093ed954c868e9f49", "subnet-03262313beb47a58f"]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2

  health_check_type         = "EC2"
  health_check_grace_period = 300

  target_group_arns = [
    aws_lb_target_group.lb_tg_home.arn,  # Home target group
    aws_lb_target_group.lb_tg_laptop.arn # Laptop target group
  ]

  tag {
    key                 = "Name"
    value               = "example-asg"
    propagate_at_launch = true
  }
}

# Target Group for Home Page
resource "aws_lb_target_group" "lb_tg_home" {
  name     = "lb-tg-home"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-013090b88cc0b8d28"

  health_check {
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Target Group for Laptop App
resource "aws_lb_target_group" "lb_tg_laptop" {
  name     = "lb-tg-laptop"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-013090b88cc0b8d28"

  health_check {
    path                = "/laptop/"
    port                = 80
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Application Load Balancer Setup
resource "aws_lb" "my_lb" {
  name               = "my-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]  # Referencing the security group
  subnets            = ["subnet-03262313beb47a58f", "subnet-093ed954c868e9f49"]  # Subnets to use for the load balancer

  tags = {
    app = "my-lb"
  }
}

# Load Balancer Listener Setup
resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg_home.arn
  }
}

# Load Balancer Listener Rule for Laptop App Routing
resource "aws_lb_listener_rule" "my_lb_listener_rule" {
  listener_arn = aws_lb_listener.my_lb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg_laptop.arn
  }

  condition {
    path_pattern {
      values = ["/laptop/*"]
    }
  }
}