iot terraform sample
--------------------


This repository has a sample configuration for using Terraform to manage IoT resorces and configure KVS permissions per device.

This registers a custom CA in a JITP provisioning flow and attaches a role alias so that KVS can use the IoT Credentials endpoint
to access a video stream associated with the device.

Getting Started
---------------

	make

Cleaning Up
-----------

	make clean
