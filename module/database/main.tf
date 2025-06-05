#  RDS Subnet Group
resource "aws_db_subnet_group" "auto_db_subnet_group" {
  name        = "${var.name}-db_subnet-v2"
  subnet_ids  = [var.pri-sub-1, var.pri-sub-2] # Use private subnets for security
  description = "Subnet group for Multi-AZ RDS deployment"

  tags = {
    Name = "${var.name}-db-Subnet-Group"
  }
}
data "vault_generic_secret" "vault-secret" {
  path = "secret/database"
}


resource "aws_db_instance" "auto_mysql_database" {
  identifier             =  "${var.name}-db_subnet-v2"
  db_subnet_group_name   = aws_db_subnet_group.auto_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.RDS-sg.id]
  db_name                = "petadoption"
  # High Availability
  multi_az = false

  # Engine Settings
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  parameter_group_name = "default.mysql5.7"

  # Storage
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true
  # Credentials (Fetch from Vault Manager)
  username = data.vault_generic_secret.vault-secret.data["username"]
  password = data.vault_generic_secret.vault-secret.data["password"]
  # Backup & Maintenance
  skip_final_snapshot = true
  # Security
  publicly_accessible = false
  deletion_protection = false
}
#RDS security group
resource "aws_security_group" "RDS-sg" {
  name        = "${var.name}-rds-sg"
  description = "RDS Security group"
  vpc_id      = var.vpc-id

  ingress {
    description     = "mysqlport"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.bastion_sg, var.stage-sg, var.prod-sg]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-rds-sg"
  }
}