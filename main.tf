provider "aws" {
    region = "ap-south-1"
}

terraform {
  backend "s3" {
    bucket        = "terraform-s3-bucket-31102025"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    use_lockfile = true
    encrypt        = true
  }
}

resource "tls_private_key" "keygen" {
  rsa_bits = 4096
  algorithm = "RSA"
}

resource "aws_key_pair" "terraform_key" {
  key_name = "terraform-key"
  public_key = tls_private_key.keygen.public_key_openssh
}

resource "local_file" "private_key_pem" {
  filename = "${path.module}/terraform-key.pem"
  content  = tls_private_key.keygen.private_key_pem
  file_permission = "0400"
}

resource "aws_vpc" "demo_vpc" {
    cidr_block = "10.0.0.0/24"
    tags = {
        Name = "terraform-VPC"
    }
}

resource "aws_subnet" "name" {
  vpc_id = aws_vpc.demo_vpc.id
  availability_zone = "ap-south-1a"
  cidr_block = "10.0.0.0/25"
  tags = {
    Name = "terraform-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.demo_vpc.id
    tags = {
        Name = "terraform-igw"
    }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.demo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "terraform-public-rt"
  }
}

resource "aws_route_table_association" "route_table_association" {
    subnet_id = aws_subnet.name.id
    route_table_id = aws_route_table.route_table.id
  
}

resource "aws_security_group" "security_group" {
    name = "terraform-web-sg"
    description = "Allow http,https and ssh"
    vpc_id = aws_vpc.demo_vpc.id

    tags = {
        Name = "security_group"
    }

    ingress {
        description = "Allow ssh"
        protocol = "tcp"
        from_port = 22
        to_port = 22
        cidr_blocks = ["103.70.199.106/32"]
    }
    
    ingress {
        description = "Allow http"
        protocol = "tcp"
        from_port = 80
        to_port = 80
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    ingress {
        description = "Allow https"
        protocol = "tcp"
        from_port = 443
        to_port = 443
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    egress {
        description = "Allow all outbound"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "ec2-instance" {
    ami = "ami-01ca13db604661046"
    instance_type = "t3.micro"
    subnet_id = aws_subnet.name.id
    vpc_security_group_ids = [ aws_security_group.security_group.id ]
    key_name = "terraform-key"

    user_data = <<-EOF
              #!/bin/bash
              #!/bin/bash
                # Update the system
                yum update -y

                # Install Apache web server
                yum install -y httpd

                # Start and enable Apache
                systemctl start httpd
                systemctl enable httpd

                # Create a simple HTML file
                echo "<h1>Welcome to My Static Website!</h1>
                <p>This page is served from an EC2 instance using user_data.</p>" > /var/www/html/index.html

                # Optional: Add a custom message or hostname
                echo "<p>Server Hostname: $(hostname)</p>" >> /var/www/html/index.html
              EOF
    tags = {
        Name = "terraform-bookmyshow-server"
    }

}

resource "aws_eip" "web_eip" {
  instance = aws_instance.ec2-instance.id

  tags = {
    Name = "terraform-eip"
  }
}

output "public_ip" {
  value = aws_eip.web_eip.public_ip
}

