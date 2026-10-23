# VPC for ${{ values.name }} (${{ values.environment }}), created from the Platform service template.

resource "aws_vpc" "${{ values.name }}" {
  cidr_block           = "${{ values.vpcCidr }}"
  enable_dns_hostnames = true

  tags = {
    Name        = "${{ values.name }}"
    Environment = "${{ values.environment }}"
  }
}