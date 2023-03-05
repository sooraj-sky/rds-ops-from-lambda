
resource "random_password" "rds_password" {
  length = 16
  special = false
}

# Create a KMS key to encrypt the password
resource "aws_kms_key" "mysqlkey" {
  description = "KMS key to encrypt MYSQL RDS password"
}

# Save the password to SSM Parameter Store with KMS encryption
resource "aws_ssm_parameter" "rds_password" {
  name      = "/rds/mysql/masterpassword"
  type      = "SecureString"
  value     = random_password.rds_password.result
  key_id    = aws_kms_key.mysqlkey.key_id
  overwrite = true
}

# Create an RDS instance using the password retrieved from SSM
resource "aws_db_instance" "mysqldb" {
  allocated_storage    = 10
  storage_type         = "gp2"
  identifier           = "example-db"
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = var.mysqluser
  password             = aws_ssm_parameter.rds_password.value
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}