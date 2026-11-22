# RDS MySQL Database
resource "aws_db_instance" "mysql" {
  identifier              = "pasalapeli-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  name                    = "pasalapeli_db"
  username                = "admin"
  password                = random_password.db_password.result
  parameter_group_name    = "mysql8.0"
  skip_final_snapshot     = true
  publicly_accessible     = false
  storage_type            = "gp2"
  allocated_storage       = 20
  name                    = "pasalapeli_db"
  backup_retention_period = 7
  monitor_iam_authentication_enabled = true
  
  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-db"
  }
}

# Generated password
resource "random_password" "db_password" {
  length  = 16
  special_chars = true
}
