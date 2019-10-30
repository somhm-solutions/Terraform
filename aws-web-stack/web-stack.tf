# Provider Info
provider "aws" {
    region = "${var.region}"
}

# Define imported Vpc module
module "vpc" {
    #source        = "${var.git_repo}?ref=v0.0.1"
    #source = "../networking/vpc"
    source = "./vpc"
    name = "web"
    cidr = "10.0.0.0/16"
    public_subnet = "10.0.1.0/24"
}

# Registry load of module example
/*module "terraform-registry-vpc" {
  source = "terraform-aws-modules/vpc/aws"
}
*/

# Create EC2 Resources
resource "aws_instance" "web" {
    # look up ami by mapping to region
    ami = "${lookup(var.ami, var.region)}"
    
    # Instance type to create
    instance_type = "${var.instance_type}"
    
    key_name = "${var.key_name}"
    
    subnet_id = "${module.vpc.public_subnet_id}"
    private_ip = "${var.instance_ips[count.index]}"

    associate_public_ip_address = true
    

    # User data file
    user_data = "${file("files/web_bootstrap.sh")}"

    # Vpc Security Groups to Use
    vpc_security_group_ids = ["${aws_security_group.web_host_sg.id}",]

    # Tags to place on Instances
    tags = {
        Name = ""web-${format("%03d", count.index + 1)}""
    }

    # Specify Number of Resources to be Created
    count = length("${var.instance_ips}")
}

# Create Elastic Load Balancer Resource
resource "aws_elb" "web" {
    name = "web-elb"
    subnets = ["${module.vpc.public_subnet_id}"]
    security_groups = ["${aws_security_group.web_inbound_sg.id}",]
    listener {
        instance_port = 80
        instance_protocol = "http"
        lb_port = 80
        lb_protocol = "http"
    }
    # Instance registered automatatically
    instances = ["${aws_instance.web.*.id}",]
}

# Create AWS Security Group Resource
resource "aws_security_group" "web_inbound_sg"{
    name = "web_inbound"
    description = "Allow HTTP from Anywhere" 
    vpc_id = "${module.vpc_basic.vpc_id}"

    # Allow Http 
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow Ping
    ingress {
        from_port = 8
        to_port = 0
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "web_host_sg" {
    name = "web_host"
    description = "Allow ssh & http to hosts"
    vpc_id = "${module.vpc_basic.vpc_id}"

    # Allow SSH
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow Http from VPC ONLY
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${module.vpc_basic.cidr}",]
    }

    # Inbound Ping
    ingress {
        from_port = 8
        to_port = 0 
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Outbound All 
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

