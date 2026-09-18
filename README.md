# PaySecure Gateway – Multi-Region Disaster Recovery Architecture

## Project Overview

PaySecure Gateway Private Limited is a fictional mid-tier payment aggregator
processing approximately 3.2 million transactions per day worth ₹500 crore
across 45,000 merchants.

The existing platform operates in a single AWS Mumbai region
(ap-south-1) with 99.92% uptime.

This project designs a multi-region disaster recovery architecture to achieve:

- 99.99% availability
- RPO under 1 minute
- RTO under 5 minutes
- Indian data localisation
- PCI DSS v4.0 alignment
- RBI payment-system resilience requirements
- NPCI UPI technical requirements

## Primary Region

AWS Mumbai – ap-south-1

## Disaster Recovery Region

AWS Hyderabad – ap-south-2

## Core Technologies

- Amazon EKS
- Amazon Aurora PostgreSQL
- Amazon DynamoDB
- Amazon ElastiCache Redis
- Amazon MSK / Apache Kafka
- Amazon Route 53
- AWS WAF
- AWS KMS
- AWS Secrets Manager
- Amazon S3
- Terraform
- Prometheus
- Grafana
- CloudWatch

## Project Status

🚧 Architecture design in progress