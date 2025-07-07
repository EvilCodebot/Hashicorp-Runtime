.PHONY: ssm-vm-a ssm-vm-b init plan apply destroy

# Initialize Terraform working directory
init:
	terraform init

# Preview the changes Terraform will make to match your configuration
plan:
	terraform plan

# Apply the changes
apply:
	terraform apply

# Destroy all remote objects managed by this Terraform configuration
destroy:
	terraform destroy 

# Connect to VM-A via SSM
ssm-vm-a:
	aws ssm start-session --target $$(aws ec2 describe-instances --filters "Name=tag:Name,Values=VM-A" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId]" --output text)

# Connect to VM-B via SSM
ssm-vm-b:
	aws ssm start-session --target $$(aws ec2 describe-instances --filters "Name=tag:Name,Values=VM-B" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId]" --output text)

