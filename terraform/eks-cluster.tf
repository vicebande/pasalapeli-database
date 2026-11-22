# EKS Cluster Resources (infra compartida - propietario: pasalapeli-database)

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "pasalapeli-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node" {
  name = "pasalapeli-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSCNIPluginPolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

# EKS Cluster
resource "aws_eks_cluster" "primary" {
  name     = "pasalapeli-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = data.aws_subnets.private.ids
    security_group_ids      = [aws_security_group.eks.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
  ]

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-cluster"
  }
}

# EKS Auth data (for kubeconfig generation)
data "aws_eks_cluster_auth" "primary" {
  name = aws_eks_cluster.primary.name
}

# EKS Node Group (EC2 workers in private subnets)
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.primary.name
  node_group_name = "pasalapeli-workers"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = data.aws_subnets.private.ids

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-workers"
  }
}

# ECR Repository (infra compartida)
resource "aws_ecr_repository" "images" {
  name                 = "pasalapeli-images"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-images"
  }
}

output "cluster_name" {
  value = aws_eks_cluster.primary.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.primary.endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.images.repository_url
}
