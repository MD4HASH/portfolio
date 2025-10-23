# modules/network/outputs.tf

# VPC ID
output "vpc_id" {
  value = module.vpc.vpc_id
}

# Public subnets
output "public_subnets" {
  value = module.vpc.public_subnets
}

# Private subnets
output "private_subnets" {
  value = module.vpc.private_subnets
}
