####################################################################
#   
#                   Terraform state resources
#                   RUN terraform apply here before
#                   running terraform in the k8s folder
####################################################################

provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "terraform-state-storage-s3" {
  bucket = "${var.name}"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags {
    Name = "S3 Remote Terraform State Store"
  }
}

resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name           = "${var.name}"
  hash_key       = "LockID"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "LockID"
    type = "S"
  }

  tags {
    Name = "DynamoDB Terraform State Lock Table"
  }
}
