#Creating the vpc
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
tags = {
    Name = "${var.name}-vpc"
  }
}

# create public subnet 1
resource "aws_subnet" "pub_sub1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az1

  tags = {
    Name = "${var.name}-pub_sub1"
  }
}

# create public subnet 2
resource "aws_subnet" "pub_sub2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.az2

  tags = {
    Name = "${var.name}-pub_sub2"
  }
}

# create private subnet 1
resource "aws_subnet" "pri_sub1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az1

  tags = {
    Name = "${var.name}-pri_sub1"
  }
}

# create private subnet 2
resource "aws_subnet" "pri_sub2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.az2

  tags = {
    Name = "${var.name}-pri_sub2"
  }
}

# create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# create elastic ip for NAT gateway
resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-eip"
  }
}

# create NAT gateway
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.pub_sub1.id

  tags = {
    Name = "${var.name}-ngw"
  }
  depends_on = [aws_eip.eip] # Ensuring the EIP is created first
}


# Create route table for public subnets
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.name}-pub_rt"
  }
}

# Create route table for private subnets
resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }
  tags = {
    Name = "${var.name}-pri_rt"
  }
}

# Creating route table association for public_subnet_1
resource "aws_route_table_association" "ass-public_subnet_1" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.pub_rt.id
}

# Creating route table association for public_subnet_2
resource "aws_route_table_association" "ass-public_subnet_2" {
  subnet_id      = aws_subnet.pub_sub2.id
  route_table_id = aws_route_table.pub_rt.id
}

# Creating route table association for private_subnet_1
resource "aws_route_table_association" "ass-private_subnet_1" {
  subnet_id      = aws_subnet.pri_sub1.id
  route_table_id = aws_route_table.pri_rt.id
}

# Creating route table association for private_subnet_2
resource "aws_route_table_association" "ass-private_subnet_2" {
  subnet_id      = aws_subnet.pri_sub2.id
  route_table_id = aws_route_table.pri_rt.id
}


# Generate a new private key
#resource "tls_private_key" "auto_discovery" {
 # algorithm = "RSA"
  #rsa_bits  = 4096
#}

# Create the key pair in AWS using the public key
#resource "aws_key_pair" "auto_discovery_key_pair" {
 # key_name   = "${var.name}-key"
  #public_key = tls_private_key.auto_discovery.public_key_openssh
#}

# Save private key to a PEM file (make sure 'generated' folder exists)
#resource "local_file" "private_key_pem" {
 # filename        = "${path.module}/generated/auto-discovery-key.pem"
  #content         = tls_private_key.auto_discovery.private_key_pem
  #file_permission = "0400"
#}

#resource "aws_instance" "example" {
 # ami           = "ami-xyz" # Replace with your AMI ID
  #instance_type = "t2.micro"
  #key_name      = aws_key_pair.auto_discovery_key_pair.key_name

  # ... your other configuration
#}


#creating keypair RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#resource "tls_private_key" "ssh" {
  #algorithm = "RSA"
  #rsa_bits  = 4096
#}

# Creating private key
resource "local_file" "private-key" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "${var.name}-key.pem"
  file_permission = 440
}

# Creating public key 
resource "aws_key_pair" "public-key" {
  key_name   = "${var.name}-infra-key"
  public_key = tls_private_key.keypair.public_key_openssh
   
   lifecycle {
    prevent_destroy = false
  }
}

#resource "aws_key_pair" "generated" {
 # key_name   = "${var.name}-key"
  #public_key = tls_private_key.ssh.public_key_openssh

   #  lifecycle {
    #prevent_destroy = false
 #
  
#}

