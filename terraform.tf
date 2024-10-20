name: Terraform ELK Stack CI/CD 

on:
  push:
    branches:
      - main  # Trigger pipeline on push to the main branch

jobs:
  terraform:
    name: Apply ELK Stack Infrastructure
    runs-on: ubuntu-latest

    steps:
      # Checkout the repository
      - name: Checkout code
        uses: actions/checkout@v3

      # Setup Terraform CLI
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      # Terraform Init (initialize backend, provider, etc.)
      - name: Terraform Init
        run: terraform init

      # Terraform Plan (show what changes will be made)
      - name: Terraform Plan
        run: terraform plan

      # Terraform Apply (deploy the infrastructure)
      - name: Terraform Apply
        run: terraform apply -auto-approve

    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
