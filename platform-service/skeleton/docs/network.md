# Network

The VPC is defined in `terraform/network/vpc.tf` with the range `${{ values.vpcCidr }}`.

## Rules

- A VPC must not overlap any range in `terraform/known-ranges.txt`. The **Platform audit** workflow
  checks this on every pull request and blocks the merge if it fails.
- To reuse a range on purpose (for example a shared EKS pod range), mark both ranges with
  `# infradoctor: allow-overlap`.
- New ranges used outside this repository should be added to `known-ranges.txt`.