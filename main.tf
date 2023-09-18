# iot.tf
# vim: ts=2 tw=2 sw=2 et:
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["credentials.iot.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "device_policy" {
  statement {
    actions = [
      "kinesisvideo:DescribeStream",
      "kinesisvideo:PutMedia",
      "kinesisvideo:TagStream",
      "kinesisvideo:GetDataEndpoint"
    ]
    resources = ["arn:aws:kinesisvideo:${local.region}:${local.account_id}:stream/$${credentials-iot:ThingName}/*"]
  }
}

resource "aws_iam_policy" "device_policy" {
  name   = "IoTDevicePolicy"
  policy = data.aws_iam_policy_document.device_policy.json
}

resource "aws_iam_role" "device_role" {
  name               = "IoTDeviceRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "device_role_policy" {
  role       = aws_iam_role.device_role.name
  policy_arn = aws_iam_policy.device_policy.arn
}

resource "aws_iot_role_alias" "alias" {
  alias    = "kinesis-video-role-alias"
  role_arn = aws_iam_role.device_role.arn
}

data "aws_iam_policy_document" "iot_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["iot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "provisioning_role" {
  name               = "IoTProvisioningRole"
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.iot_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "iot_fleet_provisioning_registration" {
  role       = aws_iam_role.provisioning_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSIoTThingsRegistration"
}


resource "aws_iot_policy" "device_policy" {
  name = "DevicePolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["iot:connect"]
      Effect   = "Allow"
      Resource = "arn:aws:iot:${local.region}:${local.account_id}:client/$${iot:Certificate.Subject.CommonName}"
      }, {
      Action   = ["iot:publish", "iot:recieve"]
      Effect   = "Allow"
      Resource = "arn:aws:iot:${local.region}:${local.account_id}:topic/$${iot:Certificate.Subject.CommonName}/*"
      }, {
      Action   = ["iot:subscribe"]
      Effect   = "Allow"
      Resource = "arn:aws:iot:${local.region}:${local.account_id}:topicfilter/$${iot:Certificate.Subject.CommonName}/*"
    }]
  })
}

resource "null_resource" "iot_provisioning_template" {
  triggers = {
    templateBody = jsonencode({
      "Parameters" : {
        "AWS::IoT::Certificate::CommonName" : { "Type" : "String" },
        "AWS::IoT::Certificate::SerialNumber" : { "Type" : "String" },
        "AWS::IoT::Certificate::Id" : { "Type" : "String" },
        # "AWS::IoT::Certificate::Country" : { "Type" : "String" },
        # "AWS::IoT::Certificate::Organization" : { "Type" : "String" },
        # "AWS::IoT::Certificate::OrganizationalUnit" : { "Type" : "String" },
        # "AWS::IoT::Certificate::DistinguishedNameQualifier" : { "Type" : "String" },
        # "AWS::IoT::Certificate::StateName" : { "Type" : "String" }
      },
      "Resources" : {
        "thing" : {
          "Type" : "AWS::IoT::Thing",
          "Properties" : {
            "ThingName" : { "Ref" : "AWS::IoT::Certificate::CommonName" },
            "AttributePayload" : {}
          }
        },
        "certificate" : {
          "Type" : "AWS::IoT::Certificate",
          "Properties" : {
            "CertificateId" : { "Ref" : "AWS::IoT::Certificate::Id" },
            "Status" : "ACTIVE"
          }
        },
        "policy" : {
          "Type" : "AWS::IoT::Policy",
          "Properties" : {
            "PolicyName" : aws_iot_policy.device_policy.name
          }
        }
      }
    })
  }

  provisioner "local-exec" {
    command = <<HERE
      echo '{ "templateBody": ${jsonencode(self.triggers.templateBody)}, "roleArn": "${aws_iam_role.provisioning_role.arn}" }' > provisioning.json
    HERE
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<THERE
      rm provisioning.json
    THERE
  }
}

resource "null_resource" "ca_certificate" {

  #triggers = {
  #  certificate_id = var.certificate_id
  #}

  provisioner "local-exec" {
    command = <<-HERE
      openssl genrsa -out ca.key 2048
      openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.pem  -subj "/CN=${var.cn}/C=${var.country}/L=${var.location}/ST=${var.state}/O=${var.org}/OU=${var.unit}"
      SUB=`aws iot get-registration-code | jq -r '.["registrationCode"]'`
      openssl req -new -key ca.key -out verificationCert.csr -subj "/CN=$SUB"
      openssl x509 -req -in verificationCert.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out verification.pem -days 500 -sha256
      sleep 15
      aws iot register-ca-certificate --ca-certificate file://ca.pem --verification-cert file://verification.pem \
          --set-as-active --allow-auto-registration --registration-config file://provisioning.json 
    HERE
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-HERE
       CERT=`aws iot list-ca-certificates | jq -r '.certificates | .[0] | .certificateId'`
       aws iot update-ca-certificate --new-status INACTIVE --remove-auto-registration --certificate-id $CERT
       aws iot delete-ca-certificate --certificate-id $CERT
    HERE
  }
  depends_on = [null_resource.iot_provisioning_template, aws_iam_role.provisioning_role]
}

