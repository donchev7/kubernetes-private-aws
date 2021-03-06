#
# Host configuration (same for master & worker)
#
data "template_file" "master" {
  template = "${file("${path.module}/scripts/userdata.tpl")}"

  vars {
    s3_id = "${aws_s3_bucket.private-k8s-topo.id}"
    role = "master"
    proxy = "${var.proxy}"
    volume = "${aws_ebs_volume.master.id}"
    load_balancer_dns = "${aws_lb.master.dns_name}"
  }
}


#
# EBS storage for master
#
resource "aws_ebs_volume" "master" {
    availability_zone = "${data.aws_subnet.selected.availability_zone}"
    size = 40
    encrypted = true
    type = "gp2"
    tags {
        Name = "${var.name}-master"
    }
}


#
# Security group for master
#
resource "aws_security_group" "master" {
  name        = "${var.name}-master"
  description = "${var.name}-master"
  vpc_id      = "${data.aws_vpc.selected.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }




  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = ["${aws_security_group.nodes.id}"]
  }

  ingress {
    from_port   = 0
    to_port     = 0  
    protocol    = "-1"

    self = true
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_launch_configuration" "master" {
  name_prefix      = "${var.name}-master-"
  image_id         = "${data.aws_ami.ubuntu.id}"
  instance_type    = "${var.master_instance_type}"
  security_groups  = ["${aws_security_group.master.id}"]
  key_name         = "${aws_key_pair.cluster.key_name}"
  user_data        = "${data.template_file.master.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.cluster.id}"

  root_block_device {
    volume_size = 60
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [ "image_id" ]
  }
}

resource "aws_autoscaling_group" "master" {
  name_prefix               = "${var.name}-master-"
  max_size                  = "${var.master_asg_max}"
  min_size                  = "${var.master_asg_min}"
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = "${var.master_asg_desired}"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.master.name}"
  vpc_zone_identifier       = ["${data.aws_subnet.selected.id}"]

  target_group_arns         = ["${aws_lb_target_group.master_443.arn}"]

  tags = [
    {
      key                 = "Name"
      value               = "${var.name}-master"
      propagate_at_launch = true
    },
    {
      key                 = "KubernetesCluster"
      value               = "${var.name}"
      propagate_at_launch = true
    },
    {
      key                 = "k8s.io/role/master"
      value               = 1 
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = true
  }
}

#
# We will run the api-server behind a Network LB
#
resource "aws_lb" "master" {
  name = "${var.name}-master"
  internal        = true
  subnets         = ["${data.aws_subnet.selected.id}"]
  load_balancer_type = "network"

  tags = {
    Name = "${var.name}-master"
  }

}


resource "aws_lb_listener" "master" {
  load_balancer_arn = "${aws_lb.master.arn}"
  port              = "443"
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.master_443.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "master_443" {
  name     = "${var.name}-master-443"
  port     = 443
  protocol = "TCP"
  vpc_id   = "${data.aws_vpc.selected.id}"
}
