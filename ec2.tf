# EC2 Instance
resource "aws_instance" "web_server" {
  ami                         = "ami-0261755bbcb8c4a84"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.main.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Deployed by Olusola Alonge - DMI Cohort-2</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "terraform-ec2"
  }
}

# Output Public IP
output "instance_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "Public IP of the EC2 instance"
}

output "website_url" {
  value       = "http://${aws_instance.web_server.public_ip}"
  description = "Website URL"
}