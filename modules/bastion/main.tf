terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM Role for SSM Session Manager ────────────────────────────────────────

resource "aws_iam_role" "bastion" {
  name = "emr-${var.env}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "emr-${var.env}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# ── Security Group ──────────────────────────────────────────────────────────
# No inbound ports needed — SSM Session Manager uses outbound HTTPS only.

resource "aws_security_group" "bastion" {
  name        = "emr-${var.env}-bastion-sg"
  vpc_id      = var.vpc_id
  description = "Bastion host - SSM Session Manager (no inbound ports)"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "emr-${var.env}-bastion-sg" }
}

# ── Allow bastion → RDS on 3306 ────────────────────────────────────────────

resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.rds_sg_id
  source_security_group_id = aws_security_group.bastion.id
  description              = "MariaDB from bastion"
}

# ── EC2 Instance ────────────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  tags = { Name = "emr-${var.env}-bastion" }
}
