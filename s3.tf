#
# The scripts are hosted on S3
# also kubeadm join tokens will be stored on S3
#
resource "aws_s3_bucket" "private-k8s-topo" {
  bucket_prefix = "${var.name}-"
  acl    = "private"

  force_destroy = true

  versioning {
    enabled = true
  }
}

data "template_file" "prepare" {
  template = "${file("${path.module}/scripts/1_prepare.sh")}"

  vars {
    kubernetes_version = "${var.kubernetes_version}"
  }
}

data "template_file" "prepare2" {
  template = "${file("${path.module}/scripts/2_setup_kubernetes.sh")}"

  vars {
    kubernetes_version = "${var.kubernetes_version}"
    kubernetes_dashboard_version = "${var.kubernetes_dashboard_version}"
  }
}

resource "aws_s3_bucket_object" "prepare" {
  bucket = "${aws_s3_bucket.private-k8s-topo.id}"
  key    = "scripts/installation/1_prepare.sh"
  content = "${data.template_file.prepare.rendered}"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "prepare2" {
  bucket = "${aws_s3_bucket.private-k8s-topo.id}"
  key    = "scripts/installation/2_setup_kubernetes.sh"
  content = "${data.template_file.prepare2.rendered}"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "redsocks" {
  bucket = "${aws_s3_bucket.private-k8s-topo.id}"
  key    = "scripts/installation/1a_setup_redsocks.sh"
  content = "${file("${path.module}/scripts/1a_setup_redsocks.sh")}"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "redsocks-bin" {
  bucket = "${aws_s3_bucket.private-k8s-topo.id}"
  key    = "scripts/installation/redsocks"
  source = "scripts/redsocks"
  etag   = "${md5(file("scripts/redsocks"))}"
}

resource "aws_s3_bucket_object" "maint1" {
  bucket = "${aws_s3_bucket.private-k8s-topo.id}"
  key    = "scripts/maintenance/9_verify_network.sh"
  content = "${file("${path.module}/scripts/9_verify_network.sh")}"
  server_side_encryption = "AES256"
}

data "template_file" "addons" {
  template = "${file("${path.module}/scripts/3_addons.sh")}"

  vars {
    node_asg_name = "${aws_autoscaling_group.nodes.name}"
    node_asg_min = "${var.node_asg_min}"
    node_asg_max = "${var.node_asg_max}"
  }
}

resource "aws_s3_bucket_object" "addons" {
  bucket = "${aws_s3_bucket.private-k8s-topo.id}"
  key    = "scripts/installation/3_addons.sh"
  content = "${data.template_file.addons.rendered}"
  server_side_encryption = "AES256"
}
