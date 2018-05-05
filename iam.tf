#
# IAM Role for the cluster
#
resource "aws_iam_role" "cluster" {
  name_prefix        = "${var.name}"
  description = "Kubernetes cluster master and worker nodes"
  path        = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#
# Instance profile that goes with the IAM role
#
resource "aws_iam_instance_profile" "cluster" {
  name_prefix = "${var.name}"
  role = "${aws_iam_role.cluster.name}"
}

data "template_file" "role_policy" {
  template = "${file("${path.module}/iam.json")}"

  vars {
    s3_arn = "${aws_s3_bucket.private-k8s-topo.arn}"
  }
}

#
# Attach the iam.json policy to the IAM role
#
resource "aws_iam_role_policy" "main" {
  name        = "${var.name}-main"
  role        = "${aws_iam_role.cluster.id}"
  policy      =  "${data.template_file.role_policy.rendered}"
}
