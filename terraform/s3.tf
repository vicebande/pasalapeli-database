# S3 Buckets
resource "aws_s3_bucket" "website" {
  bucket = "pasalapeli-website-static"
  acl    = "private"
  
  versioning {
    enabled = true
  }
  
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
  
  lifecycle_rule {
    expiration {
      days = 365
    }
  }
  
  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-website"
  }
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tfstate" {
  bucket = "pasalapeli-tfstate"
  acl    = "private"
  
  versioning {
    enabled = true
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  
  lifecycle_rule {
    expiration {
      days = 3650
    }
  }
  
  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-tfstate"
  }
}

# S3 bucket for uploads (portadas)
resource "aws_s3_bucket" "uploads" {
  bucket = "pasalapeli-uploads"
  acl    = "private"
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    expiration {
      days = 365
    }
  }
  
  tags = {
    Environment = var.environment_name
    Name        = "pasalapeli-uploads"
  }
}
