provider "aws" {
  region = "ap-south-1"  # Change to your preferred region
}
# Create a security group to allow SSH and HTTP access
resource "aws_security_group" "ELK_sg" {
  name_prefix = "ELK-sg-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  tags = {
    Name = "ELK-SecurityGroup"
  }
}
  
resource "aws_instance" "elk_server" {
  ami           = "ami-078264b8ba71bc45e"  # Use the latest Amazon Linux AMI or Ubuntu
  instance_type = "t2.micro"
  key_name      = var.key_name


  
  user_data = <<-EOF
              #!/bin/bash
              # Update and install dependencies
              sudo yum update -y
              sudo yum install docker -y
              sudo service docker start
              sudo usermod -aG docker ec2-user
              sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose

              # Create docker-compose file for ELK
              cat <<EOT >> docker-compose.yml
              version: '3'
              services:
                elasticsearch:
                  image: docker.elastic.co/elasticsearch/elasticsearch:8.10.0
                  environment:
                    - discovery.type=single-node
                    - xpack.security.enabled=false
                  ports:
                    - "9200:9200"

                logstash:
                  image: docker.elastic.co/logstash/logstash:8.10.0
                  volumes:
                    - ./logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf
                  ports:
                    - "5044:5044"

                kibana:
                  image: docker.elastic.co/kibana/kibana:8.10.0
                  environment:
                    - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
                  ports:
                    - "5601:5601"
              EOT

              # Start ELK stack
              sudo docker-compose up -d
              EOF

  tags = {
    Name = "ELK-Stack-Server"
  }
}
