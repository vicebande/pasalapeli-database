# RDS MySQL Database (infra compartida - propietario: pasalapeli-database)

resource "random_password" "db_password" {
  length           = 16
  override_special = "@#%&*"
}

resource "aws_db_parameter_group" "mysql80" {
  name        = "pasalapeli-mysql80"
  family      = "mysql8.0"
  description = "Parameter group for pasalapeli MySQL 8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-mysql80"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "pasalapeli-db-subnet-group"
  subnet_ids = data.aws_subnets.private.ids

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
  identifier              = "pasalapeli-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  username                = "admin"
  password                = random_password.db_password.result
  parameter_group_name    = aws_db_parameter_group.mysql80.name
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  storage_type            = "gp2"
  allocated_storage       = 20
  backup_retention_period = 7
  multi_az                = false
  storage_encrypted       = true

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-db"
  }
}
