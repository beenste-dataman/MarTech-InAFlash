provider "aws" {
  region = "us-east-1" # Choose the appropriate AWS region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.routetable.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ec2_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0" # Replace this with the latest relevant AMI for your region
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.allow_web.name]

  tags = {
    Name = "MarketingWebServer"
  }
}

resource "aws_rds_cluster" "marketing_db" {
  engine               = "aurora-postgresql"
  engine_version       = "12.4"
  cluster_identifier   = "marketing-db-cluster"
  master_username      = "dbadmin"
  master_password      = "yourpassword" # Replace with a secure password or use the AWS Secrets Manager
  db_subnet_group_name = aws_db_subnet_group.main.name

  tags = {
    Name = "MarketingDBCluster"
  }
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = "marketing-data-bucket-${random_id.bucket_id.hex}"
  acl    = "private"
}

resource "random_id" "bucket_id" {
  byte_length = 8
}

resource "aws_redshift_cluster" "data_warehouse" {
  cluster_identifier = "redshift-marketing-cluster"
  database_name      = "marketingdw"
  master_username    = "dwadmin"
  master_password    = "yourpassword" # Replace with a secure password or use the AWS Secrets Manager
  node_type          = "dc2.large"
  cluster_type       = "single-node"

  tags = {
    Name = "MarketingDataWarehouse"
  }
}

# Note: For RDS and Redshift, consider using a private subnet and not exposing them to the public internet for security reasons.

output "web_server_ip" {
  value = aws_ec2_instance.web_server.public_ip
}

output "marketing_db_endpoint" {
  value = aws_rds_cluster.marketing_db.endpoint
}

output "redshift_cluster_endpoint" {
  value = aws_redshift_cluster.data_warehouse.endpoint
}
