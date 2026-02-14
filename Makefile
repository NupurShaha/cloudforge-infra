.PHONY: fmt validate lint sec docs init plan-all destroy-all

# Format all Terraform files
fmt:
	terraform fmt -recursive modules/
	@echo "✅ Formatting complete"

# Validate all modules
validate:
	@for dir in $$(find modules -name "*.tf" -exec dirname {} \; | sort -u); do \
		echo "Validating $$dir..."; \
		cd $$dir && terraform init -backend=false > /dev/null 2>&1 && terraform validate && cd - > /dev/null; \
	done
	@echo "✅ All modules valid"

# Run tflint on all modules
lint:
	@for dir in $$(find modules -name "*.tf" -exec dirname {} \; | sort -u); do \
		echo "Linting $$dir..."; \
		tflint --chdir=$$dir; \
	done
	@echo "✅ Linting complete"

# Run tfsec security scan
sec:
	tfsec modules/
	@echo "✅ Security scan complete"

# Generate docs for all modules
docs:
	@for dir in $$(find modules -mindepth 2 -maxdepth 2 -type d); do \
		echo "Generating docs for $$dir..."; \
		terraform-docs markdown table $$dir > $$dir/README.md 2>/dev/null || true; \
	done
	@echo "✅ Docs generated"

# OPA policy check against a plan
opa-check:
	@echo "Run: cd environments/dev/<layer> && terragrunt plan -out=plan.tfplan && terraform show -json plan.tfplan > plan.json"
	@echo "Then: conftest test plan.json -p policies/opa/"

# Deploy dev environment
deploy-dev:
	cd environments/dev && terragrunt run-all apply --terragrunt-non-interactive

# Destroy dev environment (CAREFUL!)
destroy-dev:
	cd environments/dev && terragrunt run-all destroy --terragrunt-non-interactive

# Show what's in state across dev
state-dev:
	cd environments/dev && terragrunt run-all state list
