.PHONY: get-private-ip curl-secure curl-plain

# get the private IP of the VM-A instance
get-private-ip:
	@echo "Fetching EC2 instance private IP..."
	$(eval TOKEN := $(shell curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"))
	@curl -s -H "X-aws-ec2-metadata-token: $(TOKEN)" http://169.254.169.254/latest/meta-data/local-ipv4

# Test Nginx TLS endpoint 
curl-secure:
	@echo "Making secure HTTPS request..."
	$(eval TOKEN := $(shell curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"))
	$(eval PRIVATE_IP := $(shell curl -s -H "X-aws-ec2-metadata-token: $(TOKEN)" http://169.254.169.254/latest/meta-data/local-ipv4))
	@curl https://$(PRIVATE_IP):10443 --cacert /opt/nginx/certs/ca.crt

# Test Nginx non-TLS endpoint 
curl-plain:
	@echo "Making plain HTTP request..."
	$(eval TOKEN := $(shell curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"))
	$(eval PRIVATE_IP := $(shell curl -s -H "X-aws-ec2-metadata-token: $(TOKEN)" http://169.254.169.254/latest/meta-data/local-ipv4))
	@curl http://$(PRIVATE_IP):10000