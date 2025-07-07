.PHONY: ssm-vm-a ssm-vm-b

# Connect to VM-A via SSM
ssm-vm-a:
	aws ssm start-session --target $$(aws ec2 describe-instances --filters "Name=tag:Name,Values=VM-A" --query "Reservations[*].Instances[*].[InstanceId]" --output text)

# Connect to VM-B via SSM
ssm-vm-b:
	aws ssm start-session --target $$(aws ec2 describe-instances --filters "Name=tag:Name,Values=VM-B" --query "Reservations[*].Instances[*].[InstanceId]" --output text) 