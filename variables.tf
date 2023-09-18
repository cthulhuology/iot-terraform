# iot.tfvars
# vim: ts=2 tw=2 sw=2 et:

variable "cn" {
  type    = string
  default = "demo"
}

variable "country" {
  type    = string
  default = "LU"
}

variable "location" {
  type    = string
  default = "Luxembourg"
}

variable "state" {
  type    = string
  default = "Luxembourg"
}

variable "org" {
  type    = string
  default = "AWS"
}

variable "unit" {
  type    = string
  default = "Prototyping"
}

variable "certificate_id" {
  type    = string
  default = "64bc88eb03f99e9fa98334906dfcd632e3052e996e0efe0e797f8415e0eae0b3"
}
