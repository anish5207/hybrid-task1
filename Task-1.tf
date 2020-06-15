#Give your provider name

provider "aws" {
    region = "ap-south-1"
    profile = "anish"
}

#To generate key-pair(public-key and private-key)
   
  resource "tls_private_key" "task1-key" {
 algorithm = "RSA"
 rsa_bits = 4096
   }
   
  output "key_ssh"{
  value = tls_private_key.task1-key.public_key_openssh
}

output "pubkey"{
value = tls_private_key.task1-key.public_key_pem
#creating private key
}

    resource "local_file" "private_key" {
    depends_on = [tls_private_key.task1-key]
    content = tls_private_key.task1-key.private_key_pem
    filename = "task1key.pem"
    file_permission = 0400
    }

#creating the public key
resource "aws_key_pair" "webserver_key" {
 depends_on = [local_file.private_key]
 key_name = "task1key"
 public_key = tls_private_key.task1-key.public_key_openssh
}

#To create security-groups

resource "aws_security_group" "task1_security" {
  name        = "task1_security"
  description = "Give Security permissions"
 
#Ingress for incoming traffic
  
 ingress {
    description = "For SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
     ingress {
    description = "For HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

#Egress is for outgoing traffic 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task1_security"
  }
}

# To create EBS volume

 resource "aws_ebs_volume" "Ebs_task1" {
  availability_zone = "ap-south-1b"
  size              = 1

  tags = {
    Name = "Ebs_task1"
  }
}

# To attach EBS volume with EC2 instance

 resource "aws_volume_attachment" "attach_task1" {
   depends_on=[aws_ebs_volume.Ebs_task1]  
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.Ebs_task1.id
  instance_id = aws_instance.instance_task1.id
  force_detach = true
}
   
  


 # Creating null resources for installing and mounting
    resource "null_resource"  "remote1" {
    depends_on=[aws_volume_attachment.attach_task1]  
    connection {
    type = "ssh" 
    user = "ec2-user"
    private_key =  tls_private_key.task1-key.private_key_pem
    host = aws_instance.instance_task1.public_ip
  }
   provisioner "remote-exec" {
   inline = [
	   "sudo yum install httpd  php git -y",
                   "sudo systemctl restart httpd",
                   "sudo systemctl enable httpd",
	   "sudo mkfs.ext4 /dev/xvdh",
	   "sudo mount /dev/xvdh  /var/www/html",
	   "sudo rm -rf  /var/www/html/*",
	   "sudo git clone https://github.com/anish5207/hybrid-task1.git  /var/www/html/"
	]
             }
       }
 
#To create s3 bucket

resource "aws_s3_bucket" "task1-anish-bucket" {
  bucket = "task1-anish-bucket"
  acl = "public-read"
 
  versioning {
    enabled = true
  }

  tags = {
    Name = "task1-anish-bucket"
  }
}
 
#To upload image on s3 bucket

resource "aws_s3_bucket_object" "task1_object" {
  bucket = "${aws_s3_bucket.task1-anish-bucket.id}"
  key    = "image.jpg"
  source = "C:/Users/Anish garg/Desktop/practical.jpg"   
  acl = "public-read"
  
  force_destroy = true

}
 
 locals{
             s3_origin_id = "S3-${aws_s3_bucket.task1-anish-bucket.bucket}"
}

#To Create Cloud Front

  resource "aws_cloudfront_distribution" "task1_cf" {
   depends_on=[aws_s3_bucket.task1-anish-bucket]
   origin {
        domain_name = aws_s3_bucket.task1-anish-bucket.bucket_regional_domain_name
        origin_id = "${aws_s3_bucket.task1-anish-bucket.id}"


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true
     is_ipv6_enabled = true 


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "${aws_s3_bucket.task1-anish-bucket.id}"
         forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }

        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }

    # Restricts who is able to access this content
    
       restrictions {
          geo_restriction {
              restriction_type = "none"
        }
    }

      viewer_certificate {
        cloudfront_default_certificate = true
    }
     
      connection {
  type = "ssh"
  user = "ec2-user"
  private_key = tls_private_key.task1-key.private_key_pem
  host = aws_instance.instance_task1.public_ip
     }
    
   provisioner "remote-exec" {
  		
  		inline = [
  			
  			"sudo su << EOF",
            		"echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.task1_object.key}'>\" >> /var/www/html/index.php",
            		"EOF",	
  		]
  	}
}


#Code to launch instance

resource "aws_instance"  "instance_task1" {
  depends_on = [
           aws_security_group.task1_security,                           
   ]
  ami   = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name   = aws_key_pair.webserver_key.key_name
  security_groups = ["task1_security"]
  availability_zone = "ap-south-1b"

  connection {
  type = "ssh"
  user = "ec2-user"
  private_key = tls_private_key.task1-key.private_key_pem
  host = aws_instance.instance_task1.public_ip
     }

   tags = {
   Name = "Mytask1OS"
       }
}

resource "null_resource" "ip_in_file" {
 depends_on = [null_resource.remote1]
  provisioner "local-exec" {
    command = " echo The IP of the website is  ${aws_instance.instance_task1.public_ip} > result.txt"
  }
}

#after the completion of every step running the website
resource "null_resource" "running_the_website" {
    depends_on = [null_resource.remote1]
    provisioner "local-exec" {
    command = "chrome ${aws_instance.instance_task1.public_ip}"
  }
}













