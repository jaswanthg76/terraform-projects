terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
    region = "ap-south-1"
}


resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
    
    
    tags = {
      Name = "subnet-1a"
    }
}

resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-1b"
  }
}

resource "aws_subnet" "subnet-3" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-south-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-1c"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Main Gateway"
  }
}

resource "aws_route_table" "main-route-table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.main-route-table.id
}

resource "aws_route_table_association" "b" {
    subnet_id = aws_subnet.subnet-2.id
    route_table_id = aws_route_table.main-route-table.id
}

resource "aws_route_table_association" "c" {
    subnet_id = aws_subnet.subnet-3.id
    route_table_id = aws_route_table.main-route-table.id
}
resource "aws_security_group" "node-red" {
    name = "nodered"
    
    vpc_id = aws_vpc.main_vpc.id

    ingress{
        from_port = 1880
        to_port = 1880
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress{
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress{
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}

resource "aws_security_group" "fast-api" {
    name = "fast-api"
  
    vpc_id = aws_vpc.main_vpc.id

    ingress{
        from_port = 8000
        to_port = 8000
        protocol = "tcp"
        cidr_blocks = ["10.0.1.0/24"]
        security_groups = [aws_security_group.node-red.id]
    }

    egress{
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "nginx-web" {
    name = "nginx web"
    
    vpc_id = aws_vpc.main_vpc.id

   

    egress{
        from_port = 8000
        to_port = 8000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress{
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "rds-db" {
    name = "allow sql commands"
    description = "allows traffic to database from "
    vpc_id = aws_vpc.main_vpc.id

   

    ingress{
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        
    }
    egress{
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        
    }
}

resource "aws_instance" "NODE_RED" {
  ami = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet-1.id
  security_groups = [aws_security_group.node-red.id]
  key_name = "key_pair"
  user_data = <<-EOF
              #!/bin/bash
              # Update the package repository
              sudo apt-get update

              # Install Node.js and npm
              sudo apt-get install -y nodejs npm

              # Install Node-RED globally
              sudo npm install -g --unsafe-perm node-red

              # Create a systemd service file for Node-RED
              echo "[Unit]
              Description=Node-RED
              After=network.target

              [Service]
              ExecStart=/usr/bin/node-red
              Restart=on-failure
              User=ubuntu
              Group=ubuntu
              Environment="NODE_RED_OPTIONS=-v"

              [Install]
              WantedBy=multi-user.target" | sudo tee /etc/systemd/system/node-red.service

              # Reload systemd and enable the Node-RED service
              sudo systemctl daemon-reload
              sudo systemctl enable node-red
              sudo systemctl start node-red
              EOF

  tags = {
    Name = "NODE_RED"
  }
}

resource "aws_eip" "node-red-eip" {
   instance= aws_instance.NODE_RED.id
   domain = "vpc"
}




resource "aws_instance" "FAST_API" {
  ami = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet-2.id
  security_groups = [aws_security_group.fast-api.id]
  key_name = "key_pair"
  user_data = <<-EOF
              #!/bin/bash
              # Update the package repository
              sudo apt-get update

              # Install Python3 and pip
              sudo apt-get install -y python3 python3-pip

              # Install FastAPI and Uvicorn
              sudo pip3 install fastapi uvicorn

              # Create a sample FastAPI app
              echo "from fastapi import FastAPI

              app = FastAPI()

              @app.get('/')
              def read_root():
                  return {'Hello': 'World'}" > /home/ubuntu/main.py

              # Create a systemd service file for FastAPI
              echo "[Unit]
              Description=FastAPI
              After=network.target

              [Service]
              ExecStart=/usr/local/bin/uvicorn main:app --host 0.0.0.0 --port 8000
              WorkingDirectory=/home/ubuntu
              Restart=always
              User=ubuntu

              [Install]
              WantedBy=multi-user.target" | sudo tee /etc/systemd/system/fastapi.service

              # Reload systemd and enable the FastAPI service
              sudo systemctl daemon-reload
              sudo systemctl enable fastapi
              sudo systemctl start fastapi
              EOF
  tags = {
    Name = "FAST_API"
  }
}
resource "aws_eip" "fast-api-eip" {
   instance= aws_instance.FAST_API.id
   domain = "vpc"
}

resource "aws_instance" "NGINX_WEB" {
  ami = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet-2.id
  security_groups = [aws_security_group.nginx-web.id]
  key_name = "key_pair"
  user_data = <<-EOF
              #!/bin/bash
              # Update the package repository
              sudo apt-get update

              # Install Nginx
              sudo apt-get install -y nginx

              # Start and enable Nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              EOF 
  
  tags = {
    Name = "NGINX_WEB"
  }
}

resource "aws_eip" "nginx-web-eip" {
   instance= aws_instance.NGINX_WEB.id
   domain = "vpc"
}


resource "aws_db_subnet_group" "db-subnet-group" {
  name = "db-subnet-group"
  subnet_ids = [aws_subnet.subnet-2.id, aws_subnet.subnet-1.id,aws_subnet.subnet-3.id]
}

resource "aws_db_instance" "DB" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "jas"
  password             = "123456789"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.rds-db.id]
  db_subnet_group_name = aws_db_subnet_group.db-subnet-group.name

  tags = {
    Name = "SQL Database"
  }
}