######################################
# This is the database. SQL style... #
######################################

resource "aws_db_subnet_group" "main" {
  name = "${local.prefix}-main"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "${local.prefix}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  description = "Allows access to RDS r/w"
  name        = "${local.prefix}-db-security-group"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol  = "tcp"
    from_port = 5432
    to_port   = 5432
  }

  tags = {
    Name = "${local.prefix}-db-security-group"
  }
}

resource "aws_db_instance" "main" {
  identifier                 = "${local.prefix}-db"
  db_name                    = "recipe"
  allocated_storage          = 100   # in gb. Min size of io1 and postgres
  storage_type               = "io1" # "gp2" for simplest
  engine                     = "postgres"
  engine_version             = "15.13"
  auto_minor_version_upgrade = true
  instance_class             = "db.t4g.micro" # "db.t4g.micro" for simplest
  iops                       = 2000           # 50x100 = 5000. 5000 would be the max here
  username                   = var.db_username
  password                   = var.db_password
  skip_final_snapshot        = true
  db_subnet_group_name       = aws_db_subnet_group.main.name
  multi_az                   = false
  backup_retention_period    = 0
  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  tags = {
    Name = "${local.prefix}-main"
  }
}