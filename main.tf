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

# Create an EC2 instance for the ELK stack
resource "aws_instance" "elk_server" {
  ami           = "ami-078264b8ba71bc45e"  # Use the latest Amazon Linux AMI or Ubuntu
  instance_type = "t2.large"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.ELK_sg.id]

  # User data script for provisioning the instance
  user_data = <<-EOF
    #!/bin/bash
    # Update and install dependencies
    sudo yum update -y
    sudo yum install libxcrypt-compat -y
    sudo yum install docker -y
    sudo service docker start
    mkdir -p /root/logstash

    # Create default logstash.conf
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
        index => "logstash-%{+YYYY.MM.dd}"
      }
    }
    EOT

    sudo usermod -aG docker ec2-user
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Create docker-compose.yml file for ELK
    cat <<EOT > docker-compose.yml
    version: "3"
    services:
      elasticsearch:
        image: docker.elastic.co/elasticsearch/elasticsearch:8.15.2
        environment:
          - discovery.type=single-node
          - ELASTIC_PASSWORD=elastic123
          - xpack.security.enabled=true
          - xpack.security.http.ssl.enabled=true
          - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certs/http-es-node-1.key
          - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certs/http-es-node-1.crt
          - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/ca.crt
          - network.host=0.0.0.0
        volumes:
          - /path/to/your/certs:/usr/share/elasticsearch/config/certs
        ports:
          - "9200:9200"
        hostname: elasticsearch-node
        networks:
          elk:
            ipv4_address: 172.18.0.2

      logstash:
        image: docker.elastic.co/logstash/logstash:8.15.2
        volumes:
          - /root/logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf
        ports:
          - "5044:5044"
        networks:
          elk:
            ipv4_address: 172.18.0.3

      kibana:
        image: docker.elastic.co/kibana/kibana:8.15.2
        environment:
          - ELASTICSEARCH_HOSTS=https://elasticsearch:9200
          - ELASTICSEARCH_USERNAME=elastic
          - ELASTICSEARCH_PASSWORD=elastic123
          - SERVER_HOST=0.0.0.0
          - SERVER_NAME=kibana-node
        ports:
          - "5601:5601"
        networks:
          elk:
            ipv4_address: 172.18.0.4

    networks:
      elk:
        driver: bridge
        ipam:
          config:
            - subnet: 172.18.0.0/16
    EOT

    # Start the ELK stack
    sudo docker-compose up -d
  EOF

  tags = {
    Name = "ELK-Stack-Server"
  }
}
