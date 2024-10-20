provider "aws" {
  region = "ap-south-1"
}

# Security Group
resource "aws_security_group" "ELK_sg" {
  name_prefix = "ELK-sg-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5044
    to_port     = 5044
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
  }

  tags = {
    Name = "ELK-SecurityGroup"
  }
}

# EC2 Instance for ELK Stack
resource "aws_instance" "elk_server" {
  ami           = "ami-078264b8ba71bc45e"
  instance_type = "t2.large"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.ELK_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              # Update and install dependencies
              sudo yum update -y >> /var/log/user_data.log 2>&1
              sudo yum install libxcrypt-compat -y >> /var/log/user_data.log 2>&1
              sudo yum install docker -y >> /var/log/user_data.log 2>&1
              sudo service docker start >> /var/log/user_data.log 2>&1
              mkdir -p /root/logstash
              
              # Write the logstash configuration
              cat <<EOT > /root/logstash/logstash.conf
              input {
                beats {
                  port => 5044
                }
              }
              filter {
                # Add filters here
              }
              output {
                elasticsearch {
                  hosts => ["http://elasticsearch:9200"]
                  index => "logstash-%%{+YYYY.MM.dd}"
                }
              }
              EOT

              sudo usermod -aG docker ec2-user
              sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> /var/log/user_data.log 2>&1
              sudo chmod +x /usr/local/bin/docker-compose >> /var/log/user_data.log 2>&1

              # Create docker-compose file for ELK
              cat <<EOT > docker-compose.yml
              version: '3'
              services:
                elasticsearch:
                  image: docker.elastic.co/elasticsearch/elasticsearch:8.15.2
                  environment:
                    - discovery.type=single-node
                    - xpack.security.enabled=false
                  ports:
                    - "9200:9200"
                  networks:
                    - elk

                logstash:
                  image: docker.elastic.co/logstash/logstash:8.15.2
                  volumes:
                    - /root/logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf
                  ports:
                    - "5044:5044"
                  networks:
                    - elk

                kibana:
                  image: docker.elastic.co/kibana/kibana:8.15.2
                  environment:
                    - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
                  ports:
                    - "5601:5601"
                  networks:
                    - elk
              networks:
                elk:
                  driver: bridge
              EOT

              # Start ELK stack
              sudo docker-compose up -d >> /var/log/user_data.log 2>&1
              EOF

  tags = {
    Name = "ELK-Stack-Server"
  }
}
