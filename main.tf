
provider "aws" {

  region = "us-east-1"
  access_key = "AKIAUF3DAAW57T77IPXJ"
  secret_key = "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"
}

#1. Create vpc

resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "Production vpc"
    }
}

#2. Create Internet aws_internet_gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "Production gw"
  }
}

#3. create a Route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod oute table"
  }
}

resource "aws_subnet" "subnet-1" {
    vpc_id     = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    tags = {
        Name = "Prod"
    }
}

#Connect Subnet to the route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

#Create a Security Group

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_web"
  }
}

#Create Network Interface

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  }

  #Create Elastic IP

  resource "aws_eip" "one" {
  vpc                   = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
  }

#Create ubuntu

resource "aws_instance" "web-server" {
    ami = "ami-0fc5d935ebf8bc3bc"
    instance_type = "t2.micro"
    availability_zone = "us-east-1b"
    key_name = "main-key"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-nic.id
    }

    tags = {
    Name = "Ubuntu-web"
    }

user_data = <<-EOF
            #!BIN/BAS
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo your very first web server > /var/www/html/index.html'
            EOF
}

