
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

# Create a new VPC
resource "aws_vpc" "mysql_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create public and private subnets within the VPC
resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.mysql_vpc.id
    cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "private_subnet" {
    vpc_id = aws_vpc.mysql_vpc.id
    cidr_block = "10.0.2.0/24"
     availability_zone = "us-east-1a"
}
resource "aws_subnet" "private_subnet2" {
    vpc_id = aws_vpc.mysql_vpc.id
    cidr_block = "10.0.3.0/24"
     availability_zone = "us-east-1b"
}

resource "aws_subnet" "private_subnet3" {
    vpc_id = aws_vpc.mysql_vpc.id
    cidr_block = "10.0.4.0/24"
}

# Create an internet gateway and attach it to the VPC
resource "aws_internet_gateway" "mysql_gateway" {
    vpc_id = aws_vpc.mysql_vpc.id
}

# Create a route table for the public subnet
resource "aws_route_table" "mysql_public_route" {
    vpc_id = aws_vpc.mysql_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.mysql_gateway.id
    }
  
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "mysql_public_association" {
     subnet_id      = aws_subnet.public_subnet.id
     route_table_id = aws_route_table.mysql_public_route.id
  
}

# Create a DB subnet group for the private subnet
resource "aws_db_subnet_group" "example" {
  name        = "example-db-subnet-group"
  description = "Subnet group for the RDS instance"
  subnet_ids  = [aws_subnet.private_subnet.id,aws_subnet.private_subnet2.id,aws_subnet.private_subnet3.id]
}

# Create a security group for the RDS instance
resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg-"
  vpc_id      = aws_vpc.mysql_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet.cidr_block]
  }
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
  db_subnet_group_name     = aws_db_subnet_group.example.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  tags = {
    Name = "example-db-instance"
  }
}


resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Owner       = "example"
  }
}


# Create a Lambda function
resource "aws_lambda_function" "example" {
  filename         = "example.zip"
  function_name    = "example-function"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "main.handler"
  source_code_hash = filebase64sha256("example.zip")
  runtime          = "python3.8"
  timeout          = 60
  memory_size      = 128

  # Set environment variables to provide the RDS connection information
  environment {
    variables = {
      RDS_HOST     = aws_db_instance.mysqldb.address
      RDS_USERNAME = var.mysqluser
      RDS_PASSWORD = aws_ssm_parameter.rds_password.value
    }
  }
}

# Grant the Lambda function permission to access the RDS instance
resource "aws_lambda_permission" "example" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.example.arn
}

# Create a CloudWatch event rule to trigger the Lambda function
resource "aws_cloudwatch_event_rule" "example" {
  name        = "example-event-rule"
  description = "Trigger Lambda function on schedule"

  schedule_expression = "cron(0 12 * * ? *)"
}

resource "aws_cloudwatch_event_target" "example_target" {
  rule  = "${aws_cloudwatch_event_rule.example.name}"
  arn   = "${aws_lambda_function.example.arn}"
}