#!/bin/bash

# Function to check if a service is running
check_service_status() {
    systemctl is-active --quiet "$1"
}

# Function to get the current Tomcat port
get_tomcat_port() {
    grep 'Connector port' /opt/tomcat/conf/server.xml | grep 'protocol="HTTP/1.1"' | grep -o 'port="[0-9]*"' | sed 's/port="\([0-9]*\)"/\1/'
}

# Function to get the public IP address
get_public_ip() {
    curl -s http://checkip.amazonaws.com
}

# Check if Java is installed
if ! java -version 2>&1 | grep -q "11.0.23"; then
    echo "This may take some time. Please wait..."
    sudo yum install java-11-openjdk-devel -y &> /dev/null
else
    echo "Java 11 is already installed."
fi

# Check if Tomcat is installed
if [ ! -d "/opt/tomcat" ]; then
    echo "Tomcat is not installed. Installing Tomcat..."

    sudo mkdir -p /opt/tomcat

    # Check if the tomcat user exists
    if id "tomcat" &>/dev/null; then
        echo "User 'tomcat' already exists."
    else
        sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat
    fi

    sudo yum install wget -y &> /dev/null
    cd /tmp
    wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.89/bin/apache-tomcat-9.0.89.tar.gz &> /dev/null
    sudo tar xf apache-tomcat-9.0.89.tar.gz -C /opt/tomcat --strip-components=1 
    sudo chown -R tomcat: /opt/tomcat
    sudo chmod -R 755 /opt/tomcat

    # Prompt for port selection
    read -p "Enter port for Tomcat (8080 or 9050): " port
    if [[ "$port" != "8080" && "$port" != "9050" ]]; then
        echo "Invalid port. Defaulting to 8080."
        port=8080
    else 
        echo "Updated the port for Tomcat to: $port"
    fi

    sudo sed -i "s/port=\"8080\"/port=\"$port\"/" /opt/tomcat/conf/server.xml

    # Add service configuration
    sudo cp /home/ec2-user/artisantek-2024/tomcat/tomcat.service /etc/systemd/system/tomcat.service
    sudo cp /home/ec2-user/artisantek-2024/tomcat/tomcat-users.txt /opt/tomcat/conf/tomcat-users.xml

    # Enable manager and host manager
    sudo mkdir -p /opt/tomcat/webapps/manager/META-INF
    sudo mkdir -p /opt/tomcat/webapps/host-manager/META-INF
    sudo cp /home/ec2-user/artisantek-2024/tomcat/context.txt /opt/tomcat/webapps/manager/META-INF/context.xml
    sudo cp /home/ec2-user/artisantek-2024/tomcat/context.txt /opt/tomcat/webapps/host-manager/META-INF/context.xml

    sudo systemctl daemon-reload
    sudo systemctl start tomcat
    sudo systemctl enable tomcat &> /dev/null
    echo "Tomcat installed! Also manager and Host manager activated."
else
    port=$(get_tomcat_port)
    echo "Tomcat is already installed on port: $port"

    # Add service configuration
    sudo cp /home/ec2-user/artisantek-2024/tomcat/tomcat.service /etc/systemd/system/tomcat.service
    sudo cp /home/ec2-user/artisantek-2024/tomcat/tomcat-users.txt /opt/tomcat/conf/tomcat-users.xml
    
    # Enable manager and host manager if not enabled
    sudo mkdir -p /opt/tomcat/webapps/manager/META-INF
    sudo mkdir -p /opt/tomcat/webapps/host-manager/META-INF
    sudo cp /home/ec2-user/artisantek-2024/tomcat/context.txt /opt/tomcat/webapps/manager/META-INF/context.xml
    sudo cp /home/ec2-user/artisantek-2024/tomcat/context.txt /opt/tomcat/webapps/host-manager/META-INF/context.xml
    sudo systemctl daemon-reload
    
    # Check if Tomcat is running
    if ! check_service_status tomcat; then
        echo "Tomcat is not running. Attempting to restart..."
        sudo systemctl restart tomcat
        if ! check_service_status tomcat; then
            echo "Failed to restart Tomcat. Please check the logs for more details."
            sudo journalctl -u tomcat --since "5 minutes ago"
            exit 1
        fi
    else
        echo "Tomcat is running."
    fi
fi

# Get the public IP address and display the URL to access Tomcat
public_ip=$(get_public_ip)
echo ""
echo ""
echo "#########################################################"
echo "# You can now access Tomcat at: http://$public_ip:$port #"
echo "#########################################################"
echo ""