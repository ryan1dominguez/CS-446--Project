resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "ha-dr-db-password-v3"
  recovery_window_in_days = 0
  
  tags = {
    Name = "ha-dr-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "aws_db_subnet_group" "main" {
  name       = "ha-dr-db-subnet-group"
  subnet_ids = local.available_subnet_ids

  tags = {
    Name = "ha-dr-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "ha-dr-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = data.aws_vpc.default.id

  
  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #demo purposes only
    //security_groups = [aws_security_group.app.id]
  }

  tags = {
    Name = "ha-dr-rds-sg"
  }
}

resource "aws_db_instance" "primary" {
  identifier     = "ha-dr-orders-db"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "orders_db"
  username = "postgres"
  password = random_password.db_password.result

  multi_az = false

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = true
  performance_insights_retention_period = 7

  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "ha-dr-primary-db"
  }
}

//Create key for replica encryption
data "aws_kms_key" "rds_west" {
  provider = aws.secondary
  key_id = "alias/aws/rds"
}

//Replica DB
data "aws_subnet" "all_secondary" {
  provider = aws.secondary 
  for_each = toset(data.aws_subnets.default_secondary.ids)
  id       = each.value
}

locals {
  available_subnet_ids_secondary = [
    for subnet in data.aws_subnet.all_secondary: subnet.id
  ]
}

resource "aws_db_subnet_group" "replica" {
  provider   = aws.secondary
  name       = "ha-dr-db-subnet-group-replica"
  subnet_ids = local.available_subnet_ids_secondary

  tags = {
    Name = "ha-dr-db-subnet-group-replica"
  }
}

resource "aws_security_group" "rds_replica" {
  provider    = aws.secondary
  name        = "ha-dr-rds-sg-replica"
  description = "Replica Security group for RDS PostgreSQL"
  vpc_id      = data.aws_vpc.default_secondary.id

  
  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_secondary.id]
  }

  tags = {
    Name = "ha-dr-rds-sg-replica"
  }
}

resource "aws_db_instance" "replica" {
  provider       = aws.secondary
  identifier     = "ha-dr-orders-db-replica"
  replicate_source_db = aws_db_instance.primary.arn //REPLICATE FROM PRIMARY DB
  
  instance_class = "db.t3.micro" //Needs to be same size as replica

  db_subnet_group_name   = aws_db_subnet_group.replica.name
  vpc_security_group_ids = [aws_security_group.rds_replica.id]
  publicly_accessible    = false

  auto_minor_version_upgrade = true
  backup_retention_period = 7 //7 day backup  
  skip_final_snapshot = true
  deletion_protection = false

  performance_insights_enabled    = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports = ["postgresql"]

  storage_encrypted     = true
  kms_key_id            = data.aws_kms_key.rds_west.arn
    
  
  tags = {
    Name = "ha-dr-replica-db"
  }
}