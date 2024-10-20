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

  user_data = <<-EOF
    #!/bin/bash
    # Update and install dependencies
    sudo yum update -y >> /var/log/user_data.log 2>&1
    sudo yum install libxcrypt-compat -y  >> /var/log/user_data.log 2>&1
    sudo yum install docker -y >> /var/log/user_data.log 2>&1
    sudo service docker start >> /var/log/user_data.log 2>&1
    mkdir -p /root/logstash

    echo "Creating default logstash.conf"
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
      - ELASTIC_PASSWORD=your_elastic_password         # Set the password for the elastic user
      - xpack.security.enabled=true                    # Enable x-pack security
      - xpack.security.http.ssl.enabled=true           # Enable SSL for HTTP
      - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certs/http-es-node-1.key   # Key file path
      - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certs/http-es-node-1.crt # Certificate file path
      - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/ca.crt # CA file path (if using a CA-signed certificate)
      - network.host=0.0.0.0                           # Set the host to bind to all available IPs
    volumes:
      - /path/to/your/certs:/usr/share/elasticsearch/config/certs # Mount your SSL certificates directory
    ports:
      - "9200:9200"
    hostname: elasticsearch-node                       # Set the hostname of the Elasticsearch node
    networks:
      elk:
        ipv4_address: 172.18.0.2                       # Set the specific IP address for the container

  logstash:
    image: docker.elastic.co/logstash/logstash:8.15.2
    volumes:
      - /root/logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    ports:
      - "5044:5044"
    networks:
      elk:
        ipv4_address: 172.18.0.3                       # Set specific IP address for Logstash container

  kibana:
    image: docker.elastic.co/kibana/kibana:8.15.2
    environment:
      - ELASTICSEARCH_HOSTS=https://elasticsearch:9200  # Use HTTPS for secure communication
      - ELASTICSEARCH_USERNAME=elastic                  # Use the elastic user for Kibana
      - ELASTICSEARCH_PASSWORD=elastic123    # Provide the elastic user's password
      - SERVER_HOST=0.0.0.0                             # Set the server host
      - SERVER_NAME=kibana-node                         # Set the server hostname
    ports:
      - "5601:5601"
    networks:
      elk:
        ipv4_address: 172.18.0.4                       # Set specific IP address for Kibana container

networks:
  elk:
    driver: bridge
    ipam:
      config:
        - subnet: 172.18.0.0/16
    EOT

    # Start ELK stack
    sudo docker-compose up -d >> /var/log/user_data.log 2>&1
  EOF

  tags = {
    Name = "ELK-Stack-Server"
  }
}
