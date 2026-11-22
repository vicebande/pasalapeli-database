# EKS Cluster Resources

# ECR Repository for frontend
resource "aws_ecr_repository" "frontend" {
  name                 = "pasalapeli-frontend"
  image_scanning_configuration {
    scan_type = "BASIC"
  }
  
  lifecycle_rule {
    expiration {
      days = 30
    }
    tag_status = "tagged"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "primary" {
  name                     = "pasalapeli-cluster"
  subnet_ids           = data.aws_subnet_ids.private.ids
  vpc_id               = data.aws_vpc.main.id
  role_arn             = aws_iam_role.eks_cluster.arn
  skip_user_creation   = true
  certificate_authority_data = data.aws_eks_cluster_auth.primary.identity[0].cluster_ca_certificate
  
  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-cluster"
  }
}

# Fargate profile for frontend
resource "aws_eks_node_group" "fargate" {
  cluster_name    = aws_eks_cluster.primary.name
  node_group_name = "fargate-workers"
  instance_types  = ["t3.large"]
  subnet_ids      = data.aws_subnet_ids.private.ids
  scaling_config  = {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }
}
