all :  deploy


.PHONY: deploy destroy clean plan validate

validate:
	terraform validate

plan: 
	terraform plan

deploy : 
	terraform apply -auto-approve


destroy:
	terraform destroy -auto-approve || true

clean : destroy
	rm -f *.pem *.key *.csr *.srl *.tfstate* *.json
	aws iot delete-policy --policy-name  DevicePolicy || true
	aws iot delete-role-alias --role-alias  kinesis-video-role-alias || true
	aws iam detach-role-policy --role-name IoTDeviceRole --policy-arn arn:aws:iam::aws:policy/IoTDevicePolicy || true
	aws iam delete-policy --policy-arn arn:aws:iam::aws:policy/IoTDevicePolicy || true
	aws iam delete-role --role-name IoTDeviceRole || true
	aws iam detach-role-policy --role-name IoTProvisioningRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSIoTThingsRegistration || true
	aws iam delete-role --role-name IoTProvisioningRole || true
