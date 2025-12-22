#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

#Define the VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "demo_environment"
    Terraform   = "true"
  }
}

#Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = data.aws_availability_zones.available.names[each.value]

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

#Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = data.aws_availability_zones.available.names[each.value]
  map_public_ip_on_launch = true

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}


#Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_private_rtb"
    Terraform = "true"
  }
}

#Create the route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

#Create the Intenet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo_igw"
  }
}

/**This config bellow may cause some extra charges by aws**/
#Create EIP for NAT Gatewat
# resource "aws_eip" "nat_gateway_eip" {
#   domain = "vpc"
#   depends_on = [ aws_internet_gateway.internet_gateway ]
#   tags = {
#     Name = "demo_igw_eip"
#   }
# }

#Create NAT Gateway
# resource "aws_nat_gateway" "nat_gateway" {
#   depends_on = [ aws_subnet.public_subnets ]
#   allocation_id = aws_eip.nat_gateway_eip.id
#   subnet_id = aws_subnet.public_subnets["public_subnet_1"].id
#   tags = {
#     Name = "demo_nat_gateway"
#   }
# }

#Creating the security Group
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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

  tags = {
    Name = "web-sg"
  }
}

#Create the aws instance
resource "aws_instance" "web" {
  ami                    = "ami-0fd67c67853eafcef"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnets["public_subnet_1"].id
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    "Name"      = "demo-ec2"
    "Terraform" = "true"
  }
}

#Create the S3 Bucket
resource "aws_s3_bucket" "my-new-s3-bucket" {
  bucket = "my-new-tf-test-bucket-ilyass003"

  tags = {
    Name    = "My S3 Bucket"
    Purpose = "Resource block of S3 Bucket aws"
  }
}

#Create the S3 bucket ACL
resource "aws_s3_bucket_acl" "my_new_bucket_acl" {
  bucket = aws_s3_bucket.my-new-s3-bucket.id
  acl    = "private"
}

#Create a new security Group
resource "aws_security_group" "my-new-security-group" {
  name        = "web_servre_inbouned"
  description = "Allow inbouned traffic on tcp/443"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow 443 from the Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "web_server_inbound"
    Purpose = "My resource Blocks"
  }
}
