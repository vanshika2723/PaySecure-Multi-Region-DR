resource "aws_security_group" "primary_application" {
  provider = aws.primary

  name        = "${var.project_name}-primary-application"
  description = "PaySecure primary application security group"
  vpc_id      = module.primary_networking.vpc_id

  ingress {
    description = "HTTPS application traffic"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP health checks"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound application traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-primary-application"
    RegionRole = "primary"
  })
}

resource "aws_security_group" "dr_application" {
  provider = aws.dr

  name        = "${var.project_name}-dr-application"
  description = "PaySecure DR application security group"
  vpc_id      = module.dr_networking.vpc_id

  ingress {
    description = "HTTPS application traffic"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP health checks"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound application traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-dr-application"
    RegionRole = "dr"
  })
}

resource "aws_security_group" "primary_database" {
  provider = aws.primary

  name        = "${var.project_name}-primary-database"
  description = "PaySecure primary database security group"
  vpc_id      = module.primary_networking.vpc_id

  ingress {
    description     = "PostgreSQL from primary application VPC"
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.primary_application.id]
  }

  egress {
    description = "Database outbound traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-primary-database"
    RegionRole = "primary"
  })
}

resource "aws_security_group" "dr_database" {
  provider = aws.dr

  name        = "${var.project_name}-dr-database"
  description = "PaySecure DR database security group"
  vpc_id      = module.dr_networking.vpc_id

  ingress {
    description     = "PostgreSQL from DR application VPC"
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.dr_application.id]
  }

  egress {
    description = "Database outbound traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-dr-database"
    RegionRole = "dr"
  })
}

resource "aws_security_group" "primary_kafka" {
  provider = aws.primary

  name        = "${var.project_name}-primary-kafka"
  description = "PaySecure primary MSK security group"
  vpc_id      = module.primary_networking.vpc_id

  ingress {
    description     = "TLS Kafka traffic"
    protocol        = "tcp"
    from_port       = 9094
    to_port         = 9094
    cidr_blocks     = [module.primary_networking.vpc_cidr]
  }

  egress {
    description = "Kafka outbound traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-primary-kafka"
    RegionRole = "primary"
  })
}

resource "aws_security_group" "dr_kafka" {
  provider = aws.dr

  name        = "${var.project_name}-dr-kafka"
  description = "PaySecure DR MSK security group"
  vpc_id      = module.dr_networking.vpc_id

  ingress {
    description     = "TLS Kafka traffic"
    protocol        = "tcp"
    from_port       = 9094
    to_port         = 9094
    cidr_blocks     = [module.dr_networking.vpc_cidr]
  }

  egress {
    description = "Kafka outbound traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-dr-kafka"
    RegionRole = "dr"
  })
}

